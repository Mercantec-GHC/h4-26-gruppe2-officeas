import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLogin = true; // Toggle between login and register

  // For registration
  final _nameController = TextEditingController();
  final _departmentIdController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _departmentIdController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_isLogin) {
        context.read<AuthBloc>().add(
          LoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
      } else {
        context.read<AuthBloc>().add(
          RegisterRequested(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            departmentId: _departmentIdController.text.trim(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            context.go('/');
          } else if (state is AuthPendingApproval) {
            context.go('/pending-approval', extra: state.message);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [scheme.surface, scheme.surfaceContainerHighest]
                        : [scheme.primary, scheme.primaryContainer],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 1100 : 520,
                        ),
                        child: isWide
                            ? Row(
                                children: [
                                  // Left illustration / info
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(40),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? scheme
                                                        .surfaceContainerHighest
                                                  : Colors.white.withValues(
                                                      alpha: 0.08,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              Icons.business,
                                              size: 48,
                                              color: isDark
                                                  ? scheme.primary
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'Welcome to Office A/S',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineLarge
                                                ?.copyWith(
                                                  color: isDark
                                                      ? scheme.onSurface
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'A modern app to manage shifts, tickets and feedback. Sign in to continue.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: isDark
                                                      ? Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color
                                                            ?.withValues(
                                                              alpha: 0.78,
                                                            )
                                                      : Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 24),

                                  // Right: card with form
                                  Expanded(
                                    child: Card(
                                      elevation: 12,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(32),
                                        child: _buildAuthForm(context, state),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: _buildAuthForm(context, state),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context, AuthState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.business,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Office A/S',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          _isLogin
              ? 'Sign in to continue'
              : 'Create your account (requires HR/Ledelse approval)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 20),

        // Form
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(
                    context,
                    'Full name',
                    Icons.person,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration(context, 'Email', Icons.email),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: _inputDecoration(
                  context,
                  'Password',
                  Icons.lock,
                  suffix: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Please enter your password';
                  if (v.length < 6)
                    return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departmentIdController,
                  decoration: _inputDecoration(
                    context,
                    'Department ID',
                    Icons.business,
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter department ID'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'After signup, your account is pending HR/Ledelse approval before you can log in.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state is AuthLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: state is AuthLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? 'Sign in' : 'Create account'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),

        // Social
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: state is AuthLoading
                ? null
                : () => context.read<AuthBloc>().add(GoogleSignInRequested()),
            icon: Image.asset(
              _googleLogoAsset(context),
              height: 20,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            label: const Text('Continue with Google'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: state is AuthLoading
                ? null
                : () => context.read<AuthBloc>().add(GitHubSignInRequested()),
            icon: Image.asset(
              _githubLogoAsset(context),
              height: 20,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            label: const Text('Continue with GitHub'),
          ),
        ),

        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          child: Text(
            _isLogin
                ? "Don't have an account? Sign up"
                : 'Already have an account? Sign in',
          ),
        ),
      ],
    );
  }

  String _googleLogoAsset(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'assets/google_logo_dark.png'
        : 'assets/google_logo_light.png';
  }

  String _githubLogoAsset(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'assets/github_logo_dark.png'
        : 'assets/github_logo_light.png';
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      prefixIcon: Icon(icon),
      labelText: label,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: isDark ? scheme.surfaceContainerHighest : Colors.grey.shade50,
    );
  }
}
