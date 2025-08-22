import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/app_user.dart';

class UsersRepository {
  UsersRepository(this._db, this._functions, this._auth);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Stream<List<AppUser>> streamUsers() {
    return _db.collection('users').orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList(),
    );
  }

  Future<String> createUser({
    required String displayName,
    required String email,
    required String role,
  }) async {
    final callable = _functions.httpsCallable('createUserWithRole');
    final res = await callable.call({'displayName': displayName, 'email': email, 'role': role});
    final uid = (res.data as Map)['uid'] as String;

    // Send password reset email so the user sets their password
    await _auth.sendPasswordResetEmail(email: email);
    return uid;
  }

  Future<void> setUserStatus({required String uid, required String status}) async {
    final callable = _functions.httpsCallable('setUserStatus');
    await callable.call({'uid': uid, 'status': status});
  }

  Future<void> setUserRole({required String uid, required String role}) async {
    final callable = _functions.httpsCallable('setUserRole');
    await callable.call({'uid': uid, 'role': role});
  }
}
