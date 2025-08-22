import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String code;       // INV-XXXXXX
  final String title;
  final String category;   // tools|asset|raw
  final String? vendorId;
  final String partNumber;
  final String uom;
  final String specs;
  final double currentPrice;
  final double minStock;
  final double openingStock;
  final String uniKey;     // v2|category|vendor|canonPart
  final String? legacyUniKey;
  final String createdAt;  // ISO if string; Timestamp acceptable in parsing
  final String updatedAt;

  InventoryItem({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.vendorId,
    required this.partNumber,
    required this.uom,
    required this.specs,
    required this.currentPrice,
    required this.minStock,
    required this.openingStock,
    required this.uniKey,
    required this.legacyUniKey,
    required this.createdAt,
    required this.updatedAt,
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
    if (v is String) return double.tryParse(v) ?? def;
    return def;
  }

  factory InventoryItem.fromDoc(String id, Map<String, dynamic> m) {
    return InventoryItem(
      id: id,
      code: (m['code'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      category: (m['category'] ?? '') as String,
      vendorId: m['vendorId'] as String?,
      partNumber: (m['partNumber'] ?? '') as String,
      uom: (m['uom'] ?? '') as String,
      specs: (m['specs'] ?? '') as String,
      currentPrice: _toDouble(m['currentPrice']),
      minStock: _toDouble(m['minStock']),
      openingStock: _toDouble(m['openingStock']),
      uniKey: (m['uniKey'] ?? '') as String,
      legacyUniKey: m['legacyUniKey'] as String?,
      createdAt: _toIso(m['createdAt']),
      updatedAt: _toIso(m['updatedAt']),
    );
  }

  Map<String, dynamic> toUpdateMap() => {
    'title': title,
    'uom': uom,
    'specs': specs,
    // we’re not letting UI mass-edit min/open here yet
  };
}
