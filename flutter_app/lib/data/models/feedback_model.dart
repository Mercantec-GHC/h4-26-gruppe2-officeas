class FeedbackModel {
  final String? id;
  final String? message;
  final int rating;
  final String? departmentId;
  final String? shiftId;

  FeedbackModel({
    this.id,
    this.message,
    required this.rating,
    this.departmentId,
    this.shiftId,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id']?.toString(),
      message: json['message'] as String?,
      rating: json['rating'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (message != null && message!.isNotEmpty) 'message': message,
      'rating': rating,
      if (departmentId != null && departmentId!.isNotEmpty) 'department_id': departmentId,
      if (shiftId != null && shiftId!.isNotEmpty) 'shift_id': shiftId,
    };
  }
}