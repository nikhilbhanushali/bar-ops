import 'package:cloud_firestore/cloud_firestore.dart';

class InvitesRepository {
  InvitesRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> createInvite({
    required String adminUid,
    required String email,
    required String role,
    required String code,
    DateTime? expiresAt,
  }) async {
    final emailLc = email.trim().toLowerCase();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.collection('invites').doc(emailLc).set({
      'email': emailLc,
      'role': role,
      'code': code,
      'status': 'pending',
      'createdBy': adminUid,
      'createdAt': now,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'usedBy': null,
      'usedAt': null,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getInvite(String emailLc) async {
    final doc = await _db.collection('invites').doc(emailLc).get();
    return doc.data();
  }

  Future<void> markUsed({required String emailLc, required String uid}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.collection('invites').doc(emailLc).set({
      'status': 'used',
      'usedBy': uid,
      'usedAt': now,
    }, SetOptions(merge: true));
  }
}
