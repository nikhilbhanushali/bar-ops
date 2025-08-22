import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/vendor.dart';

class VendorRepository {
  VendorRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // LIST stream (ordered newest first)
  Stream<List<Vendor>> streamVendors() {
    return _db
        .collection('vendors')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Vendor.fromDoc(d.id, d.data())).toList());
  }

  // CREATE (Store or Admin)
  Future<String> createVendor({
    required String name,
    required String gstDetail,
    String address = '',
    String contactPerson = '',
    String phone = '',
    String email = '',
    String notes = '',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.error('not-signed-in');
    final ref = _db.collection('vendors').doc();
    await ref.set({
      'name': name.trim(),
      'gstDetail': gstDetail.trim(),
      'address': address.trim(),
      'contactPerson': contactPerson.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'notes': notes.trim(),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // UPDATE (Admin only – rules enforce)
  Future<void> updateVendor({
    required String vendorId,
    required String name,
    required String gstDetail,
    String address = '',
    String contactPerson = '',
    String phone = '',
    String email = '',
    String notes = '',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.error('not-signed-in');
    await _db.collection('vendors').doc(vendorId).set({
      'name': name.trim(),
      'gstDetail': gstDetail.trim(),
      'address': address.trim(),
      'contactPerson': contactPerson.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'notes': notes.trim(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // DELETE (Admin only – rules enforce)
  Future<void> deleteVendor(String vendorId) async {
    await _db.collection('vendors').doc(vendorId).delete();
  }
}
