import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/invites_repository.dart';

final invitesRepoProvider = Provider((ref) => InvitesRepository(FirebaseFirestore.instance));

class InviteNewSheet extends ConsumerStatefulWidget {
  const InviteNewSheet({super.key});

  @override
  ConsumerState<InviteNewSheet> createState() => _InviteNewSheetState();
}

class _InviteNewSheetState extends ConsumerState<InviteNewSheet> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = 'store';
  bool _loading = false;
  String _code = _genCode();

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
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
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Invite User', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'store', child: Text('Store')),
                  DropdownMenuItem(value: 'designer', child: Text('Designer')),
                  DropdownMenuItem(value: 'engineer', child: Text('Engineer')),
                  DropdownMenuItem(value: 'accounts', child: Text('Accounts')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v as String),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Invite Code:'), const SizedBox(width: 8),
                SelectableText(_code, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => setState(() => _code = _genCode()), child: const Text('Regenerate')),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () async {
                    if (!_form.currentState!.validate()) return;
                    setState(() => _loading = true);
                    try {
                      final adminUid = FirebaseAuth.instance.currentUser!.uid;
                      await ref.read(invitesRepoProvider).createInvite(
                        adminUid: adminUid,
                        email: _email.text.trim(),
                        role: _role,
                        code: _code,
                      );
                      if (mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invite created. Share code: $_code')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  child: _loading ? const CircularProgressIndicator() : const Text('Create Invite'),
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
