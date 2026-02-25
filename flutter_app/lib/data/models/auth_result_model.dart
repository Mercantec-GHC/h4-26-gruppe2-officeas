import 'auth_response_model.dart';
import 'pending_auth_response_model.dart';

class AuthResultModel {
  final AuthResponseModel? auth;
  final PendingAuthResponseModel? pending;

  AuthResultModel._({this.auth, this.pending});

  factory AuthResultModel.authenticated(AuthResponseModel auth) {
    return AuthResultModel._(auth: auth);
  }

  factory AuthResultModel.pending(PendingAuthResponseModel pending) {
    return AuthResultModel._(pending: pending);
  }

  bool get isAuthenticated => auth != null;
  bool get isPendingApproval => pending != null;
}
