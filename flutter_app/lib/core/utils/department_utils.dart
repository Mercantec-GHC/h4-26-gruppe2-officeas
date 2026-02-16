import '../../data/models/user_model.dart';

/// Returns true if the user is in the IT-Support (or IT) department.
/// Used to restrict ticket views and home "Seneste tickets" to IT Support only.
bool isItSupportDepartment(UserModel? user) {
  if (user == null) return false;

  final name = user.departmentName?.trim().toLowerCase() ?? '';

  return name == 'it support';
}
