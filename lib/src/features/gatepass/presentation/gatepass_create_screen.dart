import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gatepass.dart';
import '../providers/gatepass_providers.dart';

class GatepassCreateScreen extends ConsumerStatefulWidget {
  const GatepassCreateScreen({super.key});

  @override
  ConsumerState<GatepassCreateScreen> createState() => _GatepassCreateScreenState();
}

class _GatepassCreateScreenState extends ConsumerState<GatepassCreateScreen> {
  GatepassType _type = GatepassType.inward;
  bool _returnable = false;
  DateTime? _expectedDate;

  // Vendor
  String? _vendorId;
  String? _vendorName;
  final _customVendorCtrl = TextEditingController();

  // Items for gatepass: each map must match {source,title,partNumber,uom,qty, inventoryId?}
  final List<Map<String, dynamic>> _items = [];

  @override
  void dispose() {
    _customVendorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpectedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expectedDate = picked);
  }

  // ---------- Vendor list ----------
  Stream<List<Map<String, String>>> _vendors() {
    return FirebaseFirestore.instance
        .collection('vendors')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) {
      final m = d.data();
      final name = (m['name'] ?? '').toString();
      return {'id': d.id, 'name': name};
    }).toList());
  }

  // ---------- Inventory picker ----------
  Future<void> _addFromInventory() async {
    final picked = await showModalBottomSheet<_PickedInventory>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _InventoryPickerSheet(),
    );
    if (picked == null) return;

    // Optional: merge with existing same inventoryId (sum qty)
    final idx = _items.indexWhere((e) => e['source'] == 'inventory' && e['inventoryId'] == picked.id);
    if (idx >= 0) {
      setState(() {
        final oldQty = (_items[idx]['qty'] as num?)?.toDouble() ?? 0.0;
        _items[idx]['qty'] = (oldQty + picked.qty).toDouble();
      });
    } else {
      setState(() {
        _items.add({
          'source': 'inventory',
          'inventoryId': picked.id,
          'title': picked.title,
          'partNumber': picked.partNumber,
          'uom': picked.uom,
          'qty': picked.qty,
        });
      });
    }
  }

  // ---------- Manual item ----------
  Future<void> _addManual() async {
    final manual = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualItemSheet(),
    );
    if (manual == null) return;
    setState(() => _items.add(manual));
  }

  // ---------- Edit qty ----------
  Future<void> _editQty(int index) async {
    final current = (_items[index]['qty'] as num?)?.toString() ?? '';
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit quantity'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(hintText: 'Enter quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != null && ok > 0) {
      setState(() => _items[index]['qty'] = ok);
    }
  }

  // ---------- Submit ----------
  Future<void> _submit() async {
    if (_returnable && _expectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set expected return date')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    final repo = ref.read(gatepassRepoProvider);
    try {
      final id = await repo.createGatepass(
        type: _type,
        returnable: _returnable,
        expectedDate: _returnable ? _expectedDate : null,
        vendorId: _vendorId,
        vendorName: _vendorName,
        customVendorName: _customVendorCtrl.text,
        items: _items,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gatepass created: $id')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Gatepass')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type & returnable
          Row(
            children: [
              const Text('Type:'),
              const SizedBox(width: 12),
              DropdownButton<GatepassType>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: GatepassType.inward, child: Text('Inward')),
                  DropdownMenuItem(value: GatepassType.outward, child: Text('Outward')),
                ],
                onChanged: (v) => setState(() => _type = v ?? GatepassType.inward),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('Returnable'),
                  Switch(
                    value: _returnable,
                    onChanged: (v) => setState(() => _returnable = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Returnable → Expected Date
          if (_returnable) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expected Return Date'),
              subtitle: Text(_expectedDate == null
                  ? 'Not set'
                  : _expectedDate!.toIso8601String().substring(0, 10)),
              trailing: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Pick'),
                onPressed: _pickExpectedDate,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Vendor dropdown
          StreamBuilder<List<Map<String, String>>>(
            stream: _vendors(),
            builder: (context, snap) {
              final list = snap.data ?? const <Map<String, String>>[];
              return DropdownButtonFormField<String>(
                value: _vendorId,
                decoration: const InputDecoration(
                  labelText: 'Select vendor (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('None')),
                  ...list.map((v) => DropdownMenuItem<String>(
                    value: v['id']!,
                    child: Text(v['name'] ?? ''),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _vendorId = v;
                    _vendorName = list.firstWhere(
                          (e) => e['id'] == v,
                      orElse: () => {'name': ''},
                    )['name'];
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Custom vendor name
          TextField(
            controller: _customVendorCtrl,
            decoration: const InputDecoration(
              labelText: 'Custom vendor name (optional)',
              hintText: 'If not in list, type vendor name here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- Items ----------------
          Row(
            children: [
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _addFromInventory,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Add from Inventory'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addManual,
                icon: const Icon(Icons.edit_note),
                label: const Text('Add Manual'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No items added yet'),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = _items[i];
                  final source = (it['source'] ?? '') as String;
                  final title = (it['title'] ?? '') as String;
                  final part = (it['partNumber'] ?? '') as String;
                  final uom = (it['uom'] ?? '') as String;
                  final qty = (it['qty'] ?? '').toString();

                  return ListTile(
                    leading: Icon(source == 'inventory' ? Icons.inventory_2_outlined : Icons.edit_note),
                    title: Text(title.isEmpty ? '(untitled)' : title),
                    subtitle: Text([
                      if (part.isNotEmpty) part,
                      if (uom.isNotEmpty) uom,
                      'Qty $qty',
                      if (source == 'inventory' && it['inventoryId'] != null) '• ID ${it['inventoryId']}',
                    ].join(' • ')),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Edit Qty',
                          icon: const Icon(Icons.calculate),
                          onPressed: () => _editQty(i),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save),
            label: const Text('Create Gatepass'),
          ),
        ],
      ),
    );
  }
}

/// ----- Inventory Picker Bottom Sheet -----

class _InventoryPickerSheet extends StatefulWidget {
  const _InventoryPickerSheet();

  @override
  State<_InventoryPickerSheet> createState() => _InventoryPickerSheetState();
}

class _InventoryPickerSheetState extends State<_InventoryPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<List<_PickedInventory>> _inventoryStream() {
    return FirebaseFirestore.instance
        .collection('inventory')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
      final m = d.data();
      return _PickedInventory(
        id: d.id,
        code: (m['code'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        partNumber: (m['partNumber'] ?? '').toString(),
        uom: (m['uom'] ?? '').toString(),
        currentStock: (m['currentStock'] is num)
            ? (m['currentStock'] as num).toDouble()
            : (double.tryParse('${m['currentStock']}') ?? 0),
      );
    }).toList());
  }

  Future<void> _pickQtyAndReturn(_PickedInventory base) async {
    final ctrl = TextEditingController(text: '1');
    final qty = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Qty for ${base.code}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(hintText: 'Enter quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (qty != null && qty > 0) {
      Navigator.pop(context, base.copyWith(qty: qty));
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select from Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search code, title, part…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: StreamBuilder<List<_PickedInventory>>(
              stream: _inventoryStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <_PickedInventory>[];
                final q = _search.text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? list
                    : list.where((e) {
                  return e.code.toLowerCase().contains(q) ||
                      e.title.toLowerCase().contains(q) ||
                      e.partNumber.toLowerCase().contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No matches'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = filtered[i];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text('${it.code} — ${it.title}'),
                      subtitle: Text('Part: ${it.partNumber} • UoM: ${it.uom} • Stock: ${it.currentStock}'),
                      onTap: () => _pickQtyAndReturn(it),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedInventory {
  final String id;
  final String code;
  final String title;
  final String partNumber;
  final String uom;
  final double currentStock;
  final double qty;

  _PickedInventory({
    required this.id,
    required this.code,
    required this.title,
    required this.partNumber,
    required this.uom,
    required this.currentStock,
    this.qty = 1.0,
  });

  _PickedInventory copyWith({double? qty}) => _PickedInventory(
    id: id,
    code: code,
    title: title,
    partNumber: partNumber,
    uom: uom,
    currentStock: currentStock,
    qty: qty ?? this.qty,
  );
}

/// ----- Manual Item Bottom Sheet -----

class _ManualItemSheet extends StatefulWidget {
  const _ManualItemSheet();

  @override
  State<_ManualItemSheet> createState() => _ManualItemSheetState();
}

class _ManualItemSheetState extends State<_ManualItemSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _part = TextEditingController();
  final _uom = TextEditingController(text: 'pcs');
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _title.dispose();
    _part.dispose();
    _uom.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
    return Padding(
      padding: padding,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Manual Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _part,
                decoration: const InputDecoration(labelText: 'Part Number / SKU', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uom,
                decoration: const InputDecoration(labelText: 'UoM', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                validator: (v) {
                  final val = double.tryParse((v ?? '').trim());
                  if (val == null || val <= 0) return 'Enter a valid qty';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final map = {
                        'source': 'manual',
                        'title': _title.text.trim(),
                        'partNumber': _part.text.trim(),
                        'uom': _uom.text.trim(),
                        'qty': double.parse(_qty.text.trim()),
                      };
                      Navigator.pop(context, map);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
