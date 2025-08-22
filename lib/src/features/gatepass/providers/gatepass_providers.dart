import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/gateass_repository.dart';


/// Global provider for GatepassRepository using default Firebase instances.
final gatepassRepoProvider = Provider<GatepassRepository>((ref) {
  return GatepassRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});
