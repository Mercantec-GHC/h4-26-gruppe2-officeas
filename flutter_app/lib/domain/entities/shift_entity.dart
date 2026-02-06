import 'package:equatable/equatable.dart';

/// Shift Entity (Domain Layer)
/// 
/// Repræsenterer arbejdsshift data i business logic laget.
/// Entity er uafhængig af data source (API, database, osv.)
class ShiftEntity extends Equatable {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final String? userName; // Optional: user name from relationship

  const ShiftEntity({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    this.userName,
  });

  /// Convenience getter for formateret starttidspunkt
  String get formattedStartTime {
    return '${startTime.day}/${startTime.month}/${startTime.year} ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  /// Convenience getter for formateret sluttidspunkt
  String get formattedEndTime {
    return '${endTime.day}/${endTime.month}/${endTime.year} ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }

  /// Varighed i timer
  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60;
  }

  /// Varighed som string
  String get durationString {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  /// Check om shift er i dag
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// Check om shift er i fremtiden
  bool get isFuture => startTime.isAfter(DateTime.now());

  /// Check om shift er i fortiden
  bool get isPast => endTime.isBefore(DateTime.now());

  /// Check om shift er aktuel (nu)
  bool get isActive {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  @override
  List<Object?> get props => [id, userId, startTime, endTime, userName];

  @override
  String toString() {
    return 'ShiftEntity(id: $id, userId: $userId, startTime: $startTime, '
        'endTime: $endTime, userName: $userName)';
  }
}
