import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_settings.dart';
import 'camera_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AppSettings _settings = AppSettings();

  int _totalSessions = 0;
  int _totalDetections = 0;
  String _lastDetectedClass = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _totalSessions = prefs.getInt('total_sessions') ?? 0;
        _totalDetections = prefs.getInt('total_detections') ?? 0;
        _lastDetectedClass = prefs.getString('last_detected') ?? '';
      });
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  String _getInitial(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = _settings.isDarkTheme;
    final bgColor = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B);
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    const accent = Color(0xFF2563EB);

    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroBanner(
                accent: accent,
                isDark: isDark,
                displayName: displayName,
                onLogout: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        icon: Icons.visibility,
                        value: _totalDetections.toString(),
                        label: 'Detections',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        icon: Icons.history,
                        value: _totalSessions.toString(),
                        label: 'Sessions',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        icon: Icons.translate,
                        value: _settings.language == 'bn' ? 'বাং' : 'EN',
                        label: 'Language',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCameraCard(
                  accent: accent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JournalScreen(),
                          ),
                        ).then((_) => _loadStats());
                      },
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 13,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActivityCard(
                  cardBg: cardBg,
                  isDark: isDark,
                  accent: accent,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _miniCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        icon: Icons.book,
                        title: 'Journal',
                        subtitle: 'View your detections',
                        comingSoon: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const JournalScreen(),
                            ),
                          ).then((_) => _loadStats());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniCard(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        icon: Icons.settings,
                        title: 'Settings',
                        subtitle: 'Voice and theme',
                        comingSoon: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          ).then((_) => _loadStats());
                        },
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

  Widget _buildHeroBanner({
    required Color accent,
    required bool isDark,
    required String displayName,
    required VoidCallback onLogout,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E40AF),
            accent,
            const Color(0xFF3B82F6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _getInitial(displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${_getGreeting()},',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Vision Ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Color cardBg,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard({
    required Color accent,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraScreen(),
          ),
        ).then((_) => _loadStats());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(isDark ? 0.25 : 0.12),
              accent.withOpacity(isDark ? 0.10 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.5),
                        blurRadius: 20 * _pulseController.value,
                        spreadRadius: 4 * _pulseController.value,
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vision Assistant',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastDetectedClass.isNotEmpty
                        ? 'Last seen: $_lastDetectedClass'
                        : 'Tap to detect objects',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Camera',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required Color cardBg,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final hasActivity = _lastDetectedClass.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: hasActivity
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.remove_red_eye, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last detected',
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastDetectedClass,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 36,
                      color: subTextColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open camera to start detecting',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _miniCard({
    required Color cardBg,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool comingSoon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  if (comingSoon) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Soon',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
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
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
