import 'package:equatable/equatable.dart';

/// Absence Request Status enumeration
enum AbsenceRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;
  String get displayName {
    switch (this) {
      case AbsenceRequestStatus.pending:
        return 'Pending';
      case AbsenceRequestStatus.approved:
        return 'Approved';
      case AbsenceRequestStatus.rejected:
        return 'Rejected';
      case AbsenceRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  static AbsenceRequestStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return AbsenceRequestStatus.pending;
      case 'APPROVED':
        return AbsenceRequestStatus.approved;
      case 'REJECTED':
        return AbsenceRequestStatus.rejected;
      default:
        return AbsenceRequestStatus.pending;
    }
  }
}

/// Absence Type enumeration
enum AbsenceType {
  sickLeave,
  vacation,
  personal,
  other;

  String get displayName {
    switch (this) {
      case AbsenceType.sickLeave:
        return 'Sick Leave';
      case AbsenceType.vacation:
        return 'Vacation';
      case AbsenceType.personal:
        return 'Personal Leave';
      case AbsenceType.other:
        return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case AbsenceType.sickLeave:
        return 'SICK_LEAVE';
      case AbsenceType.vacation:
        return 'VACATION';
      case AbsenceType.personal:
        return 'PERSONAL_LEAVE';
      case AbsenceType.other:
        return 'OTHER';
    }
  }

  static AbsenceType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SICK_LEAVE':
        return AbsenceType.sickLeave;
      case 'VACATION':
        return AbsenceType.vacation;
      case 'PERSONAL_LEAVE':
        return AbsenceType.personal;
      case 'OTHER':
        return AbsenceType.other;
      default:
        return AbsenceType.other;
    }
  }
}

/// Absence Request Entity (Domain Layer)
///
/// Repræsenterer absence request data i business logic laget.
/// Entity er uafhængig af data source (API, database, osv.)
class AbsenceRequestEntity extends Equatable {
    /// Check if request is cancelled
    bool get isCancelled => status == AbsenceRequestStatus.cancelled;
  final String id;
  final String userId;
  final AbsenceType type;
  final DateTime startDate;
  final DateTime endDate;
  final String? shiftId;
  final AbsenceRequestStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByUserId;
  final String? userName;

  const AbsenceRequestEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.shiftId,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByUserId,
    this.userName,
  });

  /// Get formatted start date
  String get formattedStartDate {
    return '${startDate.day}/${startDate.month}/${startDate.year}';
  }

  /// Get formatted end date
  String get formattedEndDate {
    return '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  /// Get duration in days
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Check if request is pending
  bool get isPending => status == AbsenceRequestStatus.pending;

  /// Check if request is approved
  bool get isApproved => status == AbsenceRequestStatus.approved;

  /// Check if request is rejected
  bool get isRejected => status == AbsenceRequestStatus.rejected;

  /// Check if request is in the future
  bool get isFuture => startDate.isAfter(DateTime.now());

  /// Check if request is active (ongoing)
  bool get isActive {
    final now = DateTime.now();
    return startDate.isBefore(now) && endDate.isAfter(now);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        startDate,
        endDate,
        shiftId,
        status,
        createdAt,
        reviewedAt,
        reviewedByUserId,
        userName,
      ];

  @override
  String toString() {
    return 'AbsenceRequestEntity('
        'id: $id, userId: $userId, type: ${type.displayName}, '
        'startDate: $startDate, endDate: $endDate, status: ${status.displayName})';
  }
}
