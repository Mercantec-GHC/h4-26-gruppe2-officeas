import 'package:flutter/foundation.dart';
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

    // Check auth status on initialization
    _checkAuthStatusOnInit();
  }

  Future<void> _checkAuthStatusOnInit() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final token = await _authService.getToken();
        final hasUser = await _authService.hasStoredUser();
        // Only attempt to restore auth if we have both token and stored user data
        if (token != null && hasUser) {
          _currentToken = token;
          // Try to restore user from local storage
          try {
            final userMap = await _authService.getUser();
            if (userMap != null) {
              _currentUser = UserModel.fromJson(userMap);
            }
          } catch (_) {
            // ignore parse errors
          }

          add(CheckAuthStatus());
        }
      }
    } catch (e) {
      // Silent fail on init
      debugPrint('Auth status check failed on init: $e');
    }
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
      final result = await _authService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        departmentId: event.departmentId,
      );
      if (result.isPendingApproval) {
        _currentUser = null;
        _currentToken = null;
        emit(
          AuthPendingApproval(
            message:
                result.pending?.message ??
                'Your account is pending HR/Ledelse approval.',
          ),
        );
        return;
      }

      final response = result.auth!;
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
      final result = await _authService.signInWithGoogle();

      if (result.isPendingApproval) {
        _currentUser = null;
        _currentToken = null;
        emit(
          AuthPendingApproval(
            message:
                result.pending?.message ??
                'Your account is pending HR/Ledelse approval.',
          ),
        );
        return;
      }

      final response = result.auth!;
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
      final result = await _authService.signInWithGitHub();

      if (result.isPendingApproval) {
        _currentUser = null;
        _currentToken = null;
        emit(
          AuthPendingApproval(
            message:
                result.pending?.message ??
                'Your account is pending HR/Ledelse approval.',
          ),
        );
        return;
      }

      final response = result.auth!;
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
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final token = await _authService.getToken();
        if (token != null) {
          // Only restore to Authenticated if we also have a current user loaded
          if (_currentUser != null) {
            emit(Authenticated(user: _currentUser!, token: token));
          } else {
            emit(Unauthenticated());
          }
        } else {
          emit(Unauthenticated());
        }
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }
}
