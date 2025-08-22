import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/users_repository.dart';
import '../domain/app_user.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(FirebaseFirestore.instance, FirebaseFunctions.instance, FirebaseAuth.instance);
});

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.read(usersRepositoryProvider).streamUsers();
});
