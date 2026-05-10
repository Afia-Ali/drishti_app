// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/app_settings.dart';
import '../services/journal_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final AppSettings _settings = AppSettings();
  final JournalService _journal = JournalService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Set<DateTime> _datesWithDetections = {};
  List<Map<String, dynamic>> _selectedDayDetections = [];
  Map<String, dynamic>? _stats;

  bool _loadingMonth = false;
  bool _loadingDay = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _selectedDay = DateTime.now();
    _loadStats();
    _loadMonth(_focusedDay);
    _loadDay(_selectedDay!);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _journal.getStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  Future<void> _loadMonth(DateTime month) async {
    if (_loadingMonth) return;
    setState(() => _loadingMonth = true);

    try {
      final dates = await _journal.getDatesWithDetections(
        year: month.year,
        month: month.month,
      );
      if (mounted) {
        setState(() {
          _datesWithDetections = dates;
        });
      }
    } catch (e) {
      print('loadMonth error: $e');
    } finally {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  Future<void> _loadDay(DateTime day) async {
    if (_loadingDay) return;
    setState(() => _loadingDay = true);

    try {
      final detections = await _journal.getDetectionsForDate(day);
      if (mounted) {
        setState(() => _selectedDayDetections = detections);
      }
    } catch (e) {
      print('loadDay error: $e');
    } finally {
      if (mounted) setState(() => _loadingDay = false);
    }
  }

  Color _colorForClass(String className) {
    final classMap = [
      'bike',
      'cng',
      'leguna',
      'rickshaw',
      'trucks',
      'person',
      'car',
      'bus',
      'chair',
      'bed',
      'dining_table',
      'cup',
      'bottle',
      'laptop',
      'cell_phone',
      'tv',
      'book',
      'backpack',
      'handbag',
      'traffic_light',
      'stop_sign',
    ];
    final classId = classMap.indexOf(className);
    final hue = ((classId >= 0 ? classId : 0) * 137.5) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.95).toColor();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
          'Journal',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: textColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          await _loadMonth(_focusedDay);
          if (_selectedDay != null) await _loadDay(_selectedDay!);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Stats Row =====
              if (_stats != null)
                _buildStatsRow(
                  cardColor: cardColor,
                  isDark: isDark,
                  accent: accent,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),

              const SizedBox(height: 20),

              // ===== Calendar Card =====
              Container(
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
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: TableCalendar(
                  firstDay: DateTime(2024, 1, 1),
                  lastDay: DateTime.now().add(const Duration(days: 1)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      _selectedDay != null && _isSameDay(day, _selectedDay!),
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadDay(selectedDay);
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                    _loadMonth(focusedDay);
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  eventLoader: (day) {
                    final hasData = _datesWithDetections.any(
                      (d) => _isSameDay(d, day),
                    );
                    return hasData ? ['detection'] : [];
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: TextStyle(color: textColor),
                    weekendTextStyle: TextStyle(
                      color: textColor.withOpacity(0.85),
                    ),
                    todayDecoration: BoxDecoration(
                      color: accent.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    todayTextStyle: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                    markerSize: 6,
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: textColor,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: textColor,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendStyle: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== Selected Day Section =====
              _buildSelectedDayHeader(
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),

              const SizedBox(height: 12),

              _buildSelectedDayContent(
                cardColor: cardColor,
                isDark: isDark,
                accent: accent,
                textColor: textColor,
                subTextColor: subTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required Color cardColor,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final totalDetections = (_stats?['totalDetections'] ?? 0) as int;
    final totalSessions = (_stats?['totalSessions'] ?? 0) as int;
    final topClasses =
        (_stats?['topClasses'] ?? <String, int>{}) as Map<String, int>;

    String topClass = '–';
    if (topClasses.isNotEmpty) {
      final sorted = topClasses.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topClass = sorted.first.key;
    }

    return Row(
      children: [
        Expanded(
          child: _statCard(
            cardColor: cardColor,
            isDark: isDark,
            accent: accent,
            textColor: textColor,
            subTextColor: subTextColor,
            icon: Icons.visibility,
            value: '$totalDetections',
            label: 'Detections',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            cardColor: cardColor,
            isDark: isDark,
            accent: accent,
            textColor: textColor,
            subTextColor: subTextColor,
            icon: Icons.history,
            value: '$totalSessions',
            label: 'Sessions',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            cardColor: cardColor,
            isDark: isDark,
            accent: accent,
            textColor: textColor,
            subTextColor: subTextColor,
            icon: Icons.star,
            value: topClass,
            label: 'Top class',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required Color cardColor,
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
        color: cardColor,
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
              fontSize: 20,
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

  Widget _buildSelectedDayHeader({
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    final day = _selectedDay ?? DateTime.now();
    final isToday = _isSameDay(day, DateTime.now());

    return Row(
      children: [
        Icon(Icons.calendar_today, color: accent, size: 18),
        const SizedBox(width: 8),
        Text(
          isToday ? 'Today' : _formatDate(day),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const Spacer(),
        Text(
          '${_selectedDayDetections.length} ${_selectedDayDetections.length == 1 ? 'detection' : 'detections'}',
          style: TextStyle(
            fontSize: 13,
            color: subTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayContent({
    required Color cardColor,
    required bool isDark,
    required Color accent,
    required Color textColor,
    required Color subTextColor,
  }) {
    if (_loadingDay) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: accent,
          strokeWidth: 2,
        ),
      );
    }

    if (_selectedDayDetections.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
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
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 36,
              color: subTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 10),
            Text(
              'No detections on this day',
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
      );
    }

    // Group detections by hour for cleaner display
    return Column(
      children: _selectedDayDetections.map((d) {
        final className = d['className'] as String;
        final confidence = (d['confidence'] as num).toDouble();
        final timestamp = d['timestamp'] as DateTime?;
        final color = _colorForClass(className);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      className.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(confidence * 100).toInt()}% confidence',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(timestamp),
                style: TextStyle(
                  fontSize: 13,
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
