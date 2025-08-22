import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_inventory_add_screen.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_edit_sheet.dart';
import '../../inventory/presentation/store_add_inventory_screen.dart';


// Provider for repo (simple local provider)
final inventoryRepoProvider = Provider(
      (ref) => InventoryRepository(FirebaseFirestore.instance, FirebaseAuth.instance),
);

// Current user role stream (reads users/{uid}.role)
final userRoleProvider = StreamProvider<String?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.data()?['role'] as String?);
});

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider).value ?? 'unknown';
    final isAdmin = role == 'admin';
    final isStore = role == 'store';

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search code, title, part number…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: ref.read(inventoryRepoProvider).streamInventoryItems(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                final q = _search.text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? items
                    : items.where((it) {
                  return it.code.toLowerCase().contains(q) ||
                      it.title.toLowerCase().contains(q) ||
                      it.partNumber.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No items'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = filtered[i];
                    return ListTile(
                      title: Text('${it.code} — ${it.title}'),
                      subtitle: Text(
                        '${it.category} • Part: ${it.partNumber} • UoM: ${it.uom}'
                            '${it.vendorId != null ? ' • Vendor: ${it.vendorId}' : ''}'
                            ' • ₹${it.currentPrice.toStringAsFixed(2)}',
                      ),
                      trailing: isAdmin
                          ? PopupMenuButton<String>(
                        onSelected: (v) async {
                          final repo = ref.read(inventoryRepoProvider);
                          if (v == 'edit') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => InventoryEditSheet(item: it),
                            );
                          } else if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete item?'),
                                content: Text('This will remove ${it.code} and its price logs.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await repo.deleteItem(item: it);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Deleted ${it.code}')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (isStore || isAdmin)
          ? FloatingActionButton.extended(
        onPressed: () {
          if (isAdmin) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAddInventoryScreen()),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoreAddInventoryScreen()),
            );
          }
        },
        label: Text(isAdmin ? 'Add (Admin)' : 'Add'),
        icon: const Icon(Icons.add),
      )
          : null,
    );
  }
}
