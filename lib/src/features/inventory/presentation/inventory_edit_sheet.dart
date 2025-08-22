import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final inventoryRepoProvider = Provider((ref) =>
    InventoryRepository(FirebaseFirestore.instance, FirebaseAuth.instance));

class InventoryEditSheet extends ConsumerStatefulWidget {
  const InventoryEditSheet({super.key, required this.item});
  final InventoryItem item;

  @override
  ConsumerState<InventoryEditSheet> createState() => _InventoryEditSheetState();
}

class _InventoryEditSheetState extends ConsumerState<InventoryEditSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
  TextEditingController(text: widget.item.title);
  late final TextEditingController _uom =
  TextEditingController(text: widget.item.uom);
  late final TextEditingController _specs =
  TextEditingController(text: widget.item.specs);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _uom.dispose();
    _specs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Edit ${widget.item.code}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _uom,
              decoration: const InputDecoration(labelText: 'UoM'),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter unit' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specs,
              decoration: const InputDecoration(labelText: 'Specs'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Note: price, category, vendor & part no. are not editable here.\n'
                    'Price updates will come from GRN/Gatepass later.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() => _saving = true);
                  try {
                    await ref.read(inventoryRepoProvider).updateItem(
                      itemId: widget.item.id,
                      title: _title.text,
                      uom: _uom.text,
                      specs: _specs.text,
                    );
                    if (mounted) Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Inventory updated')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
