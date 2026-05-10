// ignore_for_file: avoid_print

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_role.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // ===== Profile path =====

  DocumentReference _profileRef(String uid) {
    return _db.collection('users').doc(uid).collection('profile').doc('info');
  }

  DocumentReference _linkingCodeRef(String code) {
    return _db.collection('linkingCodes').doc(code);
  }

  // ===== Linking code generation =====

  String _generateLinkingCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = String.fromCharCodes(
      Iterable.generate(
        4,
        (_) => chars.codeUnitAt(rand.nextInt(chars.length)),
      ),
    );
    return 'DRISHTI-$code';
  }

  /// Save code in top-level linkingCodes collection for fast lookup
  Future<void> _saveLinkingCode({
    required String code,
    required String visionUserId,
    required String name,
    required String email,
  }) async {
    await _linkingCodeRef(code).set({
      'visionUserId': visionUserId,
      'name': name,
      'email': email,
      'createdAt': Timestamp.now(),
    });
  }

  /// Delete old code from linkingCodes when regenerating
  Future<void> _deleteLinkingCode(String code) async {
    try {
      await _linkingCodeRef(code).delete();
    } catch (e) {
      print('_deleteLinkingCode error: $e');
    }
  }

  // ===== Sign up =====

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user?.updateDisplayName(name);

    final uid = cred.user?.uid;
    if (uid != null) {
      final profile = <String, dynamic>{
        'name': name,
        'email': email,
        'role': role.toFirestoreString(),
        'createdAt': Timestamp.now(),
      };

      String? code;
      if (role == UserRole.visionUser) {
        code = _generateLinkingCode();
        profile['linkingCode'] = code;
      }

      await _profileRef(uid).set(profile);

      // Save in top-level linkingCodes collection
      if (code != null) {
        await _saveLinkingCode(
          code: code,
          visionUserId: uid,
          name: name,
          email: email,
        );
      }
    }

    return cred;
  }

  // ===== Sign in =====

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ===== Sign out =====

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ===== Get user profile =====

  Future<Map<String, dynamic>?> getProfile([String? uid]) async {
    final targetUid = uid ?? currentUserId;
    if (targetUid == null) return null;

    try {
      final snap = await _profileRef(targetUid).get();
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    } catch (e) {
      print('getProfile error: $e');
      return null;
    }
  }

  Future<UserRole> getCurrentUserRole() async {
    final profile = await getProfile();
    if (profile == null) return UserRole.unknown;
    return UserRole.fromFirestoreString(profile['role'] as String?);
  }

  // ===== Linking code regeneration =====

  Future<String?> regenerateLinkingCode() async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      // Get current profile to delete old code from linkingCodes
      final profileSnap = await _profileRef(uid).get();
      if (!profileSnap.exists) return null;

      final profileData = profileSnap.data() as Map<String, dynamic>;
      final oldCode = profileData['linkingCode'] as String?;
      final name = profileData['name'] as String? ?? 'Unknown';
      final email = profileData['email'] as String? ?? '';

      // Generate new code
      final newCode = _generateLinkingCode();

      // Delete old code entry
      if (oldCode != null) {
        await _deleteLinkingCode(oldCode);
      }

      // Update profile with new code
      await _profileRef(uid).update({'linkingCode': newCode});

      // Save new code in linkingCodes collection
      await _saveLinkingCode(
        code: newCode,
        visionUserId: uid,
        name: name,
        email: email,
      );

      return newCode;
    } catch (e) {
      print('regenerateLinkingCode error: $e');
      return null;
    }
  }

  // ===== Backfill existing accounts =====

  Future<void> backfillRoleIfMissing(UserRole role) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final ref = _profileRef(uid);
      final snap = await ref.get();
      final user = _auth.currentUser;

      if (!snap.exists) {
        final name = user?.displayName ?? 'User';
        final email = user?.email ?? '';
        final profile = <String, dynamic>{
          'name': name,
          'email': email,
          'role': role.toFirestoreString(),
          'createdAt': Timestamp.now(),
          'backfilled': true,
        };
        String? code;
        if (role == UserRole.visionUser) {
          code = _generateLinkingCode();
          profile['linkingCode'] = code;
        }
        await ref.set(profile);

        if (code != null) {
          await _saveLinkingCode(
            code: code,
            visionUserId: uid,
            name: name,
            email: email,
          );
        }
        print('Profile backfilled for $uid as ${role.displayName}');
      } else {
        final data = snap.data() as Map<String, dynamic>;
        if (data['role'] == null) {
          final updates = <String, dynamic>{'role': role.toFirestoreString()};
          String? code;
          if (role == UserRole.visionUser && data['linkingCode'] == null) {
            code = _generateLinkingCode();
            updates['linkingCode'] = code;
          }
          await ref.update(updates);

          if (code != null) {
            await _saveLinkingCode(
              code: code,
              visionUserId: uid,
              name: data['name'] as String? ?? 'Unknown',
              email: data['email'] as String? ?? '',
            );
          }
          print('Role backfilled for $uid');
        } else if (role == UserRole.visionUser) {
          // Existing vision user — make sure their linkingCode is in linkingCodes collection
          final existingCode = data['linkingCode'] as String?;
          if (existingCode != null) {
            final codeSnap = await _linkingCodeRef(existingCode).get();
            if (!codeSnap.exists) {
              print(
                  'Migrating existing code $existingCode to linkingCodes collection');
              await _saveLinkingCode(
                code: existingCode,
                visionUserId: uid,
                name: data['name'] as String? ?? 'Unknown',
                email: data['email'] as String? ?? '',
              );
            }
          }
        }
      }
    } catch (e) {
      print('backfillRoleIfMissing error: $e');
    }
  }
}
