// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JournalService {
  static final JournalService _instance = JournalService._internal();
  factory JournalService() => _instance;
  JournalService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, DateTime> _lastSavedAt = {};
  static const Duration _dedupWindow = Duration(seconds: 30);

  String? _currentSessionId;
  DateTime? _sessionStartedAt;
  int _sessionDetectionCount = 0;
  final Set<String> _sessionUniqueClasses = {};

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference? get _detectionsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('detections');
  }

  CollectionReference? get _sessionsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('sessions');
  }

  DocumentReference? get _statsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('stats').doc('summary');
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> startSession() async {
    final ref = _sessionsRef;
    if (ref == null) {
      print('JournalService: user not logged in, cannot start session');
      return;
    }

    try {
      _sessionStartedAt = DateTime.now();
      _sessionDetectionCount = 0;
      _sessionUniqueClasses.clear();
      _lastSavedAt.clear();

      final docRef = await ref.add({
        'startedAt': Timestamp.fromDate(_sessionStartedAt!),
        'date': _formatDate(_sessionStartedAt!),
        'totalDetections': 0,
        'uniqueClasses': [],
      });

      _currentSessionId = docRef.id;
      print('Session started: $_currentSessionId');
    } catch (e) {
      print('startSession error: $e');
    }
  }

  Future<void> endSession() async {
    final ref = _sessionsRef;
    if (ref == null || _currentSessionId == null) return;

    try {
      await ref.doc(_currentSessionId).update({
        'endedAt': Timestamp.fromDate(DateTime.now()),
        'totalDetections': _sessionDetectionCount,
        'uniqueClasses': _sessionUniqueClasses.toList(),
      });

      await _incrementSessionStats();

      print('Session ended: $_currentSessionId');
      _currentSessionId = null;
      _sessionStartedAt = null;
      _sessionDetectionCount = 0;
      _sessionUniqueClasses.clear();
    } catch (e) {
      print('endSession error: $e');
    }
  }

  Future<bool> saveDetection({
    required String className,
    required double confidence,
  }) async {
    final ref = _detectionsRef;
    if (ref == null) return false;

    final now = DateTime.now();
    final lastSaved = _lastSavedAt[className];
    if (lastSaved != null && now.difference(lastSaved) < _dedupWindow) {
      return false;
    }

    try {
      _lastSavedAt[className] = now;
      _sessionDetectionCount++;
      _sessionUniqueClasses.add(className);

      await ref.add({
        'className': className,
        'confidence': confidence,
        'timestamp': Timestamp.fromDate(now),
        'date': _formatDate(now),
        'sessionId': _currentSessionId ?? 'unknown',
      });

      await _incrementDetectionStats(className);

      return true;
    } catch (e) {
      print('saveDetection error: $e');
      return false;
    }
  }

  Future<void> _incrementDetectionStats(String className) async {
    final ref = _statsRef;
    if (ref == null) return;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final total = (data['totalDetections'] ?? 0) as int;
          final topClasses =
              Map<String, dynamic>.from(data['topClasses'] ?? {});
          topClasses[className] = ((topClasses[className] ?? 0) as int) + 1;

          tx.update(ref, {
            'totalDetections': total + 1,
            'topClasses': topClasses,
            'lastSeenAt': Timestamp.now(),
          });
        } else {
          tx.set(ref, {
            'totalDetections': 1,
            'totalSessions': 0,
            'topClasses': {className: 1},
            'firstSeenAt': Timestamp.now(),
            'lastSeenAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      print('_incrementDetectionStats error: $e');
    }
  }

  Future<void> _incrementSessionStats() async {
    final ref = _statsRef;
    if (ref == null) return;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final total = (data['totalSessions'] ?? 0) as int;
          tx.update(ref, {'totalSessions': total + 1});
        } else {
          tx.set(ref, {
            'totalDetections': 0,
            'totalSessions': 1,
            'topClasses': {},
            'firstSeenAt': Timestamp.now(),
            'lastSeenAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      print('_incrementSessionStats error: $e');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    final ref = _statsRef;
    if (ref == null) {
      return {
        'totalDetections': 0,
        'totalSessions': 0,
        'topClasses': <String, int>{},
      };
    }

    try {
      final snap = await ref.get();
      if (!snap.exists) {
        return {
          'totalDetections': 0,
          'totalSessions': 0,
          'topClasses': <String, int>{},
        };
      }
      final data = snap.data() as Map<String, dynamic>;
      return {
        'totalDetections': (data['totalDetections'] ?? 0) as int,
        'totalSessions': (data['totalSessions'] ?? 0) as int,
        'topClasses': Map<String, int>.from(
          (data['topClasses'] ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ),
        ),
      };
    } catch (e) {
      print('getStats error: $e');
      return {
        'totalDetections': 0,
        'totalSessions': 0,
        'topClasses': <String, int>{},
      };
    }
  }

  // =====================================
  // OWN USER QUERIES (no composite index needed)
  // =====================================

  Future<List<Map<String, dynamic>>> getDetectionsForDate(DateTime date) async {
    final ref = _detectionsRef;
    if (ref == null) return [];

    try {
      final dateStr = _formatDate(date);
      final snap = await ref.where('date', isEqualTo: dateStr).get();

      final results = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'className': data['className'] ?? 'unknown',
          'confidence': (data['confidence'] ?? 0.0) as num,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'sessionId': data['sessionId'] ?? '',
        };
      }).toList();

      results.sort((a, b) {
        final ta = a['timestamp'] as DateTime?;
        final tb = b['timestamp'] as DateTime?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      return results;
    } catch (e) {
      print('getDetectionsForDate error: $e');
      return [];
    }
  }

  Future<Set<DateTime>> getDatesWithDetections({
    required int year,
    required int month,
  }) async {
    final ref = _detectionsRef;
    if (ref == null) return {};

    try {
      final snap = await ref.get();

      final dates = <DateTime>{};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts != null && ts.year == year && ts.month == month) {
          dates.add(DateTime(ts.year, ts.month, ts.day));
        }
      }
      return dates;
    } catch (e) {
      print('getDatesWithDetections error: $e');
      return {};
    }
  }

  // =====================================
  // CAREGIVER READ-ONLY QUERIES
  // (read another user's journal data)
  // =====================================

  /// Get detections for a specific date for ANOTHER user (caregiver use)
  Future<List<Map<String, dynamic>>> getDetectionsForDateOfUser({
    required String visionUserId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final snap = await _db
          .collection('users')
          .doc(visionUserId)
          .collection('detections')
          .where('date', isEqualTo: dateStr)
          .get();

      final results = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'className': data['className'] ?? 'unknown',
          'confidence': (data['confidence'] ?? 0.0) as num,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'sessionId': data['sessionId'] ?? '',
        };
      }).toList();

      results.sort((a, b) {
        final ta = a['timestamp'] as DateTime?;
        final tb = b['timestamp'] as DateTime?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

      return results;
    } catch (e) {
      print('getDetectionsForDateOfUser error: $e');
      return [];
    }
  }

  /// Get sessions for a specific date for ANOTHER user (caregiver use)
  Future<List<Map<String, dynamic>>> getSessionsForDateOfUser({
    required String visionUserId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final snap = await _db
          .collection('users')
          .doc(visionUserId)
          .collection('sessions')
          .where('date', isEqualTo: dateStr)
          .get();

      final results = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'startedAt': (data['startedAt'] as Timestamp?)?.toDate(),
          'endedAt': (data['endedAt'] as Timestamp?)?.toDate(),
          'totalDetections': (data['totalDetections'] ?? 0) as int,
          'uniqueClasses':
              List<String>.from(data['uniqueClasses'] ?? <String>[]),
        };
      }).toList();

      results.sort((a, b) {
        final ta = a['startedAt'] as DateTime?;
        final tb = b['startedAt'] as DateTime?;
        if (ta == null || tb == null) return 0;
        return ta.compareTo(tb); // ascending (oldest first)
      });

      return results;
    } catch (e) {
      print('getSessionsForDateOfUser error: $e');
      return [];
    }
  }

  /// Get dates with detections for ANOTHER user (caregiver calendar markers)
  Future<Set<DateTime>> getDatesWithDetectionsForUser({
    required String visionUserId,
    required int year,
    required int month,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(visionUserId)
          .collection('detections')
          .get();

      final dates = <DateTime>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts != null && ts.year == year && ts.month == month) {
          dates.add(DateTime(ts.year, ts.month, ts.day));
        }
      }
      return dates;
    } catch (e) {
      print('getDatesWithDetectionsForUser error: $e');
      return {};
    }
  }
}
