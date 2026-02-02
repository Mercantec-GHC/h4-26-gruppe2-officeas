import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  UserModel? _currentUser;
  String? _currentToken;

  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;

  AuthBloc({AuthService? authService})
    : _authService = authService ?? AuthService(),
      super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<GitHubSignInRequested>(_onGitHubSignInRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.login(event.email, event.password);
      _currentUser = response.user;
      _currentToken = response.token;
      emit(Authenticated(user: response.user, token: response.token));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        departmentId: event.departmentId,
      );
      _currentUser = response.user;
      _currentToken = response.token;
      emit(Authenticated(user: response.user, token: response.token));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.signInWithGoogle();
      _currentUser = response.user;
      _currentToken = response.token;
      emit(Authenticated(user: response.user, token: response.token));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGitHubSignInRequested(
    GitHubSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authService.signInWithGitHub();
      _currentUser = response.user;
      _currentToken = response.token;
      emit(Authenticated(user: response.user, token: response.token));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.logout();
    _currentUser = null;
    _currentToken = null;
    emit(Unauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      // For now, we'll just mark as authenticated if token exists
      emit(Unauthenticated());
    } else {
      emit(Unauthenticated());
    }
  }
}
