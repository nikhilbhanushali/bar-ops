// lib/features/users/presentation/user_new_sheet.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../users/data/users_admin_local_repository.dart';
import '../../users/providers/users_providers.dart'; // if you keep the users list stream

class UserNewSheet extends ConsumerStatefulWidget {
  const UserNewSheet({super.key});
  @override
  ConsumerState<UserNewSheet> createState() => _UserNewSheetState();
}

class _UserNewSheetState extends ConsumerState<UserNewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController(text: 'Temp@123'); // suggest/change
  String _role = 'store';
  bool _loading = false;
  String? _error;


  final usersAdminLocalRepoProvider = Provider<UsersAdminLocalRepository>((ref) {
    return UsersAdminLocalRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
  });


  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(usersAdminLocalRepoProvider);
      final uid = await repo.createUserAsAdmin(
        displayName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: _role,
        tempPassword: _pwdCtrl.text,
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User created (uid: $uid)')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Add User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (lowercase)'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || !v.contains('@')) return 'Enter a valid email';
                  if (v != v.toLowerCase()) return 'Use lowercase email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'store', child: Text('Store')),
                  DropdownMenuItem(value: 'designer', child: Text('Designer')),
                  DropdownMenuItem(value: 'engineer', child: Text('Engineer')),
                  DropdownMenuItem(value: 'accounts', child: Text('Accounts')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'store'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwdCtrl,
                decoration: const InputDecoration(labelText: 'Temporary password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}
