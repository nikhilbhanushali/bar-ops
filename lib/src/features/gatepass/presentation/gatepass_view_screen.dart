import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gatepass.dart';
import '../providers/gatepass_providers.dart';

class GatepassViewScreen extends ConsumerWidget {
  const GatepassViewScreen({super.key, required this.gatepassId});
  final String gatepassId;

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null ? '' : d.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = FirebaseFirestore.instance;
    final repo = ref.watch(gatepassRepoProvider);
    final docStream = db.collection('gatepasses').doc(gatepassId).snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Gatepass Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Not found'));
          }
          final m = snap.data!.data()!;
          final gp = Gatepass.fromDoc(snap.data!.id, m);
          final t = gp.type == GatepassType.outward ? 'Outward' : 'Inward';
          final ret = gp.returnable ? ' (Returnable)' : '';

          Future<void> _dispatch() async {
            try {
              await repo.markDispatched(gp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked Dispatched')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }

          Future<void> _returned() async {
            try {
              await repo.markReturned(gp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked Returned')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }

          Future<void> _complete() async {
            try {
              await repo.markCompleted(gp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked Completed')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }

          List<Widget> _actions() {
            final st = gp.status;
            final isORGP = gp.type == GatepassType.outward && gp.returnable;
            final list = <Widget>[];
            if (st == 'pending' && gp.type == GatepassType.outward) {
              list.add(FilledButton.icon(onPressed: _dispatch, icon: const Icon(Icons.local_shipping), label: const Text('Dispatch')));
            }
            if (isORGP && st == 'dispatched') {
              list.add(FilledButton.icon(onPressed: _returned, icon: const Icon(Icons.undo), label: const Text('Mark Returned')));
            }
            if (st == 'pending' && gp.type == GatepassType.inward) {
              list.add(FilledButton.icon(onPressed: _complete, icon: const Icon(Icons.check), label: const Text('Complete')));
            }
            if (st == 'dispatched' && gp.type == GatepassType.outward && !isORGP) {
              list.add(FilledButton.icon(onPressed: _complete, icon: const Icon(Icons.check), label: const Text('Complete')));
            }
            if (st == 'returned' && isORGP) {
              list.add(FilledButton.icon(onPressed: _complete, icon: const Icon(Icons.check), label: const Text('Complete')));
            }
            return list;
          }

          final vendorText = (gp.vendorName != null && gp.vendorName!.isNotEmpty)
              ? gp.vendorName!
              : (gp.customVendorName ?? '');

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('${gp.code} • $t$ret', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text('Status: ${gp.status.toUpperCase()}')),
                    if (vendorText.isNotEmpty) Chip(label: Text('Vendor: $vendorText')),
                    if (gp.projectId != null && gp.projectId!.isNotEmpty) Chip(label: Text('Project: ${gp.projectId}')),
                    if (gp.expectedDateIso != null && gp.expectedDateIso!.isNotEmpty) Chip(label: Text('Due: ${_fmtDate(gp.expectedDateIso)}')),
                    if (gp.type == GatepassType.inward && gp.returnable && !gp.billUploaded)
                      const Chip(label: Text('Bill missing'), avatar: Icon(Icons.receipt_long, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                ...gp.items.map((e) {
                  final map = Map<String, dynamic>.from(e);
                  final source = (map['source'] ?? '') as String;
                  final title = (map['title'] ?? '') as String;
                  final part = (map['partNumber'] ?? '') as String;
                  final uom = (map['uom'] ?? '') as String;
                  final qty = map['qty'];

                  return ListTile(
                    leading: Icon(source == 'inventory' ? Icons.inventory_2_outlined : Icons.edit_note),
                    title: Text(title.isEmpty ? '(untitled)' : title),
                    subtitle: Text([
                      if (part.isNotEmpty) part,
                      if (uom.isNotEmpty) uom,
                      if (qty != null) 'Qty $qty',
                    ].join(' • ')),
                  );
                }),
                const SizedBox(height: 24),
                Row(
                  children: [
                    for (final a in _actions()) ...[
                      a,
                      const SizedBox(width: 12),
                    ]
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
