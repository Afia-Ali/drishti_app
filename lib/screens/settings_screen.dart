// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/bangla_tts.dart';
import '../services/linking_service.dart';
import '../services/user_role.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings();
  final AuthService _authService = AuthService();
  final LinkingService _linkingService = LinkingService();
  final FlutterTts _enTts = FlutterTts();
  final BanglaTTS _bnTts = BanglaTTS();

  bool _isTesting = false;
  UserRole _userRole = UserRole.unknown;
  String? _linkingCode;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _enTts.stop();
    _bnTts.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final role = await _authService.getCurrentUserRole();
      String? code;
      if (role == UserRole.visionUser) {
        code = await _linkingService.getMyLinkingCode();
      }
      if (mounted) {
        setState(() {
          _userRole = role;
          _linkingCode = code;
        });
      }
    } catch (e) {
      print('Settings _loadProfile error: $e');
    }
  }

  Future<void> _testVoice() async {
    if (_isTesting) return;
    setState(() => _isTesting = true);

    try {
      if (_settings.language == 'bn') {
        await _enTts.stop();
        await _bnTts.speak('আমি একটি গাড়ি এবং একজন মানুষ দেখছি');
      } else {
        await _bnTts.stop();
        await _enTts.setLanguage('en-US');
        await _enTts.setSpeechRate(_settings.voiceRate);
        await _enTts.setVolume(1.0);
        await _enTts.setPitch(1.0);
        await _enTts.speak('I see a car and a person');
      }
    } catch (e) {
      print('Test voice error: $e');
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isTesting = false);
        });
      }
    }
  }

  Future<void> _speakLinkingCode() async {
    if (_linkingCode == null) return;
    try {
      await _enTts.setLanguage('en-US');
      await _enTts.setSpeechRate(0.4);
      final spelled = _linkingCode!.split('').join(', ');
      await _enTts.speak('Your linking code is $spelled');
    } catch (e) {
      print('Speak code error: $e');
    }
  }

  Future<void> _copyCode() async {
    if (_linkingCode == null) return;
    await Clipboard.setData(ClipboardData(text: _linkingCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerateCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Linking Code?'),
        content: const Text(
          'Your old code will stop working immediately. You will need to share the new code with anyone who wants to link with you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newCode = await _authService.regenerateLinkingCode();
    if (mounted && newCode != null) {
      setState(() => _linkingCode = newCode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New code generated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _acceptRequest(String requestId, String caregiverName) async {
    final ok = await _linkingService.acceptRequest(requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ok ? '$caregiverName is now linked' : 'Failed to accept'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await _linkingService.rejectRequest(requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeCaregiver(String caregiverId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Caregiver?'),
        content: Text(
          '$name will no longer have access to your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _linkingService.removeCaregiver(caregiverId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '$name removed' : 'Failed to remove'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _settings.isDarkTheme;
    final bgColor = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B);
    const accent = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: textColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Linking section (vision user only) =====
            if (_userRole == UserRole.visionUser && _linkingCode != null) ...[
              _sectionHeader('Caregivers', subTextColor),
              const SizedBox(height: 12),
              _buildLinkingCodeCard(
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 16),
              _buildPendingRequestsSection(
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 16),
              _buildLinkedCaregiversSection(
                cardColor: cardColor,
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 28),
            ],

            // ===== Appearance section =====
            _sectionHeader('Appearance', subTextColor),
            const SizedBox(height: 12),
            _card(
              cardColor: cardColor,
              isDark: isDark,
              child: _toggleRow(
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: 'Dark Theme',
                subtitle: isDark ? 'Dark mode active' : 'Light mode active',
                value: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
                onChanged: (v) => _settings.setDarkTheme(v),
              ),
            ),

            const SizedBox(height: 28),

            // ===== Voice section (vision user only) =====
            if (_userRole == UserRole.visionUser) ...[
              _sectionHeader('Voice', subTextColor),
              const SizedBox(height: 12),
              _card(
                cardColor: cardColor,
                isDark: isDark,
                child: Column(
                  children: [
                    _toggleRow(
                      icon: _settings.ttsEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      title: 'Voice Feedback',
                      subtitle: _settings.ttsEnabled
                          ? 'Voice will announce detections'
                          : 'Voice is muted',
                      value: _settings.ttsEnabled,
                      accent: accent,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      onChanged: (v) => _settings.setTtsEnabled(v),
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      height: 1,
                    ),
                    _languageRow(
                      accent: accent,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      isDark: isDark,
                    ),
                    Divider(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      height: 1,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed, color: accent, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Voice Rate',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _rateLabel(_settings.voiceRate),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accent,
                              inactiveTrackColor: accent.withOpacity(0.2),
                              thumbColor: accent,
                              overlayColor: accent.withOpacity(0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                            ),
                            child: Slider(
                              value: _settings.voiceRate,
                              min: 0.3,
                              max: 0.7,
                              divisions: 4,
                              onChanged: (v) => _settings.setVoiceRate(v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Slow',
                                    style: TextStyle(
                                        color: subTextColor, fontSize: 12)),
                                Text('Fast',
                                    style: TextStyle(
                                        color: subTextColor, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Test Voice button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _settings.ttsEnabled ? _testVoice : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: accent.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTesting ? Icons.graphic_eq : Icons.volume_up,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isTesting ? 'Playing...' : 'Test Voice',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  _settings.ttsEnabled
                      ? 'Tap to preview current voice settings'
                      : 'Enable voice feedback to test',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],

            // ===== About section =====
            _sectionHeader('About', subTextColor),
            const SizedBox(height: 12),
            _card(
              cardColor: cardColor,
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, color: accent, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Drishti Vision',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI vision assistant for visually impaired users',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // LINKING UI WIDGETS
  // =====================================

  Widget _buildLinkingCodeCard({
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Your Linking Code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _linkingCode ?? '...',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accent,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with a caregiver. They will need it to link with you.',
            style: TextStyle(
              fontSize: 13,
              color: subTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _speakLinkingCode,
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Speak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _regenerateCode,
                icon: Icon(Icons.refresh, color: subTextColor),
                tooltip: 'Regenerate code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection({
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _linkingService.watchPendingRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7).withOpacity(isDark ? 0.1 : 1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Requests (${requests.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...requests.map((req) => _buildRequestTile(
                    req: req,
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestTile({
    required Map<String, dynamic> req,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    final name = req['fromCaregiverName'] as String;
    final email = req['fromCaregiverEmail'] as String;
    final id = req['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: TextStyle(
              fontSize: 12,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(id, name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectRequest(id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCaregiversSection({
    required Color cardColor,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _linkingService.watchLinkedCaregivers(),
      builder: (context, snapshot) {
        final caregivers = snapshot.data ?? [];
        if (caregivers.isEmpty) return const SizedBox.shrink();

        return _card(
          cardColor: cardColor,
          isDark: isDark,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.people, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Linked Caregivers (${caregivers.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              ...caregivers.map((c) => _buildCaregiverTile(
                    caregiver: c,
                    accent: accent,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaregiverTile({
    required Map<String, dynamic> caregiver,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final name = caregiver['name'] as String;
    final email = caregiver['email'] as String;
    final id = caregiver['id'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeCaregiver(id, name),
            icon: Icon(
              Icons.remove_circle_outline,
              color: subTextColor,
              size: 22,
            ),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  // =====================================
  // ORIGINAL HELPERS
  // =====================================

  String _rateLabel(double rate) {
    if (rate <= 0.35) return 'Slow';
    if (rate <= 0.45) return 'Normal-';
    if (rate <= 0.55) return 'Normal';
    if (rate <= 0.65) return 'Fast';
    return 'Very Fast';
  }

  Widget _sectionHeader(String title, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: subTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _card({
    required Color cardColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
            activeTrackColor: accent.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _languageRow({
    required Color accent,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.translate, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _settings.language == 'bn' ? 'Bangla (বাংলা)' : 'English',
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _langButton('EN', 'en', accent, textColor),
                _langButton('বাং', 'bn', accent, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langButton(String label, String code, Color accent, Color textColor) {
    final selected = _settings.language == code;
    return GestureDetector(
      onTap: () => _settings.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textColor.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
