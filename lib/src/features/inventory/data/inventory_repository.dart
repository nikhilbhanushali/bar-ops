import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../domain/inventory_submission.dart';
import '../domain/inventory_item.dart';

class InventoryRepository {
  InventoryRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // ---------- Helpers ----------
  static String _normalize(String s) => s.trim().toLowerCase();

  static String _idSafe(String? s) {
    if (s == null) return '';
    return s
        .trim()
        .replaceAll('/', '_')
        .replaceAll('#', '_')
        .replaceAll('?', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('*', '_')
        .replaceAll('|', '_');
  }

  static String _canonicalTokensKey(String input) {
    final lower = input.toLowerCase();
    final re = RegExp(r'[a-z0-9]+');
    final tokens = re.allMatches(lower).map((m) => m.group(0)!).toList();
    tokens.sort();
    return tokens.join('_');
  }

  static String _legacyUniKey({
    required String category,
    String? vendorId,
    required String partNumber,
  }) {
    final cat = _normalize(category);
    final ven = _idSafe(vendorId);
    final part = _idSafe(partNumber);
    return '$cat|$ven|$part';
  }

  static String _v2UniKey({
    required String category,
    String? vendorId,
    required String partNumber,
  }) {
    final cat = _normalize(category);
    final ven = _idSafe(vendorId);
    final canonPart = _canonicalTokensKey(partNumber);
    return 'v2|$cat|$ven|$canonPart';
  }

  // NEW: v3 considers BOTH title + partNumber for canon
  static String _v3UniKey({
    required String category,
    String? vendorId,
    required String title,
    required String partNumber,
  }) {
    final cat = _normalize(category);
    final ven = _idSafe(vendorId);
    final canon = _canonicalTokensKey('$title $partNumber');
    return 'v3|$cat|$ven|$canon';
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  static String _humanizeError(Object e) {
    if (e is FirebaseException) {
      final msg = (e.message ?? '').trim();
      return '${e.code}${msg.isEmpty ? '' : ': $msg'}';
    }
    if (e is PlatformException) {
      final msg = (e.message ?? '').trim();
      return '${e.code}${msg.isEmpty ? '' : ': $msg'}';
    }
    if (e is AsyncError) {
      return _humanizeError(e.error);
    }
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', ''));
    return null;
  }

  // ---------- STORE: submit a draft for approval ----------
  Future<void> submitDraft({
    required String title,
    required String category, // tools|asset|raw
    String? vendorId,
    required String partNumber,
    required String uom,
    String specs = '',
    double? initPrice,
    String notes = '',
    double? minStock,       // NEW
    double? openingStock,   // NEW
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.error('not-signed-in');
    try {
      await _db.collection('inventory_submissions').add({
        'title': title.trim(),
        'category': category,
        'vendorId': vendorId,
        'partNumber': partNumber.trim(),
        'uom': uom.trim(),
        'specs': specs.trim(),
        'initPrice': initPrice,
        'minStock': (minStock ?? 0.0).toDouble(),
        'openingStock': (openingStock ?? 0.0).toDouble(),
        'notes': notes.trim(),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'decidedBy': null,
        'decidedAt': null,
      });
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }

  // ---------- ADMIN: pending submissions stream ----------
  Stream<List<InventorySubmission>> streamPendingSubmissions() {
    return _db
        .collection('inventory_submissions')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => InventorySubmission.fromDoc(d.id, d.data()))
        .toList());
  }

  // ---------- ADMIN: approve submission (no transaction) ----------
  Future<void> approveSubmission(InventorySubmission sub) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return Future.error('not-signed-in');

    try {
      final legacyKey = _legacyUniKey(
        category: sub.category,
        vendorId: sub.vendorId,
        partNumber: sub.partNumber,
      );
      final v2Key = _v2UniKey(
        category: sub.category,
        vendorId: sub.vendorId,
        partNumber: sub.partNumber,
      );
      final v3Key = _v3UniKey(
        category: sub.category,
        vendorId: sub.vendorId,
        title: sub.title,
        partNumber: sub.partNumber,
      );

      final legacyRef = _db.collection('inventory_index').doc(legacyKey);
      final v2Ref = _db.collection('inventory_index').doc(v2Key);
      final v3Ref = _db.collection('inventory_index').doc(v3Key);

      // --- Duplicate check with backward compatibility ---
      final checks = await Future.wait([v3Ref.get(), v2Ref.get()]);
      final v3Exists = checks[0].exists;
      final v2Snap = checks[1];

      if (v3Exists) {
        return Future.error('duplicate-item: same title+partNumber under category/vendor already exists');
      }

      if (v2Snap.exists) {
        // v2 collision on partNumber: verify if the existing item has same canon(title+part).
        final itemId = v2Snap.data()?['itemId']?.toString();
        if (itemId != null && itemId.isNotEmpty) {
          final inv = await _db.collection('inventory').doc(itemId).get();
          if (inv.exists) {
            final m = inv.data() ?? {};
            final oldCanon = _canonicalTokensKey('${m['title'] ?? ''} ${m['partNumber'] ?? ''}');
            final newCanon = _canonicalTokensKey('${sub.title} ${sub.partNumber}');
            if (oldCanon == newCanon) {
              return Future.error('duplicate-item: same title+partNumber under category/vendor already exists');
            }
          }
        }
      }

      final itemRef = _db.collection('inventory').doc();
      final code = 'INV-${itemRef.id.substring(0, 6).toUpperCase()}';
      final nowIso = _nowIso();

      final batch = _db.batch();

      batch.set(itemRef, {
        'code': code,
        'title': sub.title.trim(),
        'category': sub.category,
        'vendorId': sub.vendorId,
        'partNumber': sub.partNumber.trim(),
        'uom': sub.uom.trim(),
        'specs': sub.specs.trim(),
        'currentPrice': sub.initPrice ?? 0.0,
        'minStock': sub.minStock,
        'openingStock': sub.openingStock,
        'currentStock': (sub.openingStock ?? 0.0),
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'uniKey': v2Key,     // keep v2 for compatibility
        'uniKeyV3': v3Key,   // NEW
        'legacyUniKey': legacyKey,
      });

      // index docs
      batch.set(legacyRef, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'legacy',
      });
      batch.set(v2Ref, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'v2',
      });
      batch.set(v3Ref, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'v3',
      });

      if (sub.initPrice != null) {
        final priceLogRef = itemRef.collection('priceLogs').doc();
        batch.set(priceLogRef, {
          'vendorId': sub.vendorId,
          'price': sub.initPrice,
          'currency': 'INR',
          'effectiveDate': nowIso,
          'addedBy': adminUid,
          'addedAt': nowIso,
        });
      }

      final subRef = _db.collection('inventory_submissions').doc(sub.id);
      batch.update(subRef, {
        'status': 'approved',
        'decidedBy': adminUid,
        'decidedAt': nowIso,
      });

      await batch.commit();
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }

  // ---------- ADMIN: reject submission ----------
  Future<void> rejectSubmission(InventorySubmission sub, {String? reason}) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return Future.error('not-signed-in');
    final nowIso = _nowIso();
    try {
      final subRef = _db.collection('inventory_submissions').doc(sub.id);
      final newNotes = (sub.notes == null || sub.notes!.isEmpty)
          ? (reason == null || reason.isEmpty ? null : '[REJECTED] $reason')
          : (reason == null || reason.isEmpty ? sub.notes : '${sub.notes}\n[REJECTED] $reason');

      await subRef.update({
        'status': 'rejected',
        'decidedBy': adminUid,
        'decidedAt': nowIso,
        if (newNotes != null) 'notes': newNotes,
      });
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }

  // ---------- ADMIN: create item directly (no transaction) ----------
  Future<String> adminCreateItem({
    required String title,
    required String category, // tools|asset|raw
    String? vendorId,
    required String partNumber,
    required String uom,
    String specs = '',
    double? initPrice,
    double? minStock,
    double? openingStock,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return Future.error('not-signed-in');

    try {
      final legacyKey = _legacyUniKey(
        category: category,
        vendorId: vendorId,
        partNumber: partNumber,
      );
      final v2Key = _v2UniKey(
        category: category,
        vendorId: vendorId,
        partNumber: partNumber,
      );
      final v3Key = _v3UniKey(
        category: category,
        vendorId: vendorId,
        title: title,
        partNumber: partNumber,
      );

      final legacyRef = _db.collection('inventory_index').doc(legacyKey);
      final v2Ref = _db.collection('inventory_index').doc(v2Key);
      final v3Ref = _db.collection('inventory_index').doc(v3Key);

      // --- Duplicate check with backward compatibility ---
      final checks = await Future.wait([v3Ref.get(), v2Ref.get()]);
      final v3Exists = checks[0].exists;
      final v2Snap = checks[1];

      if (v3Exists) {
        return Future.error('duplicate-item: same title+partNumber under category/vendor already exists');
      }

      if (v2Snap.exists) {
        final itemId = v2Snap.data()?['itemId']?.toString();
        if (itemId != null && itemId.isNotEmpty) {
          final inv = await _db.collection('inventory').doc(itemId).get();
          if (inv.exists) {
            final m = inv.data() ?? {};
            final oldCanon = _canonicalTokensKey('${m['title'] ?? ''} ${m['partNumber'] ?? ''}');
            final newCanon = _canonicalTokensKey('$title $partNumber');
            if (oldCanon == newCanon) {
              return Future.error('duplicate-item: same title+partNumber under category/vendor already exists');
            }
          }
        }
      }

      final itemRef = _db.collection('inventory').doc();
      final code = 'INV-${itemRef.id.substring(0, 6).toUpperCase()}';
      final nowIso = _nowIso();

      final batch = _db.batch();

      batch.set(itemRef, {
        'code': code,
        'title': title.trim(),
        'category': category,
        'vendorId': vendorId,
        'partNumber': partNumber.trim(),
        'uom': uom.trim(),
        'specs': specs.trim(),
        'currentPrice': (initPrice ?? 0.0).toDouble(),
        'minStock': (minStock ?? 0.0).toDouble(),
        'openingStock': (openingStock ?? 0.0).toDouble(),
        'currentStock': (openingStock ?? 0.0).toDouble(), // init = opening
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'uniKey': v2Key,     // keep v2 for compatibility
        'uniKeyV3': v3Key,   // NEW
        'legacyUniKey': legacyKey,
      });

      // index docs
      batch.set(legacyRef, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'legacy',
      });
      batch.set(v2Ref, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'v2',
      });
      batch.set(v3Ref, {
        'itemId': itemRef.id,
        'createdAt': nowIso,
        'createdBy': adminUid,
        'keyType': 'v3',
      });

      if (initPrice != null) {
        final priceLogRef = itemRef.collection('priceLogs').doc();
        batch.set(priceLogRef, {
          'vendorId': vendorId,
          'price': initPrice,
          'currency': 'INR',
          'effectiveDate': nowIso,
          'addedBy': adminUid,
          'addedAt': nowIso,
        });
      }

      await batch.commit();
      return itemRef.id;
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }

  // ---------- BULK IMPORT (admin) ----------
  Future<List<String>> adminBulkCreate(List<Map<String, dynamic>> rows) async {
    final createdIds = <String>[];
    for (final row in rows) {
      try {
        final id = await adminCreateItem(
          title: (row['title'] ?? '') as String,
          category: (row['category'] ?? '') as String,
          vendorId: (row['vendorId'] as String?)?.trim().isEmpty == true ? null : row['vendorId'] as String?,
          partNumber: (row['partNumber'] ?? '') as String,
          uom: (row['uom'] ?? 'pcs') as String,
          specs: (row['specs'] ?? '') as String,
          initPrice: _toDouble(row['initPrice']),
          minStock: _toDouble(row['minStock']),
          openingStock: _toDouble(row['openingStock']),
        );
        createdIds.add(id);
      } catch (_) {
        // Skip duplicates/invalid rows silently for now.
      }
    }
    return createdIds;
  }

  // ---------- INVENTORY list stream ----------
  Stream<List<InventoryItem>> streamInventoryItems() {
    return _db
        .collection('inventory')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
        .map((d) => InventoryItem.fromDoc(d.id, d.data()))
        .toList());
  }

  // ---------- ADMIN: update safe fields ----------
  Future<void> updateItem({
    required String itemId,
    required String title,
    required String uom,
    required String specs,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return Future.error('not-signed-in');
    try {
      await _db.collection('inventory').doc(itemId).set({
        'title': title.trim(),
        'uom': uom.trim(),
        'specs': specs.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      }, SetOptions(merge: true));
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }

  // ---------- ADMIN: delete item + all index docs ----------
  Future<void> deleteItem({required InventoryItem item}) async {
    try {
      final itemRef = _db.collection('inventory').doc(item.id);

      final legacyKey = _legacyUniKey(
        category: item.category,
        vendorId: item.vendorId,
        partNumber: item.partNumber,
      );
      final v2Key = _v2UniKey(
        category: item.category,
        vendorId: item.vendorId,
        partNumber: item.partNumber,
      );
      final v3Key = _v3UniKey(
        category: item.category,
        vendorId: item.vendorId,
        title: item.title,
        partNumber: item.partNumber,
      );

      final legacyIndexRef = _db.collection('inventory_index').doc(legacyKey);
      final v2IndexRef = _db.collection('inventory_index').doc(v2Key);
      final v3IndexRef = _db.collection('inventory_index').doc(v3Key);

      final logsSnap = await itemRef.collection('priceLogs').get();

      final batch = _db.batch();
      for (final doc in logsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(itemRef);
      batch.delete(legacyIndexRef);
      batch.delete(v2IndexRef);
      batch.delete(v3IndexRef);
      await batch.commit();
    } catch (e, st) {
      return Future.error(_humanizeError(e), st);
    }
  }
}
