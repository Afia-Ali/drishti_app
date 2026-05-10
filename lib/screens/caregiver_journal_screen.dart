// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/journal_service.dart';

class CaregiverJournalScreen extends StatefulWidget {
  final String visionUserId;
  final String visionUserName;

  const CaregiverJournalScreen({
    super.key,
    required this.visionUserId,
    required this.visionUserName,
  });

  @override
  State<CaregiverJournalScreen> createState() => _CaregiverJournalScreenState();
}

class _CaregiverJournalScreenState extends State<CaregiverJournalScreen> {
  final JournalService _journal = JournalService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Set<DateTime> _datesWithData = {};
  List<Map<String, dynamic>> _detections = [];
  List<Map<String, dynamic>> _sessions = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final dates = await _journal.getDatesWithDetectionsForUser(
        visionUserId: widget.visionUserId,
        year: _focusedDay.year,
        month: _focusedDay.month,
      );

      final detections = await _journal.getDetectionsForDateOfUser(
        visionUserId: widget.visionUserId,
        date: _selectedDay,
      );

      final sessions = await _journal.getSessionsForDateOfUser(
        visionUserId: widget.visionUserId,
        date: _selectedDay,
      );

      if (!mounted) return;
      setState(() {
        _datesWithData = dates;
        _detections = detections;
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      print('CaregiverJournal load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onDaySelected(DateTime selected, DateTime focused) async {
    if (isSameDay(_selectedDay, selected)) return;

    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
      _loading = true;
    });

    try {
      final detections = await _journal.getDetectionsForDateOfUser(
        visionUserId: widget.visionUserId,
        date: selected,
      );
      final sessions = await _journal.getSessionsForDateOfUser(
        visionUserId: widget.visionUserId,
        date: selected,
      );

      if (!mounted) return;
      setState(() {
        _detections = detections;
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      print('day select error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onPageChanged(DateTime focused) async {
    setState(() => _focusedDay = focused);

    try {
      final dates = await _journal.getDatesWithDetectionsForUser(
        visionUserId: widget.visionUserId,
        year: focused.year,
        month: focused.month,
      );
      if (!mounted) return;
      setState(() => _datesWithData = dates);
    } catch (e) {
      print('page change error: $e');
    }
  }

  // =====================================
  // SUMMARY GENERATION (the warm passage)
  // =====================================

  String _generateSummary() {
    final firstName = widget.visionUserName.split(' ').first;
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final dayWord = isToday ? 'today' : 'on this day';

    if (_detections.isEmpty && _sessions.isEmpty) {
      return "It looks like $firstName didn't use the app $dayWord. "
          "Maybe a calm day at home, or perhaps they were just resting.";
    }

    // Calculate total active duration
    Duration totalActive = Duration.zero;
    for (final s in _sessions) {
      final start = s['startedAt'] as DateTime?;
      final end = s['endedAt'] as DateTime?;
      if (start != null && end != null) {
        totalActive += end.difference(start);
      }
    }

    final totalMinutes = totalActive.inMinutes;
    final sessionCount = _sessions.length;
    final detectionCount = _detections.length;

    // Determine vibe from detection count
    String vibe;
    if (detectionCount < 8) {
      vibe = 'a quiet';
    } else if (detectionCount < 25) {
      vibe = 'a fairly active';
    } else if (detectionCount < 60) {
      vibe = 'an active';
    } else {
      vibe = 'a busy';
    }

    // Time of day context
    String timeOfDayContext = '';
    if (_detections.isNotEmpty) {
      final times = _detections
          .map((d) => d['timestamp'] as DateTime?)
          .whereType<DateTime>()
          .toList();
      if (times.isNotEmpty) {
        times.sort();
        final firstHour = times.first.hour;
        final lastHour = times.last.hour;

        if (firstHour < 12 && lastHour < 12) {
          timeOfDayContext = ' Most activity was in the morning.';
        } else if (firstHour >= 12 && firstHour < 17) {
          timeOfDayContext = ' Activity was concentrated in the afternoon.';
        } else if (firstHour >= 17) {
          timeOfDayContext = ' An evening of detections.';
        } else if (firstHour < 12 && lastHour >= 17) {
          timeOfDayContext = ' Activity spanned the whole day.';
        }
      }
    }

    // Top objects
    final classCounts = <String, int>{};
    for (final d in _detections) {
      final c = d['className'] as String? ?? 'unknown';
      classCounts[c] = (classCounts[c] ?? 0) + 1;
    }
    final sortedClasses = classCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sortedClasses.take(3).toList();

    String objectsPhrase;
    if (top.isEmpty) {
      objectsPhrase = '';
    } else if (top.length == 1) {
      objectsPhrase =
          ' ${_capitalize(top[0].key)}s were the most familiar sight.';
    } else if (top.length == 2) {
      objectsPhrase =
          ' ${_capitalize(top[0].key)}s and ${top[1].key}s were the most familiar sights.';
    } else {
      objectsPhrase =
          ' ${_capitalize(top[0].key)}s, ${top[1].key}s and ${top[2].key}s were the most familiar sights.';
    }

    // Time phrase
    String timePhrase;
    if (sessionCount == 0) {
      timePhrase = '';
    } else if (sessionCount == 1) {
      if (totalMinutes < 5) {
        timePhrase = 'They had one short session $dayWord.';
      } else if (totalMinutes < 60) {
        timePhrase =
            'They had one session $dayWord lasting about $totalMinutes minutes.';
      } else {
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        timePhrase = 'They had one session $dayWord lasting about ${h}h ${m}m.';
      }
    } else {
      if (totalMinutes < 60) {
        timePhrase =
            'They had $sessionCount sessions $dayWord, around $totalMinutes minutes total.';
      } else {
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        timePhrase =
            'They had $sessionCount sessions $dayWord, around ${h}h ${m}m total.';
      }
    }

    return '$firstName had $vibe day. $timePhrase$objectsPhrase$timeOfDayContext';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // =====================================
  // BUILD
  // =====================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFF2563EB);

    final isToday = isSameDay(_selectedDay, DateTime.now());
    final dayLabel = isToday
        ? "${widget.visionUserName.split(' ').first}'s day so far"
        : "${widget.visionUserName.split(' ').first}'s day";

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          "${widget.visionUserName}'s Activity",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: accent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCalendar(isDark, accent),
            const SizedBox(height: 24),
            _buildSummaryCard(isDark, accent, dayLabel),
            const SizedBox(height: 24),
            _buildDetectionsList(isDark, accent),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(bool isDark, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onPageChanged: _onPageChanged,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          weekendTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          todayDecoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
          selectedDecoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          markerSize: 5,
        ),
        eventLoader: (day) {
          final stripped = DateTime(day.year, day.month, day.day);
          if (_datesWithData.contains(stripped)) {
            return ['data'];
          }
          return [];
        },
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, Color accent, String dayLabel) {
    if (_loading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
      );
    }

    final summary = _generateSummary();
    Duration totalActive = Duration.zero;
    for (final s in _sessions) {
      final start = s['startedAt'] as DateTime?;
      final end = s['endedAt'] as DateTime?;
      if (start != null && end != null) {
        totalActive += end.difference(start);
      }
    }

    String activeStr;
    if (totalActive.inMinutes < 60) {
      activeStr = '${totalActive.inMinutes}m active';
    } else {
      final h = totalActive.inMinutes ~/ 60;
      final m = totalActive.inMinutes % 60;
      activeStr = '${h}h ${m}m active';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  accent.withValues(alpha: 0.15),
                  accent.withValues(alpha: 0.05),
                ]
              : [
                  accent.withValues(alpha: 0.08),
                  accent.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                dayLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (_detections.isNotEmpty || _sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _statChip(
                  '${_detections.length} detections',
                  isDark,
                  accent,
                ),
                _statChip(
                  '${_sessions.length} sessions',
                  isDark,
                  accent,
                ),
                if (totalActive.inMinutes > 0)
                  _statChip(activeStr, isDark, accent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(String text, bool isDark, Color accent) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDetectionsList(bool isDark, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'ALL DETECTIONS',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_detections.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 36,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No detections recorded for this day',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _detections.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              itemBuilder: (context, i) {
                final d = _detections[i];
                final ts = d['timestamp'] as DateTime?;
                final timeStr = ts != null ? _formatTime(ts) : '';
                final confidence = (d['confidence'] as num?)?.toDouble() ?? 0;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.visibility_outlined,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    _capitalize(d['className'] as String),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '$timeStr  ·  ${(confidence * 100).toStringAsFixed(0)}% confidence',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }
}
