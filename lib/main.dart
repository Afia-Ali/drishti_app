import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings.dart';
import 'services/role_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load saved settings
  await AppSettings().load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings(),
      builder: (context, _) {
        final isDark = AppSettings().isDarkTheme;
        return MaterialApp(
          title: 'Drishti',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
          ),
          home: const _AuthGate(),
        );
      },
    );
  }
}

/// Decides initial screen based on auth state
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const WelcomeScreen();
        }

        // Logged in: resolve role and route accordingly
        return FutureBuilder<Widget>(
          future: RoleRouter.resolveHomeScreen(),
          builder: (context, screenSnapshot) {
            if (screenSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }
            return screenSnapshot.data ?? const WelcomeScreen();
          },
        );
      },
    );
  }
}

/// Branded splash while auth + role check happens
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E40AF),
              Color(0xFF2563EB),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility,
                color: Colors.white,
                size: 72,
              ),
              SizedBox(height: 20),
              Text(
                'Drishti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
