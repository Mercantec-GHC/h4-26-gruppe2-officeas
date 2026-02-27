class UserModel {
  final String id;
  final String name;
  final String email;
  final String? departmentId;
  final String? avatarUrl;
  final String? departmentName;
  final bool isApproved;
  final DateTime? approvedAt;
  final String? approvedByUserId;
  final int feedbackRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.departmentId,
    this.avatarUrl,
    this.departmentName,
    this.isApproved = true,
    this.approvedAt,
    this.approvedByUserId,
    this.feedbackRating = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.empty() {
    return UserModel(
      id: '',
      name: '',
      email: '',
      isApproved: false,
      feedbackRating: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      departmentId: json['department_id'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'] ?? null,
      departmentName: json['department']?['name'],
      isApproved: json['is_approved'] ?? true,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'])
          : null,
      approvedByUserId: json['approved_by_user_id'],
      feedbackRating: json['feedback_rating'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department_id': departmentId,
      'avatar_url': avatarUrl,
      'is_approved': isApproved,
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by_user_id': approvedByUserId,
      'feedback_rating': feedbackRating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
