import 'package:cloud_firestore/cloud_firestore.dart';

class InventorySubmission {
  final String id;

  final String title;
  final String category; // tools|asset|raw
  final String? vendorId;
  final String partNumber;
  final String uom;
  final String specs;

  final double? initPrice;
  final double minStock;      // NEW
  final double openingStock;  // NEW

  final String status; // pending|approved|rejected
  final String createdBy;
  final String? decidedBy;

  final String? notes;

  final String createdAt; // ISO (from Timestamp or String)
  final String? decidedAt; // ISO

  InventorySubmission({
    required this.id,
    required this.title,
    required this.category,
    required this.vendorId,
    required this.partNumber,
    required this.uom,
    required this.specs,
    required this.initPrice,
    required this.minStock,
    required this.openingStock,
    required this.status,
    required this.createdBy,
    required this.decidedBy,
    required this.notes,
    required this.createdAt,
    required this.decidedAt,
  });

  static String _toIso(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    return v.toString();
  }

  static double _toDouble(dynamic v, [double def = 0.0]) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? def;
    return def;
  }

  factory InventorySubmission.fromDoc(String id, Map<String, dynamic> m) {
    return InventorySubmission(
      id: id,
      title: (m['title'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      vendorId: (m['vendorId'] as String?),
      partNumber: (m['partNumber'] ?? '').toString(),
      uom: (m['uom'] ?? '').toString(),
      specs: (m['specs'] ?? '').toString(),
      initPrice: m['initPrice'] == null
          ? null
          : _toDouble(m['initPrice']),
      minStock: _toDouble(m['minStock'], 0.0),
      openingStock: _toDouble(m['openingStock'], 0.0),
      status: (m['status'] ?? 'pending').toString(),
      createdBy: (m['createdBy'] ?? '').toString(),
      decidedBy: (m['decidedBy'] as String?),
      notes: (m['notes'] as String?),
      createdAt: _toIso(m['createdAt']),
      decidedAt: m['decidedAt'] == null ? null : _toIso(m['decidedAt']),
    );
  }
}
