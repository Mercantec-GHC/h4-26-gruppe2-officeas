import 'package:equatable/equatable.dart';
import '../../../data/models/ticket_model.dart';

abstract class TicketsState extends Equatable {
  const TicketsState();

  @override
  List<Object?> get props => [];
}

class TicketsInitial extends TicketsState {
  const TicketsInitial();
}

class TicketsLoading extends TicketsState {
  const TicketsLoading();
}

class TicketsListLoaded extends TicketsState {
  final List<TicketModel> tickets;

  const TicketsListLoaded(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

class TicketDetailLoaded extends TicketsState {
  final TicketModel ticket;

  const TicketDetailLoaded(this.ticket);

  @override
  List<Object?> get props => [ticket];
}

class TicketsError extends TicketsState {
  final String message;

  const TicketsError(this.message);

  @override
  List<Object?> get props => [message];
}

class TicketCreateSuccess extends TicketsState {
  final TicketModel ticket;

  const TicketCreateSuccess(this.ticket);

  @override
  List<Object?> get props => [ticket];
}

class TicketUpdateSuccess extends TicketsState {
  final TicketModel ticket;

  const TicketUpdateSuccess(this.ticket);

  @override
  List<Object?> get props => [ticket];
}

class CommentAddSuccess extends TicketsState {
  final TicketModel ticket;

  const CommentAddSuccess(this.ticket);

  @override
  List<Object?> get props => [ticket];
}
