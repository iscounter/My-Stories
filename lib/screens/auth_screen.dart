import 'package:flutter/material.dart';
import 'package:my_stories/models/user_profile.dart';
import 'package:my_stories/repositories/auth_repository.dart';
import 'package:my_stories/screens/home_screen.dart';
import 'package:my_stories/services/story_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.storyRepository,
  });

  final AuthRepository authRepository;
  final StoryRepository storyRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'reader@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _usernameController = TextEditingController(text: 'reader');
  final _displayNameController = TextEditingController(text: 'Reader One');
  bool _isLogin = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final user = UserProfile(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        email: _emailController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? _emailController.text.trim().split('@').first
            : _usernameController.text.trim(),
        displayName: _displayNameController.text.trim().isEmpty
            ? 'Reader'
            : _displayNameController.text.trim(),
        bio: 'StoryShare reader and storyteller.',
        followerCount: 0,
        followingCount: 0,
        storyCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await widget.authRepository.signIn(user);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: HomeScreen(repository: widget.storyRepository),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isLogin ? 'Welcome back' : 'Create your account',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17152B),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Sign in to continue reading and sharing.'
                          : 'Join the community and publish your next story.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF77748A),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!_isLogin) ...[
                      _AuthField(
                        controller: _displayNameController,
                        label: 'Display name',
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Please enter a display name.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _AuthField(
                        controller: _usernameController,
                        label: 'Username',
                        validator: (value) =>
                            (value == null || value.trim().length < 3)
                            ? 'Use at least 3 characters.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _AuthField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required.';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _AuthField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLogin ? 'Sign in' : 'Create account'),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? 'Need an account? Create one'
                            : 'Already have an account? Sign in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}
