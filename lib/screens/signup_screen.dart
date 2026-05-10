import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/user_role.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final AppSettings _settings = AppSettings();

  UserRole? selectedRole;
  bool agreedToTerms = false;
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> signUp() async {
    if (fullNameController.text.trim().isEmpty) {
      showMessage('Please enter your full name');
      return;
    }
    if (emailController.text.trim().isEmpty) {
      showMessage('Please enter your email');
      return;
    }
    if (passwordController.text.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      showMessage('Passwords do not match');
      return;
    }
    if (selectedRole == null) {
      showMessage('Please select your role');
      return;
    }
    if (!agreedToTerms) {
      showMessage('Please agree to Terms & Conditions');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        name: fullNameController.text.trim(),
        role: selectedRole!,
      );

      if (mounted) {
        showMessage('Account created successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
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
        title: Text(
          'Create Account',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ===== Role Picker =====
              Text(
                'I am a',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              _roleCard(
                role: UserRole.visionUser,
                icon: Icons.visibility,
                title: 'Vision User',
                subtitle:
                    'I am visually impaired and use the app for daily assistance',
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 12),
              _roleCard(
                role: UserRole.caregiver,
                icon: Icons.favorite,
                title: 'Caregiver',
                subtitle:
                    'I support a family member or friend who is visually impaired',
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),

              const SizedBox(height: 24),

              // ===== Form fields =====
              _label('Full Name', textColor),
              _textField(
                controller: fullNameController,
                hint: 'Enter your full name',
                fieldFill: fieldFill,
                fieldBorder: fieldBorder,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 20),

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
              const SizedBox(height: 20),

              _label('Confirm Password', textColor),
              _textField(
                controller: confirmPasswordController,
                hint: '••••••••',
                obscureText: _obscureConfirm,
                fieldFill: fieldFill,
                fieldBorder: fieldBorder,
                textColor: textColor,
                subTextColor: subTextColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: subTextColor,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ===== Terms checkbox =====
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: agreedToTerms,
                      onChanged: (bool? value) {
                        setState(() => agreedToTerms = value ?? false);
                      },
                      activeColor: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: textColor, fontSize: 14),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ===== Sign up button =====
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signUp,
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
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: subTextColor),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
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

  Widget _roleCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final selected = selectedRole == role;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? accent.withOpacity(isDark ? 0.2 : 0.08)
                : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06)),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
