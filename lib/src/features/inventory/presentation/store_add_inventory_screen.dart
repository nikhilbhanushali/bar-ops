import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_providers.dart';

class StoreAddInventoryScreen extends ConsumerStatefulWidget {
  const StoreAddInventoryScreen({super.key});

  @override
  ConsumerState<StoreAddInventoryScreen> createState() => _StoreAddInventoryScreenState();
}

class _StoreAddInventoryScreenState extends ConsumerState<StoreAddInventoryScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _part = TextEditingController();
  final _uom = TextEditingController(text: 'pcs');
  final _specs = TextEditingController();
  final _price = TextEditingController();
  final _vendor = TextEditingController();
  final _minStock = TextEditingController(text: '0');       // NEW
  final _openingStock = TextEditingController(text: '0');   // NEW
  final _notes = TextEditingController();

  String _category = 'tools';
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _part.dispose();
    _uom.dispose();
    _specs.dispose();
    _price.dispose();
    _vendor.dispose();
    _minStock.dispose();
    _openingStock.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _num(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  String _unwrapError(Object e) {
    if (e is AsyncError) return _unwrapError(e.error ?? 'Unknown error');
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(inventoryRepoProvider);
      await repo.submitDraft(
        title: _title.text,
        category: _category,
        vendorId: _vendor.text.trim().isEmpty ? null : _vendor.text.trim(),
        partNumber: _part.text,
        uom: _uom.text,
        specs: _specs.text,
        initPrice: _num(_price.text),
        notes: _notes.text,
        minStock: _num(_minStock.text),          // NEW
        openingStock: _num(_openingStock.text),  // NEW
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for approval')),
      );
    } catch (e, st) {
      if (!mounted) return;
      final msg = _unwrapError(e);
      // debugPrintStack(stackTrace: st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $msg')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const sp = 12.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Inventory (Store → Approval)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(children: [
            DropdownButtonFormField(
              value: _category,
              items: const [
                DropdownMenuItem(value: 'tools', child: Text('Tools')),
                DropdownMenuItem(value: 'asset', child: Text('Asset')),
                DropdownMenuItem(value: 'raw', child: Text('Raw')),
              ],
              onChanged: (v) => setState(() => _category = v as String),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter title' : null,
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _part,
              decoration: const InputDecoration(labelText: 'Part Number / SKU'),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter part number' : null,
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _uom,
              decoration: const InputDecoration(labelText: 'UoM'),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter unit' : null,
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _vendor,
              decoration: const InputDecoration(labelText: 'Vendor ID (optional)'),
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _specs,
              decoration: const InputDecoration(labelText: 'Specs (optional)'),
              maxLines: 2,
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Initial price (optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: sp),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    decoration: const InputDecoration(labelText: 'Min Stock'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '')) == null)
                        ? 'Enter a number'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _openingStock,
                    decoration: const InputDecoration(labelText: 'Opening Stock'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '')) == null)
                        ? 'Enter a number'
                        : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: sp),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional for admin)'),
              maxLines: 2,
            ),
            SizedBox(height: sp),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading ? const CircularProgressIndicator() : const Text('Submit for Approval'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
