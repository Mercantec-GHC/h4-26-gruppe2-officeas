import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // Navigation is handled by BlocBuilder in main.dart
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
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A66FF), Color(0xFF4B7CFF)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Decorative header with logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.business,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'OfficeAs',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin ? 'Welcome back — sign in to continue' : 'Create your OfficeAs account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 28),

                        // Card with form
                        Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isLogin) ...[
                                    _buildTextField(
                                      controller: _nameController,
                                      label: 'Full name',
                                      icon: Icons.person,
                                      validator: (v) => v == null || v.isEmpty ? 'Please enter your name' : null,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    icon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please enter your email';
                                      if (!v.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock,
                                    obscureText: !_isPasswordVisible,
                                    suffix: IconButton(
                                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please enter your password';
                                      if (v.length < 6) return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                  ),
                                  if (!_isLogin) ...[
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _departmentIdController,
                                      label: 'Department ID',
                                      icon: Icons.business_center,
                                      helperText: 'Ask your admin for the ID',
                                      validator: (v) => v == null || v.isEmpty ? 'Please enter department ID' : null,
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: state is AuthLoading ? null : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0A66FF),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: state is AuthLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(_isLogin ? 'Sign in' : 'Create account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      child: Text('Forgot password?', style: TextStyle(color: Colors.grey.shade600)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Social buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: state is AuthLoading ? null : () => context.read<AuthBloc>().add(GoogleSignInRequested()),
                                icon: Image.asset('assets/google_logo.png', height: 20, errorBuilder: (c,e,s)=>const SizedBox.shrink()),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: Colors.white,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: state is AuthLoading ? null : () => context.read<AuthBloc>().add(GitHubSignInRequested()),
                                icon: Image.asset('assets/github_logo.png', height: 20, errorBuilder: (c,e,s)=>const SizedBox.shrink()),
                                label: const Text('GitHub'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.12),
                                  foregroundColor: Colors.white,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin ? "Don\'t have an account? Sign up" : 'Already have an account? Sign in',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
