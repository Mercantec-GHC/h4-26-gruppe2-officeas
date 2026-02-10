import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../../data/models/messaging_models.dart';

/// WebSocket client for real-time messaging.
/// Connects to the backend and streams [WebSocketEventModel] events.
class MessagingWebSocketService {
  static const String _tokenKey = 'auth_token';
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const int _maxReconnectAttempts = 5;

  WebSocketChannel? _channel;
  final _controller = StreamController<WebSocketEventModel>.broadcast();
  StreamSubscription? _subscription;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  /// Stream of incoming WebSocket events.
  Stream<WebSocketEventModel> get events => _controller.stream;

  /// Whether the socket is currently connected.
  bool get isConnected => _channel != null;

  /// Connect to the messaging WebSocket.
  Future<void> connect() async {
    if (_disposed) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      debugPrint('[WS] No auth token — skipping connect');
      return;
    }

    // Build ws(s) URL from the HTTP base URL.
    final httpBase = AppConfig.instance.apiBaseUrl;
    final wsBase = httpBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/ws/messages?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      debugPrint('[WS] Connecting to $uri');

      _subscription = _channel!.stream.listen(
        (data) {
          // First successful message proves the connection is alive.
          _reconnectAttempts = 0;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _controller.add(WebSocketEventModel.fromJson(json));
          } catch (e) {
            debugPrint('[WS] Failed to parse event: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WS] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _cleanup();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Max reconnect attempts reached');
      return;
    }
    _reconnectAttempts++;
    debugPrint('[WS] Reconnecting (attempt $_reconnectAttempts)...');
    Future.delayed(_reconnectDelay, connect);
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Disconnect and release resources.
  void dispose() {
    _disposed = true;
    _cleanup();
    _controller.close();
  }
}
