import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gatepass.dart';
import '../providers/gatepass_providers.dart';
import 'gatepass_create_screen.dart';
import 'gatepass_view_screen.dart';

class GatepassListScreen extends ConsumerStatefulWidget {
  const GatepassListScreen({super.key, this.canCreate = true});
  final bool canCreate;

  @override
  ConsumerState<GatepassListScreen> createState() => _GatepassListScreenState();
}

class _GatepassListScreenState extends ConsumerState<GatepassListScreen> {
  String? _type; // 'inward'|'outward'|null
  bool _returnableOnly = false;
  bool _overdueOnly = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(gatepassRepoProvider);
    final stream = repo.streamGatepasses(
      typeFilter: _type,
      returnableOnly: _returnableOnly,
      overdueOnly: _overdueOnly,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gatepasses'),
        actions: [
          if (widget.canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GatepassCreateScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  value: _type,
                  hint: const Text('Type'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'inward', child: Text('Inward')),
                    DropdownMenuItem(value: 'outward', child: Text('Outward')),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
                FilterChip(
                  label: const Text('Returnable only'),
                  selected: _returnableOnly,
                  onSelected: (v) => setState(() => _returnableOnly = v),
                ),
                FilterChip(
                  label: const Text('Overdue only'),
                  selected: _overdueOnly,
                  onSelected: (v) => setState(() => _overdueOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Gatepass>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? const <Gatepass>[];
                if (list.isEmpty) return const Center(child: Text('No gatepasses'));

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final gp = list[i];
                    final t = gp.type == GatepassType.outward ? 'Outward' : 'Inward';
                    final ret = gp.returnable ? ' (Returnable)' : '';
                    final redFlag = gp.type == GatepassType.inward && gp.returnable && !gp.billUploaded;

                    final vendorText = (gp.vendorName != null && gp.vendorName!.isNotEmpty)
                        ? gp.vendorName!
                        : (gp.customVendorName ?? '');

                    final title = '${gp.code} • $t$ret';

                    final subtitleBits = <String>[
                      if (vendorText.isNotEmpty) vendorText,
                      'Status: ${gp.status}',
                      if (gp.expectedDateIso != null && gp.expectedDateIso!.isNotEmpty)
                        'Due: ${gp.expectedDateIso!.substring(0, 10)}',
                    ];

                    return ListTile(
                      title: Text(title),
                      subtitle: Text(subtitleBits.join(' • ')),
                      trailing: redFlag ? const Icon(Icons.receipt_long, color: Colors.red) : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GatepassViewScreen(gatepassId: gp.id)),
                      ),
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
