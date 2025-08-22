// BarOps root app: routes by auth state
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';


class BarOpsApp extends ConsumerWidget {
  const BarOpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    return MaterialApp(
      title: 'BarOps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          } else {
            return userProfileAsync.when(
              data: (profile) {
                if (profile == null) {
                  return const Scaffold(body: Center(child: Text('Loading profile...')));
                }
                // Route to HomeScreen (dashboard)
                return const HomeScreen();
              },
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
            );
          }
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}
