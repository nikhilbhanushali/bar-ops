import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../users/providers/users_providers.dart'; // usersStreamProvider (List<AppUser>)
import '../../users/domain/app_user.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList());
});

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all'; // all | admin | store | designer | engineer | accounts

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Department (role) filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RoleChip(
                    label: 'All',
                    value: 'all',
                    groupValue: _roleFilter,
                    onSelected: (v) => setState(() => _roleFilter = v),
                  ),
                  const SizedBox(width: 6),
                  _RoleChip(label: 'Admin', value: 'admin', groupValue: _roleFilter, onSelected: (v) => setState(() => _roleFilter = v)),
                  const SizedBox(width: 6),
                  _RoleChip(label: 'Store', value: 'store', groupValue: _roleFilter, onSelected: (v) => setState(() => _roleFilter = v)),
                  const SizedBox(width: 6),
                  _RoleChip(label: 'Designer', value: 'designer', groupValue: _roleFilter, onSelected: (v) => setState(() => _roleFilter = v)),
                  const SizedBox(width: 6),
                  _RoleChip(label: 'Engineer', value: 'engineer', groupValue: _roleFilter, onSelected: (v) => setState(() => _roleFilter = v)),
                  const SizedBox(width: 6),
                  _RoleChip(label: 'Accounts', value: 'accounts', groupValue: _roleFilter, onSelected: (v) => setState(() => _roleFilter = v)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // List
            Expanded(
              child: usersAsync.when(
                data: (list) {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final filtered = list.where((u) {
                    final matchesRole = _roleFilter == 'all' || u.role.toLowerCase() == _roleFilter;
                    if (!matchesRole) return false;
                    if (q.isEmpty) return true;
                    final inName = u.displayName.toLowerCase().contains(q);
                    final inEmail = u.email.toLowerCase().contains(q);
                    return inName || inEmail;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _UserTile(user: filtered[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // open your existing "Add User" bottom sheet
          // showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const UserNewSheet());
        },
        label: const Text('Add User'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = user.status != 'active';
    return ListTile(
      title: Text(user.displayName),
      subtitle: Text('${user.email} • ${user.role}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted) const Icon(Icons.block, color: Colors.red),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final db = FirebaseFirestore.instance;
              final auth = FirebaseAuth.instance;

              try {
                if (value.startsWith('status:')) {
                  final status = value.split(':')[1];
                  await db.collection('users').doc(user.id).update({
                    'status': status,
                    'updatedAt': DateTime.now().toUtc().toIso8601String(),
                    'updatedBy': auth.currentUser!.uid,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Status set to $status')),
                  );
                } else if (value.startsWith('role:')) {
                  final role = value.split(':')[1];
                  await db.collection('users').doc(user.id).update({
                    'role': role,
                    'updatedAt': DateTime.now().toUtc().toIso8601String(),
                    'updatedBy': auth.currentUser!.uid,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Role changed to $role')),
                  );
                } else if (value == 'resetPassword') {
                  // Admin cannot directly set another user's password from client.
                  // Best practice: send a password reset email to the user.
                  await auth.sendPasswordResetEmail(email: user.email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'status:active', child: Text('Set Active')),
              PopupMenuItem(value: 'status:suspended', child: Text('Suspend')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'role:admin', child: Text('Role: Admin')),
              PopupMenuItem(value: 'role:store', child: Text('Role: Store')),
              PopupMenuItem(value: 'role:designer', child: Text('Role: Designer')),
              PopupMenuItem(value: 'role:engineer', child: Text('Role: Engineer')),
              PopupMenuItem(value: 'role:accounts', child: Text('Role: Accounts')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'resetPassword',
                child: Text('Send Password Reset Email'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
