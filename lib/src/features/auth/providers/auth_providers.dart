// Riverpod providers for auth state and user profile
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return null;
  final repo = ref.watch(authRepositoryProvider);
  return await repo.getUserProfile(authState.uid);
});

