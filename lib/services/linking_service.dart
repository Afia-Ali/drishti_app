// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LinkingService {
  static final LinkingService _instance = LinkingService._internal();
  factory LinkingService() => _instance;
  LinkingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ===== Helpers =====

  DocumentReference _profileRef(String uid) {
    return _db.collection('users').doc(uid).collection('profile').doc('info');
  }

  DocumentReference _linkingCodeRef(String code) {
    return _db.collection('linkingCodes').doc(code);
  }

  CollectionReference _linkedCaregiversRef(String visionUserId) {
    return _db
        .collection('users')
        .doc(visionUserId)
        .collection('linkedCaregivers');
  }

  CollectionReference _linkedVisionUsersRef(String caregiverId) {
    return _db
        .collection('users')
        .doc(caregiverId)
        .collection('linkedVisionUsers');
  }

  CollectionReference get _linkRequestsRef => _db.collection('linkRequests');

  // =====================================
  // VISION USER FUNCTIONS
  // =====================================

  Future<String?> getMyLinkingCode() async {
    final uid = _userId;
    if (uid == null) return null;

    try {
      final snap = await _profileRef(uid).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      return data['linkingCode'] as String?;
    } catch (e) {
      print('getMyLinkingCode error: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> watchPendingRequests() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _linkRequestsRef
        .where('toVisionUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'fromCaregiverId': data['fromCaregiverId'] ?? '',
          'fromCaregiverName': data['fromCaregiverName'] ?? 'Unknown',
          'fromCaregiverEmail': data['fromCaregiverEmail'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  Future<bool> acceptRequest(String requestId) async {
    final visionUserId = _userId;
    if (visionUserId == null) return false;

    try {
      final reqSnap = await _linkRequestsRef.doc(requestId).get();
      if (!reqSnap.exists) return false;

      final reqData = reqSnap.data() as Map<String, dynamic>;
      final caregiverId = reqData['fromCaregiverId'] as String?;
      final caregiverName =
          reqData['fromCaregiverName'] as String? ?? 'Unknown';
      final caregiverEmail = reqData['fromCaregiverEmail'] as String? ?? '';

      if (caregiverId == null) return false;

      final visionProfileSnap = await _profileRef(visionUserId).get();
      final visionData = visionProfileSnap.exists
          ? visionProfileSnap.data() as Map<String, dynamic>
          : <String, dynamic>{};
      final visionName = visionData['name'] as String? ?? 'Unknown';
      final visionEmail = visionData['email'] as String? ?? '';

      final batch = _db.batch();

      batch.set(_linkedCaregiversRef(visionUserId).doc(caregiverId), {
        'name': caregiverName,
        'email': caregiverEmail,
        'addedAt': Timestamp.now(),
      });

      batch.set(_linkedVisionUsersRef(caregiverId).doc(visionUserId), {
        'name': visionName,
        'email': visionEmail,
        'addedAt': Timestamp.now(),
      });

      batch.update(_linkRequestsRef.doc(requestId), {
        'status': 'accepted',
        'respondedAt': Timestamp.now(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('acceptRequest error: $e');
      return false;
    }
  }

  Future<bool> rejectRequest(String requestId) async {
    try {
      await _linkRequestsRef.doc(requestId).update({
        'status': 'rejected',
        'respondedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('rejectRequest error: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchLinkedCaregivers() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _linkedCaregiversRef(uid).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'addedAt': (data['addedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  Future<bool> removeCaregiver(String caregiverId) async {
    final visionUserId = _userId;
    if (visionUserId == null) return false;

    try {
      final batch = _db.batch();
      batch.delete(_linkedCaregiversRef(visionUserId).doc(caregiverId));
      batch.delete(_linkedVisionUsersRef(caregiverId).doc(visionUserId));
      await batch.commit();
      return true;
    } catch (e) {
      print('removeCaregiver error: $e');
      return false;
    }
  }

  // =====================================
  // CAREGIVER FUNCTIONS
  // =====================================

  /// Find a vision user by their linking code
  /// NEW: Direct lookup from linkingCodes collection (no index needed)
  Future<Map<String, dynamic>?> findVisionUserByCode(String code) async {
    print('🔍 findVisionUserByCode called with: "$code"');

    try {
      final cleanCode = code.trim().toUpperCase();
      print('🔍 Looking up code directly: "$cleanCode"');

      final snap = await _linkingCodeRef(cleanCode).get();

      if (!snap.exists) {
        print('❌ No linking code found: $cleanCode');
        return null;
      }

      final data = snap.data() as Map<String, dynamic>;
      print('✅ Found code, data: $data');

      final uid = data['visionUserId'] as String?;
      if (uid == null) {
        print('❌ No visionUserId in code document');
        return null;
      }

      print('✅ Returning vision user: uid=$uid, name=${data['name']}');
      return {
        'uid': uid,
        'name': data['name'] ?? 'Unknown',
        'email': data['email'] ?? '',
      };
    } catch (e, stack) {
      print('🔥 findVisionUserByCode error: $e');
      print('🔥 Stack: $stack');
      return null;
    }
  }

  Future<String?> sendLinkRequest({
    required String visionUserId,
  }) async {
    print('📤 sendLinkRequest called for visionUserId: $visionUserId');

    final caregiverId = _userId;
    if (caregiverId == null) {
      print('❌ No caregiverId (not logged in)');
      return null;
    }

    print('📤 caregiverId: $caregiverId');

    try {
      final caregiverProfileSnap = await _profileRef(caregiverId).get();
      print('📤 caregiver profile exists: ${caregiverProfileSnap.exists}');

      final caregiverData = caregiverProfileSnap.exists
          ? caregiverProfileSnap.data() as Map<String, dynamic>
          : <String, dynamic>{};
      final caregiverName = caregiverData['name'] as String? ?? 'Unknown';
      final caregiverEmail = caregiverData['email'] as String? ?? '';

      print('📤 caregiver name: $caregiverName, email: $caregiverEmail');

      final existingLink =
          await _linkedVisionUsersRef(caregiverId).doc(visionUserId).get();
      if (existingLink.exists) {
        print('⚠️ Already linked');
        return 'already_linked';
      }

      print('📤 Checking for existing pending requests...');
      final existingReq = await _linkRequestsRef
          .where('fromCaregiverId', isEqualTo: caregiverId)
          .where('toVisionUserId', isEqualTo: visionUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existingReq.docs.isNotEmpty) {
        print('⚠️ Already pending');
        return 'already_pending';
      }

      print('📤 Creating new request document...');
      final reqDoc = await _linkRequestsRef.add({
        'fromCaregiverId': caregiverId,
        'fromCaregiverName': caregiverName,
        'fromCaregiverEmail': caregiverEmail,
        'toVisionUserId': visionUserId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      print('✅ Request created with id: ${reqDoc.id}');
      return reqDoc.id;
    } catch (e, stack) {
      print('🔥 sendLinkRequest error: $e');
      print('🔥 Stack: $stack');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> watchLinkedVisionUsers() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _linkedVisionUsersRef(uid).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'addedAt': (data['addedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  Future<bool> unlinkVisionUser(String visionUserId) async {
    final caregiverId = _userId;
    if (caregiverId == null) return false;

    try {
      final batch = _db.batch();
      batch.delete(_linkedVisionUsersRef(caregiverId).doc(visionUserId));
      batch.delete(_linkedCaregiversRef(visionUserId).doc(caregiverId));
      await batch.commit();
      return true;
    } catch (e) {
      print('unlinkVisionUser error: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchSentRequests() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _linkRequestsRef
        .where('fromCaregiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'toVisionUserId': data['toVisionUserId'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }
}
