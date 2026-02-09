class FeedbackModel {
  final String? id;
  final String message; 
  final int rating; 

  FeedbackModel({
    this.id,
    required this.message,
    required this.rating,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'],
      message: json['message'],
      rating: json['rating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'rating': rating,
    };
  }
}