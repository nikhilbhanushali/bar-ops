// AuthRepository: handles FirebaseAuth + Firestore for BarOps
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> signOut() async {
    await _auth.signOut();
    return null;
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> signupAdmin({
    required String displayName,
    required String email,
    required String password,
    required String setupCode,
    required String expectedSetupCode,
  }) async {
    if (setupCode != expectedSetupCode) {
      return 'Invalid setup code.';
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(displayName);
      final now = DateTime.now().toUtc().toIso8601String();
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'displayName': displayName,
        'email': email,
        'phone': '',
        'role': 'admin',
        'status': 'active',
        'createdAt': now,
        'createdBy': cred.user!.uid,
        'updatedAt': now,
        'updatedBy': cred.user!.uid,
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> createUserWithProfile({
    required String displayName,
    required String email,
    required String phone,
    required String role,
    required String status,
    required String createdBy,
    required String password,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = userCred.user?.uid;
      if (uid == null) throw Exception('Failed to create user');
      // Set Firestore profile
      final now = DateTime.now().toIso8601String();
      await _firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'createdAt': now,
        'createdBy': createdBy,
        'updatedAt': now,
        'updatedBy': createdBy,
      });
      // Optionally set custom claims (requires admin privileges, usually via Cloud Functions)
      // This is a placeholder; actual claim setting should be done server-side
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      return e.toString();
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'network-request-failed':
        return 'Network error. Please try again.';
      case 'user-disabled':
        return 'This user account is disabled.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
