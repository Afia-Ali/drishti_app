import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/linking_service.dart';
import 'caregiver_journal_screen.dart';
import 'welcome_screen.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  final AppSettings _settings = AppSettings();
  final LinkingService _linkingService = LinkingService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
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
    if (name.isEmpty) return 'C';
    return name[0].toUpperCase();
  }

  void _openJournal(String visionUserId, String visionUserName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaregiverJournalScreen(
          visionUserId: visionUserId,
          visionUserName: visionUserName,
        ),
      ),
    );
  }

  Future<void> _showAddVisionUserSheet() async {
    final isDark = _settings.isDarkTheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AddVisionUserSheet(
          isDark: isDark,
          onSubmit: (code) async {
            await _handleSendRequest(sheetContext, code);
          },
        );
      },
    );
  }

  Future<void> _handleSendRequest(
    BuildContext sheetContext,
    String code,
  ) async {
    if (_isSending) return;
    if (code.trim().isEmpty) {
      _showSnack('Please enter a linking code');
      return;
    }

    _isSending = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? errorMessage;
    String? successName;
    String? infoMessage;

    try {
      final visionUser = await _linkingService.findVisionUserByCode(code);

      if (visionUser == null) {
        errorMessage = 'Invalid code. Please check and try again.';
      } else {
        final result = await _linkingService.sendLinkRequest(
          visionUserId: visionUser['uid'] as String,
        );

        if (result == 'already_linked') {
          infoMessage = 'You are already linked with ${visionUser['name']}';
        } else if (result == 'already_pending') {
          infoMessage = 'Request already sent. Waiting for response.';
        } else if (result == null) {
          errorMessage = 'Failed to send request. Try again.';
        } else {
          successName = visionUser['name'] as String;
        }
      }
    } catch (e) {
      errorMessage = 'Error: ${e.toString()}';
    }

    _isSending = false;

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (successName != null && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    if (successName != null) {
      _showSnack('Request sent to $successName', success: true);
    } else if (errorMessage != null) {
      _showSnack(errorMessage);
    } else if (infoMessage != null) {
      _showSnack(infoMessage);
    }
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF10B981) : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmUnlink(String visionUserId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Vision User?'),
        content: Text(
          'You will no longer have access to $name\'s data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _linkingService.unlinkVisionUser(visionUserId);
    _showSnack(ok ? '$name unlinked' : 'Failed to unlink');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = _settings.isDarkTheme;
    final bgColor = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B);
    const accent = Color(0xFF2563EB);

    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Caregiver';

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
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _showAddVisionUserSheet,
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text(
                      'Add Vision User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'My Vision Users',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _linkingService.watchLinkedVisionUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingCard(cardBg, isDark);
                    }
                    final users = snapshot.data ?? [];
                    if (users.isEmpty) {
                      return _buildEmptyState(
                        cardBg: cardBg,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        subTextColor: subTextColor,
                      );
                    }
                    return Column(
                      children: users
                          .map((u) => _buildVisionUserCard(
                                user: u,
                                cardBg: cardBg,
                                isDark: isDark,
                                accent: accent,
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _linkingService.watchSentRequests(),
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7)
                            .withOpacity(isDark ? 0.1 : 1),
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
                                Icons.hourglass_top,
                                color: Color(0xFFF59E0B),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pending Requests (${requests.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for the vision user to accept your request.',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How linking works',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ask the vision user to share their linking code from their app settings. Once they accept your request, you can view their journal and receive alerts.',
                              style: TextStyle(
                                fontSize: 13,
                                color: subTextColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Caregiver Dashboard',
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

  Widget _buildLoadingCard(Color cardBg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
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
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState({
    required Color cardBg,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline, color: accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'No Vision Users Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add Vision User" above to link with someone using their code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionUserCard({
    required Map<String, dynamic> user,
    required Color cardBg,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final name = user['name'] as String;
    final email = user['email'] as String;
    final id = user['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openJournal(id, name),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'View Journal',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmUnlink(id, name),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: subTextColor,
                    size: 22,
                  ),
                  tooltip: 'Unlink',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddVisionUserSheet extends StatefulWidget {
  final bool isDark;
  final Function(String code) onSubmit;

  const _AddVisionUserSheet({
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<_AddVisionUserSheet> createState() => _AddVisionUserSheetState();
}

class _AddVisionUserSheetState extends State<_AddVisionUserSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSendTap() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_codeController.text);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF111111) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.65) : const Color(0xFF64748B);
    final fieldFill =
        isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    const accent = Color(0xFF2563EB);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Vision User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Enter the linking code shared by the vision user. The format is DRISHTI-XXXX.',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Linking Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              autofocus: true,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'DRISHTI-XXXX',
                hintStyle: TextStyle(
                  color: subTextColor,
                  letterSpacing: 1.5,
                ),
                filled: true,
                fillColor: fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _onSendTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Send Request',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
