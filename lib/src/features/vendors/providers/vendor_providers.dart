import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/vendor_repository.dart';

// Global provider for VendorRepository
final vendorRepoProvider = Provider<VendorRepository>((ref) {
  return VendorRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

// Optional: stream provider if you prefer DI in widgets
final vendorsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(vendorRepoProvider);
  return repo.streamVendors();
});
