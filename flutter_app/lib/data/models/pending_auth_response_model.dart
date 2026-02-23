import 'user_model.dart';

class PendingAuthResponseModel {
  final String message;
  final UserModel user;

  PendingAuthResponseModel({required this.message, required this.user});

  factory PendingAuthResponseModel.fromJson(Map<String, dynamic> json) {
    return PendingAuthResponseModel(
      message:
          json['message']?.toString() ??
          'Your account is pending HR/Ledelse approval.',
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }
}
