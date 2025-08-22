import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/users/data/users_repository_no_functions.dart';
import '../../invite/data/invites_repository.dart';

final _db = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

final invitesRepoProvider = Provider((ref) => InvitesRepository(_db));
final usersRepoNoFxProvider = Provider((ref) => UsersRepositoryNoFx(_db, _auth));

class SignupWithInviteScreen extends ConsumerStatefulWidget {
  const SignupWithInviteScreen({super.key});

  @override
  ConsumerState<SignupWithInviteScreen> createState() => _SignupWithInviteScreenState();
}

class _SignupWithInviteScreenState extends ConsumerState<SignupWithInviteScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _pass.dispose(); _code.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final emailLc = _email.text.trim().toLowerCase();
      final invite = await ref.read(invitesRepoProvider).getInvite(emailLc);
      if (invite == null || invite['status'] != 'pending') {
        throw Exception('No active invite for this email');
      }
      if ((invite['code'] as String).trim().toUpperCase() != _code.text.trim().toUpperCase()) {
        throw Exception('Invalid invite code');
      }
      final role = invite['role'] as String;

      // Create auth user (client-side)
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailLc,
        password: _pass.text,
      );

      // Write profile (guarded by rules)
      await ref.read(usersRepoNoFxProvider).createProfileAfterSignup(
        displayName: _name.text.trim(),
        emailLc: emailLc,
        role: role,
      );

      // Mark invite used (admin-only in rules, so do it best-effort on client;
      // If you want to protect this, leave it to admin manually)
      try {
        await ref.read(invitesRepoProvider).markUsed(emailLc: emailLc, uid: FirebaseAuth.instance.currentUser!.uid);
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(); // back to login/home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signup complete')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = 12.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up with Invite')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  SizedBox(height: sp),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email (lowercase)'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || !v.contains('@')) return 'Enter valid email';
                      if (v != v.toLowerCase()) return 'Use lowercase email';
                      return null;
                    },
                  ),
                  SizedBox(height: sp),
                  TextFormField(
                    controller: _pass,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  SizedBox(height: sp),
                  TextFormField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Invite code'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter code' : null,
                  ),
                  SizedBox(height: sp),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  SizedBox(height: sp),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _signup,
                      child: _loading ? const CircularProgressIndicator() : const Text('Sign up'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
