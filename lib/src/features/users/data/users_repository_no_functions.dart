import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersRepositoryNoFx {
  UsersRepositoryNoFx(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Called after signup succeeds; writes profile gated by rules
  Future<void> createProfileAfterSignup({
    required String displayName,
    required String emailLc,
    required String role,
  }) async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'email': emailLc,
      'phone': '',
      'role': role,
      'status': 'active',
      'createdAt': now,
      'createdBy': uid,
      'updatedAt': now,
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
