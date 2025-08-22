import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_submission.dart';
import '../providers/inventory_providers.dart';


class AdminInventoryApprovalsScreen extends ConsumerWidget {
  const AdminInventoryApprovalsScreen({super.key});

  String _unwrapError(Object e) {
    if (e is AsyncError) {
      return _unwrapError(e.error ?? 'Unknown error');
    }
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(inventoryRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Approvals')),
      body: StreamBuilder<List<InventorySubmission>>(
        stream: repo.streamPendingSubmissions(),
        builder: (context, snap) {
          if (snap.hasError) {
            final msg = _unwrapError(snap.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: $msg',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data ?? <InventorySubmission>[];
          if (list.isEmpty) {
            return const Center(child: Text('Nothing to approve'));
          }

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                title: Text('${s.title}  (${s.category})'),
                subtitle: Text(
                  [
                    'Part: ${s.partNumber}',
                    'UoM: ${s.uom}',
                    if (s.vendorId != null && s.vendorId!.isNotEmpty) 'Vendor: ${s.vendorId}',
                    if (s.initPrice != null) '₹${s.initPrice!.toStringAsFixed(2)}',
                    'By: ${s.createdBy}',
                  ].join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Reject',
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        try {
                          await repo.rejectSubmission(s);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Submission rejected')),
                            );
                          }
                        } catch (e, st) {
                          final msg = _unwrapError(e);
                          if (context.mounted) {
                            // debugPrintStack(stackTrace: st);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $msg')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Approve',
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        try {
                          await repo.approveSubmission(s);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Approved & added to inventory')),
                            );
                          }
                        } catch (e, st) {
                          final msg = _unwrapError(e);
                          if (context.mounted) {
                            // debugPrintStack(stackTrace: st);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $msg')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
