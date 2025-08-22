import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/inventory_repository.dart';

/// Centralized provider for the InventoryRepository (use this everywhere)
final inventoryRepoProvider = Provider<InventoryRepository>(
      (ref) => InventoryRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  ),
);

/// Optional: user role stream (if you need it on screens)
final userRoleProvider = StreamProvider<String?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.data()?['role'] as String?);
});
