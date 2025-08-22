import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vendor.dart';
import '../providers/vendor_providers.dart';
import 'vendor_add_screen.dart';
import 'vendor_edit_screen.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  const VendorListScreen({super.key});

  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<Map<String, dynamic>?> _currentUserDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((d) => d.data());
  }

  bool _matches(Vendor v, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    bool contains(String x) => x.toLowerCase().contains(s);
    return contains(v.name) ||
        contains(v.gstDetail) ||
        contains(v.address) ||
        contains(v.contactPerson) ||
        contains(v.phone) ||
        contains(v.email) ||
        contains(v.notes);
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsStreamProvider);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _currentUserDoc(),
      builder: (context, roleSnap) {
        final role = (roleSnap.data?['role'] ?? 'unknown') as String;
        final isAdmin = role == 'admin';
        final isStore = role == 'store';

        return Scaffold(
          appBar: AppBar(title: const Text('Vendors')),
          floatingActionButton: (isAdmin || isStore)
              ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorAddScreen()));
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add Vendor'),
          )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search vendors (name, GST, phone, email...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _search.clear());
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: vendorsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (list) {
                    final vendors = (list as List<Vendor>).where((v) => _matches(v, _search.text)).toList();
                    if (vendors.isEmpty) {
                      return const Center(child: Text('No vendors found'));
                    }
                    return ListView.separated(
                      itemCount: vendors.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = vendors[i];
                        return ListTile(
                          title: Text(v.name),
                          subtitle: Text([
                            if (v.gstDetail.isNotEmpty) 'GST: ${v.gstDetail}',
                            if (v.contactPerson.isNotEmpty) 'Contact: ${v.contactPerson}',
                            if (v.phone.isNotEmpty) 'Phone: ${v.phone}',
                            if (v.email.isNotEmpty) 'Email: ${v.email}',
                          ].join(' • ')),
                          onTap: isAdmin
                              ? () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => VendorEditScreen(vendor: v)),
                          )
                              : null,
                          trailing: isAdmin
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => VendorEditScreen(vendor: v)),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete vendor?'),
                                      content: Text('This will remove "${v.name}". This cannot be undone.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    await ref.read(vendorRepoProvider).deleteVendor(v.id);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendor deleted')));
                                  }
                                },
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
        );
      },
    );
  }
}
