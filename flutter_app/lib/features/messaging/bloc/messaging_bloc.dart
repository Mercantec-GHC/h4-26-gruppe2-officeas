import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/messaging_remote_datasource.dart';
import '../../../data/models/messaging_models.dart';
import '../../../core/services/messaging_websocket_service.dart';
import 'messaging_event.dart';
import 'messaging_state.dart';

/// BLoC for the messaging feature.
/// Handles conversations, messages, and WebSocket events.
class MessagingBloc extends Bloc<MessagingEvent, MessagingState> {
  final MessagingRemoteDataSource _dataSource;
  final MessagingWebSocketService _wsService;
  StreamSubscription? _wsSub;

  /// Cached conversations list, kept in sync with WS events.
  List<ConversationModel> _conversations = [];

  /// Current chat state — kept around so retry works after errors.
  MessagesLoaded? _currentChat;

  /// Pagination offset for the current conversation's messages.
  int _offset = 0;
  bool _isLoadingMore = false;
  static const int _pageSize = 50;

  /// IDs we've already marked as read (avoids duplicate requests).
  final Set<String> _markedReadIds = {};

  MessagingBloc({
    required MessagingRemoteDataSource dataSource,
    required MessagingWebSocketService wsService,
  }) : _dataSource = dataSource,
       _wsService = wsService,
       super(MessagingInitial()) {
    on<LoadConversations>(_onLoadConversations);
    on<CreateConversation>(_onCreateConversation);
    on<OpenConversation>(_onOpenConversation);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendMessage>(_onSendMessage);
    on<MarkMessageRead>(_onMarkMessageRead);
    on<WebSocketEventReceived>(_onWebSocketEvent);

    // Start WebSocket and forward events into the BLoC.
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsService.connect();
    _wsSub = _wsService.events.listen((wsEvent) {
      add(WebSocketEventReceived(type: wsEvent.type, payload: wsEvent.payload));
    });
  }

  // ── Load conversations ──────────────────────────────────────

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<MessagingState> emit,
  ) async {
    emit(ConversationsLoading());
    try {
      _conversations = await _dataSource.getConversations();
      emit(ConversationsLoaded(conversations: _conversations));
    } catch (e) {
      emit(MessagingError(message: _friendlyError(e)));
    }
  }

  // ── Create conversation ─────────────────────────────────────

  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<MessagingState> emit,
  ) async {
    try {
      final conv = await _dataSource.createConversation(
        userIds: event.userIds,
        isGroup: event.isGroup,
      );
      _conversations = [conv, ..._conversations];
      emit(ConversationsLoaded(conversations: _conversations));
    } catch (e) {
      emit(MessagingError(message: _friendlyError(e)));
    }
  }

  // ── Open conversation (load first page) ─────────────────────

  Future<void> _onOpenConversation(
    OpenConversation event,
    Emitter<MessagingState> emit,
  ) async {
    _offset = 0;
    _currentChat = null;
    emit(MessagesLoading(conversationId: event.conversationId));
    try {
      final page = await _dataSource.getMessages(
        event.conversationId,
        limit: _pageSize,
        offset: 0,
      );
      _offset = page.messages.length;
      _currentChat = MessagesLoaded(
        conversationId: event.conversationId,
        messages: page.messages,
        hasMore: page.hasMore,
        total: page.total,
      );
      emit(_currentChat!);
    } catch (e) {
      emit(MessagingError(message: _friendlyError(e)));
    }
  }

  // ── Load more (pagination) ──────────────────────────────────

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<MessagingState> emit,
  ) async {
    final current = _currentChat;
    if (current == null || !current.hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final page = await _dataSource.getMessages(
        current.conversationId,
        limit: _pageSize,
        offset: _offset,
      );
      _offset += page.messages.length;
      _currentChat = current.copyWith(
        messages: [...current.messages, ...page.messages],
        hasMore: page.hasMore,
        total: page.total,
      );
      emit(_currentChat!);
    } catch (e) {
      debugPrint('[MessagingBloc] LoadMore error: $e');
      // Don't emit error — keep showing existing messages.
    } finally {
      _isLoadingMore = false;
    }
  }

  // ── Send message ────────────────────────────────────────────

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<MessagingState> emit,
  ) async {
    final current = _currentChat;
    if (current == null) return;

    try {
      final msg = await _dataSource.sendMessage(
        current.conversationId,
        event.content,
      );
      // Prepend the new message (newest first).
      _currentChat = current.copyWith(
        messages: [msg, ...current.messages],
        total: current.total + 1,
      );
      emit(_currentChat!);
    } catch (e) {
      debugPrint('[MessagingBloc] SendMessage error: $e');
      // Re-emit current chat state so UI stays on the chat screen.
      // Emit a brief error then restore, so the user sees the failure
      // but can retry without navigating away.
      emit(MessagingError(message: _friendlyError(e)));
      emit(current);
    }
  }

  // ── Mark as read ────────────────────────────────────────────

  Future<void> _onMarkMessageRead(
    MarkMessageRead event,
    Emitter<MessagingState> emit,
  ) async {
    if (_markedReadIds.contains(event.messageId)) return;
    _markedReadIds.add(event.messageId);
    try {
      await _dataSource.markAsRead(event.messageId);
    } catch (e) {
      _markedReadIds.remove(event.messageId);
      debugPrint('[MessagingBloc] MarkAsRead error: $e');
    }
  }

  // ── WebSocket events ────────────────────────────────────────

  Future<void> _onWebSocketEvent(
    WebSocketEventReceived event,
    Emitter<MessagingState> emit,
  ) async {
    switch (event.type) {
      case 'new_message':
        _handleNewMessage(event.payload, emit);
        break;
      case 'message_read':
        _handleMessageRead(event.payload, emit);
        break;
      default:
        debugPrint('[MessagingBloc] Unknown WS event: ${event.type}');
    }
  }

  void _handleNewMessage(
    Map<String, dynamic> payload,
    Emitter<MessagingState> emit,
  ) {
    try {
      final msg = MessageModel.fromJson(payload);
      final chat = _currentChat;

      if (chat != null && chat.conversationId == msg.conversationId) {
        // Currently viewing this conversation.
        // Skip if message already exists (dedup HTTP response + WS broadcast).
        if (chat.messages.any((m) => m.id == msg.id)) return;

        _currentChat = chat.copyWith(
          messages: [msg, ...chat.messages],
          total: chat.total + 1,
        );
        emit(_currentChat!);
      }
      // For messages in OTHER conversations: don't call LoadConversations()
      // as that would change state and break the current chat view.
      // The conversation list will refresh when the user navigates back.
    } catch (e) {
      debugPrint('[MessagingBloc] Failed to handle new_message: $e');
    }
  }

  void _handleMessageRead(
    Map<String, dynamic> payload,
    Emitter<MessagingState> emit,
  ) {
    final chat = _currentChat;
    if (chat == null) return;

    final messageId = payload['message_id']?.toString();
    if (messageId == null) return;

    var changed = false;
    final updated = chat.messages.map((m) {
      if (m.id == messageId && m.readAt == null) {
        changed = true;
        return m.copyWith(readAt: DateTime.now());
      }
      return m;
    }).toList();

    if (changed) {
      _currentChat = chat.copyWith(messages: updated);
      emit(_currentChat!);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Kan ikke forbinde til serveren. Prøv igen.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Du er ikke logget ind.';
    }
    return 'Noget gik galt. Prøv igen.';
  }

  @override
  Future<void> close() {
    _wsSub?.cancel();
    // Do NOT dispose _wsService — it's a DI singleton shared across
    // bloc instances. Its lifecycle is managed by the DI container.
    return super.close();
  }
}
