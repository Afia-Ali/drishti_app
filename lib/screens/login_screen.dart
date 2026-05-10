import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/role_router.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final AppSettings _settings = AppSettings();

  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> signIn() async {
    if (emailController.text.trim().isEmpty) {
      showMessage('Please enter your email');
      return;
    }
    if (passwordController.text.isEmpty) {
      showMessage('Please enter your password');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (mounted) {
        showMessage('Login successful!');
        // Route based on user role (vision user vs caregiver)
        await RoleRouter.navigateToHome(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = 'No account found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      }
      showMessage(message);
    } catch (e) {
      showMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _settings.isDarkTheme;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B);
    final fieldFill =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9);
    final fieldBorder =
        isDark ? Colors.white.withOpacity(0.08) : Colors.transparent;
    const accent = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Title
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 16, color: subTextColor),
              ),
              const SizedBox(height: 40),

              // Email
              _label('Email', textColor),
              _textField(
                controller: emailController,
                hint: 'your.email@example.com',
                keyboardType: TextInputType.emailAddress,
                fieldFill: fieldFill,
                fieldBorder: fieldBorder,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 20),

              // Password
              _label('Password', textColor),
              _textField(
                controller: passwordController,
                hint: '••••••••',
                obscureText: _obscurePassword,
                fieldFill: fieldFill,
                fieldBorder: fieldBorder,
                textColor: textColor,
                subTextColor: subTextColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: subTextColor,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Sign In button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Forgot password
              Center(
                child: TextButton(
                  onPressed: () {
                    showMessage('Password reset coming soon');
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign up link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: subTextColor),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Helpers =====

  Widget _label(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required Color fieldFill,
    required Color fieldBorder,
    required Color textColor,
    required Color subTextColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: subTextColor),
        filled: true,
        fillColor: fieldFill,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
