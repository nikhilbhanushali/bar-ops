import 'package:cloud_firestore/cloud_firestore.dart';

class Vendor {
  final String id;
  final String name;
  final String gstDetail;        // GSTIN or GST details
  final String address;
  final String contactPerson;
  final String phone;
  final String email;
  final String notes;

  final String createdBy;
  final String createdAt;        // ISO string or Timestamp converted
  final String updatedBy;
  final String updatedAt;        // ISO string

  Vendor({
    required this.id,
    required this.name,
    required this.gstDetail,
    required this.address,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
  });

  static String _iso(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    return v.toString();
  }

  factory Vendor.fromDoc(String id, Map<String, dynamic> m) {
    return Vendor(
      id: id,
      name: (m['name'] ?? '').toString(),
      gstDetail: (m['gstDetail'] ?? '').toString(),
      address: (m['address'] ?? '').toString(),
      contactPerson: (m['contactPerson'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      email: (m['email'] ?? '').toString(),
      notes: (m['notes'] ?? '').toString(),
      createdBy: (m['createdBy'] ?? '').toString(),
      createdAt: _iso(m['createdAt']),
      updatedBy: (m['updatedBy'] ?? '').toString(),
      updatedAt: _iso(m['updatedAt']),
    );
  }
}
