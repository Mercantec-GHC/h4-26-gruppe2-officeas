import 'package:equatable/equatable.dart';

abstract class TicketsEvent extends Equatable {
  const TicketsEvent();

  @override
  List<Object?> get props => [];
}

class LoadTickets extends TicketsEvent {
  const LoadTickets();
}

class RefreshTickets extends TicketsEvent {
  const RefreshTickets();
}

class LoadTicketDetail extends TicketsEvent {
  final String ticketId;

  const LoadTicketDetail(this.ticketId);

  @override
  List<Object?> get props => [ticketId];
}

class CreateTicket extends TicketsEvent {
  final String title;
  final String description;
  final String createdByUserId;

  const CreateTicket({
    required this.title,
    required this.description,
    required this.createdByUserId,
  });

  @override
  List<Object?> get props => [title, description, createdByUserId];
}

class UpdateTicketStatus extends TicketsEvent {
  final String ticketId;
  final String status;

  const UpdateTicketStatus({required this.ticketId, required this.status});

  @override
  List<Object?> get props => [ticketId, status];
}

class AddComment extends TicketsEvent {
  final String ticketId;
  final String content;
  final String userId;

  const AddComment({
    required this.ticketId,
    required this.content,
    required this.userId,
  });

  @override
  List<Object?> get props => [ticketId, content, userId];
}

class ClearTicketDetail extends TicketsEvent {
  const ClearTicketDetail();
}
