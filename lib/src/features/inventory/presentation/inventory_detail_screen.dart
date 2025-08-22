import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryDetailScreen extends StatelessWidget {
  const InventoryDetailScreen({super.key, required this.inventoryId});

  final String inventoryId;

  @override
  Widget build(BuildContext context) {
    final docRef =
    FirebaseFirestore.instance.collection('inventory').doc(inventoryId);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Item not found'));
          }

          final m = snap.data!.data()!;
          final title = (m['title'] ?? '') as String;
          final partNumber = (m['partNumber'] ?? '') as String;
          final uom = (m['uom'] ?? '') as String;
          final category = (m['category'] ?? '') as String; // tools|asset|raw
          final code = (m['code'] ?? '') as String;          // unique code
          final minQty = (m['minQty'] is num) ? (m['minQty'] as num).toDouble() : 0.0;
          final openingStock = (m['openingStock'] is num) ? (m['openingStock'] as num).toDouble() : 0.0;
          final currentStock = (m['currentStock'] is num) ? (m['currentStock'] as num).toDouble() : 0.0;

          final belowMin = currentStock < minQty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (partNumber.isNotEmpty)
                    Chip(label: Text('Part/SKU: $partNumber')),
                  if (uom.isNotEmpty)
                    Chip(label: Text('UoM: $uom')),
                  if (category.isNotEmpty)
                    Chip(label: Text('Category: $category')),
                  if (code.isNotEmpty)
                    Chip(label: Text('Code: $code')),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QtyTile(
                          label: 'Current Qty',
                          value: currentStock,
                          highlightColor: belowMin ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QtyTile(label: 'Min Qty', value: minQty),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QtyTile(label: 'Opening Stock', value: openingStock),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Meta (if present)
              _MetaBlock(map: m),
            ],
          );
        },
      ),
    );
  }
}

class _QtyTile extends StatelessWidget {
  const _QtyTile({
    required this.label,
    required this.value,
    this.highlightColor,
  });

  final String label;
  final double value;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final vStr = (value == value.roundToDouble())
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (highlightColor ?? Theme.of(context).dividerColor).withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            vStr,
            style: textTheme.headlineSmall?.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.map});
  final Map<String, dynamic> map;

  String _fmt(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final createdBy = _fmt(map['createdBy']);
    final updatedBy = _fmt(map['updatedBy']);
    final createdAt = map['createdAt'];
    final updatedAt = map['updatedAt'];

    String asIso(dynamic ts) {
      if (ts == null) return '';
      if (ts is Timestamp) return ts.toDate().toUtc().toIso8601String();
      return ts.toString();
    }

    final rows = <Widget>[
      if (createdBy.isNotEmpty) _metaRow('Created by', createdBy),
      if (asIso(createdAt).isNotEmpty) _metaRow('Created at', asIso(createdAt).substring(0, 19)),
      if (updatedBy.isNotEmpty) _metaRow('Updated by', updatedBy),
      if (asIso(updatedAt).isNotEmpty) _metaRow('Updated at', asIso(updatedAt).substring(0, 19)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metadata', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
