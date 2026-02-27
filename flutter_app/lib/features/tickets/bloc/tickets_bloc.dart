import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/repositories/ticket_repository.dart';
import 'tickets_event.dart';
import 'tickets_state.dart';

class TicketsBloc extends Bloc<TicketsEvent, TicketsState> {
  final TicketRepository _repository;

  List<TicketModel> _cachedTickets = [];

  TicketsBloc({required TicketRepository repository})
    : _repository = repository,
      super(const TicketsInitial()) {
    on<LoadTickets>(_onLoadTickets);
    on<RefreshTickets>(_onRefreshTickets);
    on<LoadTicketDetail>(_onLoadTicketDetail);
    on<CreateTicket>(_onCreateTicket);
    on<UpdateTicketStatus>(_onUpdateTicketStatus);
    on<AddComment>(_onAddComment);
    on<ClearTicketDetail>(_onClearTicketDetail);
    on<UploadTicketImage>(_onUploadTicketImage);
  }

  List<TicketModel> get cachedTickets => List.unmodifiable(_cachedTickets);

  Future<void> _onLoadTickets(
    LoadTickets event,
    Emitter<TicketsState> emit,
  ) async {
    emit(const TicketsLoading());

    try {
      final tickets = await _repository.getTickets();

      _cachedTickets = tickets;

      emit(TicketsListLoaded(tickets));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  Future<void> _onRefreshTickets(
    RefreshTickets event,
    Emitter<TicketsState> emit,
  ) async {
    try {
      final tickets = await _repository.getTickets();
      _cachedTickets = tickets;

      if (state is TicketDetailLoaded) {
        final current = state as TicketDetailLoaded;
        final updated = tickets.where((t) => t.id == current.ticket.id);

        if (updated.isNotEmpty) {
          emit(TicketDetailLoaded(updated.first));
          return;
        }
      }

      emit(TicketsListLoaded(tickets));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  Future<void> _onLoadTicketDetail(
    LoadTicketDetail event,
    Emitter<TicketsState> emit,
  ) async {
    emit(const TicketsLoading());

    try {
      final ticket = await _repository.getTicketById(event.ticketId);

      emit(TicketDetailLoaded(ticket));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  Future<void> _onCreateTicket(
    CreateTicket event,
    Emitter<TicketsState> emit,
  ) async {
    emit(const TicketsLoading());

    try {
      final ticket = await _repository.createTicket(
        title: event.title,
        description: event.description,
        createdByUserId: event.createdByUserId,
      );

      _cachedTickets = [ticket, ..._cachedTickets];

      emit(TicketCreateSuccess(ticket));
      emit(TicketsListLoaded(_cachedTickets));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  Future<void> _onUpdateTicketStatus(
    UpdateTicketStatus event,
    Emitter<TicketsState> emit,
  ) async {
    try {
      final ticket = await _repository.updateTicket(
        event.ticketId,
        status: event.status,
      );

      final index = _cachedTickets.indexWhere((t) => t.id == ticket.id);

      if (index >= 0) _cachedTickets[index] = ticket;

      emit(TicketUpdateSuccess(ticket));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  Future<void> _onAddComment(
    AddComment event,
    Emitter<TicketsState> emit,
  ) async {
    try {
      await _repository.addComment(
        ticketId: event.ticketId,
        userId: event.userId,
        content: event.content,
      );

      final ticket = await _repository.getTicketById(event.ticketId);

      emit(CommentAddSuccess(ticket));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }

  void _onClearTicketDetail(
    ClearTicketDetail event,
    Emitter<TicketsState> emit,
  ) {
    if (_cachedTickets.isEmpty) {
      emit(const TicketsInitial());
    } else {
      emit(TicketsListLoaded(_cachedTickets));
    }
  }

  Future<void> _onUploadTicketImage(
    UploadTicketImage event,
    Emitter<TicketsState> emit,
  ) async {
    try {
      final ticket = await _repository.uploadTicketImage(
        event.ticketId,
        event.imageBytes,
        filename: event.filename,
      );
      final index = _cachedTickets.indexWhere((t) => t.id == ticket.id);
      if (index >= 0) _cachedTickets[index] = ticket;
      emit(TicketUpdateSuccess(ticket));
    } catch (e) {
      emit(TicketsError(e.toString()));
    }
  }
}
