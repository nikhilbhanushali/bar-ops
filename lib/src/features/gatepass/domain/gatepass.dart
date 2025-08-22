import 'package:cloud_firestore/cloud_firestore.dart';

enum GatepassType { inward, outward }

class Gatepass {
  final String id;
  final String code;

  final GatepassType type;       // inward | outward
  final bool returnable;         // true → expectedDate matters
  final String status;           // pending|dispatched|returned|completed|cancelled

  final String? expectedDateIso; // ISO string for returnable passes
  final bool billUploaded;       // mainly for inward returnable

  // Vendor can be selected (vendorId+vendorName) OR customVendorName
  final String? vendorId;
  final String? vendorName;
  final String? customVendorName;

  final String? projectId;

  /// Each item: {source: 'inventory'|'manual', inventoryId?, title, partNumber, uom, qty}
  final List<Map<String, dynamic>> items;

  final String createdBy;
  final String? updatedBy;
  final dynamic createdAt; // Timestamp|String
  final dynamic updatedAt;

  Gatepass({
    required this.id,
    required this.code,
    required this.type,
    required this.returnable,
    required this.status,
    required this.billUploaded,
    required this.items,
    required this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.expectedDateIso,
    this.vendorId,
    this.vendorName,
    this.customVendorName,
    this.projectId,
  });

  static GatepassType _typeFrom(String s) =>
      (s == 'outward') ? GatepassType.outward : GatepassType.inward;

  static String _typeTo(GatepassType t) =>
      t == GatepassType.outward ? 'outward' : 'inward';

  factory Gatepass.fromDoc(String id, Map<String, dynamic> m) {
    String? _iso(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
      return v.toString();
    }

    return Gatepass(
      id: id,
      code: (m['code'] ?? '') as String,
      type: _typeFrom((m['type'] ?? 'inward') as String),
      returnable: (m['returnable'] ?? false) as bool,
      status: (m['status'] ?? 'pending') as String,
      expectedDateIso: _iso(m['expectedDate']),
      billUploaded: (m['billUploaded'] ?? false) as bool,
      vendorId: m['vendorId'] as String?,
      vendorName: m['vendorName'] as String?,
      customVendorName: m['customVendorName'] as String?,
      projectId: m['projectId'] as String?,
      items: ((m['items'] as List?) ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdBy: (m['createdBy'] ?? '') as String,
      updatedBy: m['updatedBy'] as String?,
      createdAt: m['createdAt'],
      updatedAt: m['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': _typeTo(type),
      'returnable': returnable,
      'status': status,
      'expectedDate': expectedDateIso,
      'billUploaded': billUploaded,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'customVendorName': customVendorName,
      'projectId': projectId,
      'items': items,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
