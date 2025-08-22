import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import '../../auth/providers/auth_providers.dart';
import '../../debug/ops_diagnostics_screen.dart';
import '../../inventory/presentation/admin_inventory_add_screen.dart';
import '../../inventory/presentation/admin_inventory_approvals_screen.dart';
import '../../inventory/presentation/import_inventory_screen.dart';
import '../../inventory/presentation/inventory_list_screen.dart';
import '../../inventory/presentation/store_add_inventory_screen.dart';
import '../../users/presentation/user_list_screen.dart';
import '../../vendors/presentation/vendor_list_screen.dart';



class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // TODO: Navigate to login
              }
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading profile: $e')),
        data: (p) {
          final displayName = (p?['displayName'] ?? 'User') as String;
          final role = (p?['role'] ?? 'unknown') as String;

          if (p == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Hi $displayName,\nYour account record is missing. Ask admin to create users/{uid}.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final isAdmin = role == 'admin';
          final isStore = role == 'store';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(displayName: displayName, role: role),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DashButton(
                      icon: Icons.inventory_2,
                      label: 'Inventory',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InventoryListScreen()),
                      ),
                    ),
                    if (isStore)
                      _DashButton.outlined(
                        icon: Icons.playlist_add,
                        label: 'Add (Store)',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StoreAddInventoryScreen()),
                        ),
                      ),
                    if (isAdmin)
                      _DashButton.outlined(
                        icon: Icons.checklist_rtl,
                        label: 'Approvals',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminInventoryApprovalsScreen()),
                        ),
                      ),
                    if (isAdmin)
                      _DashButton.outlined(
                        icon: Icons.add_box_outlined,
                        label: 'Add Inventory',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminAddInventoryScreen()),
                        ),
                      ),
                    if (isAdmin)
                      _DashButton.outlined(
                        icon: Icons.file_upload,
                        label: 'Import Inventory',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ImportInventoryScreen()),
                        ),
                      ),

                    // ------ Vendors ------
                    _DashButton(
                      icon: Icons.factory_outlined,
                      label: 'Vendors',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VendorListScreen()),
                      ),
                    ),

                    if (isAdmin)
                      _DashButton(
                        icon: Icons.group,
                        label: 'Users',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserListScreen()),
                        ),
                      ),
                    if (isAdmin)
                      _DashButton.outlined(
                        icon: Icons.bug_report,
                        label: 'Diagnostics',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OpsDiagnosticsScreen()),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.displayName, required this.role});
  final String displayName;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, $displayName', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Role: $role', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashButton extends StatelessWidget {
  const _DashButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _DashButton.outlined({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) : this(icon: icon, label: label, onTap: onTap, outlined: true);

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 180,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

    return outlined
        ? OutlinedButton(onPressed: onTap, child: child)
        : FilledButton(onPressed: onTap, child: child);
  }
}
