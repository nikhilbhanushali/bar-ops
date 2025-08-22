import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/gatepass.dart';

class GatepassRepository {
  GatepassRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // ---- list / filter ----
  Stream<List<Gatepass>> streamGatepasses({
    String? typeFilter,        // 'inward'|'outward'|null
    bool returnableOnly = false,
    bool overdueOnly = false,  // client-side filter by expectedDate
  }) {
    Query<Map<String, dynamic>> q = _db.collection('gatepasses');
    if (typeFilter != null) q = q.where('type', isEqualTo: typeFilter);
    if (returnableOnly) q = q.where('returnable', isEqualTo: true);
    q = q.orderBy('createdAt', descending: true);

    return q.snapshots().map((snap) {
      final list = snap.docs.map((d) => Gatepass.fromDoc(d.id, d.data())).toList();
      if (!overdueOnly) return list;
      final now = DateTime.now().toUtc();
      return list.where((g) {
        if (!g.returnable) return false;
        if (g.expectedDateIso == null || g.expectedDateIso!.isEmpty) return false;
        final due = DateTime.tryParse(g.expectedDateIso!)?.toUtc();
        final open = !(g.status == 'returned' || g.status == 'completed' || g.status == 'cancelled');
        return due != null && open && due.isBefore(now);
      }).toList();
    });
  }

  // ---- create ----
  Future<String> createGatepass({
    required GatepassType type,
    required bool returnable,
    DateTime? expectedDate,           // required when returnable
    String? vendorId,                 // optional selected vendor
    String? vendorName,               // optional selected vendor name
    String? customVendorName,         // optional free-text vendor name
    String? projectId,
    List<Map<String, dynamic>> items = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('not-signed-in');

    if (returnable && expectedDate == null) {
      throw Exception('expected-date-required-for-returnable');
    }

    final doc = _db.collection('gatepasses').doc();
    final code = 'GP-${doc.id.substring(0, 6).toUpperCase()}';
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'code': code,
      'type': type == GatepassType.outward ? 'outward' : 'inward',
      'returnable': returnable,
      'status': 'pending',
      'expectedDate': expectedDate?.toUtc().toIso8601String(),
      'billUploaded': false,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'customVendorName': (customVendorName?.trim().isEmpty ?? true) ? null : customVendorName!.trim(),
      'projectId': projectId,
      'items': items,
      'createdBy': uid,
      'createdAt': now,
      'updatedBy': uid,
      'updatedAt': now,
    };

    await doc.set(data);
    return doc.id;
  }

  // ---- status transitions ----
  Future<void> updateStatus(String id, String nextStatus, {Map<String, dynamic>? extra}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('not-signed-in');

    final Map<String, dynamic> payload = {
      'status': nextStatus,
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };

    await _db.collection('gatepasses').doc(id).set(payload, SetOptions(merge: true));
  }

  Future<void> setBillUploaded(String id, bool uploaded) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('not-signed-in');
    await _db.collection('gatepasses').doc(id).set({
      'billUploaded': uploaded,
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markDispatched(String id) async {
    await updateStatus(id, 'dispatched', extra: {
      'dispatchedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReturned(String id) async {
    await updateStatus(id, 'returned', extra: {
      'returnedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markCompleted(String id) async {
    await updateStatus(id, 'completed', extra: {
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markCancelled(String id) async {
    await updateStatus(id, 'cancelled', extra: {
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}
