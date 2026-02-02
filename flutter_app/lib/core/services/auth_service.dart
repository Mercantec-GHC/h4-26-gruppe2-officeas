import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../data/models/auth_response_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository;
  GoogleSignIn? _googleSignIn;
  bool _googleSignInInitialized = false;

  // OAuth configuration
  static const String googleClientId =
      '8318618298-6pnp9073pprc7f9lihjief5gb53u3p5h.apps.googleusercontent.com';
  static const String githubClientId = '';
  static const String githubRedirectUri = '';
  static const String githubAuthUrl =
      'https://github.com/login/oauth/authorize';

  AuthService({AuthRepository? authRepository, GoogleSignIn? googleSignIn})
    : _authRepository = authRepository ?? AuthRepository();

  // Lazy initialize Google Sign-In to prevent crashes
  void _initializeGoogleSignIn() {
    if (!kIsWeb && !_googleSignInInitialized) {
      try {
        _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        _googleSignInInitialized = true;
      } catch (e) {
        print('Failed to initialize Google Sign-In: $e');
      }
    }
  }

  // Regular email/password login
  Future<AuthResponseModel> login(String email, String password) async {
    return await _authRepository.login(email, password);
  }

  // Regular registration
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    required String departmentId,
  }) async {
    return await _authRepository.register(
      name: name,
      email: email,
      password: password,
      departmentId: departmentId,
    );
  }

  // Google Sign-In
  Future<AuthResponseModel> signInWithGoogle() async {
    // Google Sign-In on web requires additional setup
    // throws helpful error on web
    if (kIsWeb) {
      throw 'Google Sign-In is not supported on web yet. Please use email/password login or run on mobile/desktop.';
    }

    // Initialize Google Sign-In if not already done
    _initializeGoogleSignIn();

    if (_googleSignIn == null) {
      throw 'Google Sign-In could not be initialized. This feature requires additional platform configuration.';
    }

    try {
      // Sign out first to ensure account selection dialog appears
      await _googleSignIn!.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        throw 'Google sign-in was cancelled by user';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw 'Failed to get Google ID token';
      }

      // Use the ID token to authenticate with backend
      return await _authRepository.ssoLogin(
        provider: 'google',
        idToken: googleAuth.idToken!,
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email,
      );
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        throw e; // Rethrow cancellation as-is
      }
      throw 'Google sign-in failed: $e';
    }
  }

  // GitHub Sign-In
  Future<AuthResponseModel> signInWithGitHub() async {
    try {
      // Build the authorization URL
      final url = Uri.https('github.com', '/login/oauth/authorize', {
        'client_id': githubClientId,
        'redirect_uri': githubRedirectUri,
        'scope': 'user:email',
      });

      // Perform the authentication
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'officeas',
      );

      // Extract the code from the redirect URL
      final code = Uri.parse(result).queryParameters['code'];

      if (code == null) {
        throw 'No authorization code received';
      }

      // Call backend to exchange code for user info and get JWT
      // The backend will handle the token exchange with GitHub
      return await _authRepository.githubCallback(code);
    } catch (e) {
      throw 'GitHub sign-in failed: $e';
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authRepository.isLoggedIn();
  }

  // Get stored auth token
  Future<String?> getToken() async {
    return await _authRepository.getToken();
  }

  // Logout
  Future<void> logout() async {
    try {
      if (!kIsWeb && _googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
    } catch (e) {
      // Ignore Google sign-out errors
    }
    await _authRepository.logout();
  }
}
