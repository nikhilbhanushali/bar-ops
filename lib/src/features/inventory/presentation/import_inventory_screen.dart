import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_providers.dart';

class ImportInventoryScreen extends ConsumerStatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  ConsumerState<ImportInventoryScreen> createState() => _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends ConsumerState<ImportInventoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  String? _fileName;
  bool _loading = false;
  String? _message;

  Future<void> _pickFile() async {
    setState(() {
      _rows = [];
      _fileName = null;
      _message = null;
    });

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final file = res.files.single;
    _fileName = file.name;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _message = 'Could not read file bytes.');
      return;
    }
    final ext = (_fileName!.split('.').last).toLowerCase();

    try {
      if (ext == 'csv') {
        _rows = _parseCsv(bytes);
      } else if (ext == 'xlsx') {
        _rows = _parseXlsx(bytes);
      } else {
        setState(() => _message = 'Unsupported file type.');
        return;
      }
      setState(() {});
    } catch (e) {
      setState(() => _message = 'Parse error: $e');
    }
  }

  List<Map<String, dynamic>> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes);
    final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final values = _splitCsvLine(lines[i]);
      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < values.length; j++) {
        map[headers[j]] = values[j].trim();
      }
      rows.add(_coerceRow(map));
    }
    return rows;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"' ) {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"'); i++; // escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString());
    return result;
  }

  List<Map<String, dynamic>> _parseXlsx(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final table = excel.tables.values.first;
    if (table == null) return [];

    // First row as header
    final headerRow = table.rows.first;
    final headers = headerRow
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();

    final rows = <Map<String, dynamic>>[];
    for (int r = 1; r < table.rows.length; r++) {
      final row = table.rows[r];
      final map = <String, dynamic>{};
      for (int c = 0; c < headers.length && c < row.length; c++) {
        map[headers[c]] = (row[c]?.value?.toString() ?? '').trim();
      }
      rows.add(_coerceRow(map));
    }
    return rows;
  }

  Map<String, dynamic> _coerceRow(Map<String, dynamic> m) {
    double? _d(v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', ''));
      return null;
    }

    return {
      'title': (m['title'] ?? '').toString(),
      'category': (m['category'] ?? '').toString(),
      'vendorId': (m['vendorid'] ?? m['vendor_id'] ?? m['vendor'] ?? '').toString(),
      'partNumber': (m['partnumber'] ?? m['part_number'] ?? m['sku'] ?? '').toString(),
      'uom': (m['uom'] ?? 'pcs').toString(),
      'specs': (m['specs'] ?? '').toString(),
      'initPrice': _d(m['initprice'] ?? m['price']),
      'minStock': _d(m['minstock'] ?? m['min_stock']),
      'openingStock': _d(m['openingstock'] ?? m['opening_stock']),
    };
  }

  Future<void> _import() async {
    if (_rows.isEmpty) {
      setState(() => _message = 'No rows to import.');
      return;
    }
    setState(() { _loading = true; _message = null; });
    try {
      final repo = ref.read(inventoryRepoProvider);
      final created = await repo.adminBulkCreate(_rows);
      setState(() => _message = 'Imported ${created.length}/${_rows.length} items.');
    } catch (e) {
      setState(() => _message = 'Import failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Inventory (Excel/CSV)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick .xlsx / .csv'),
                ),
                const SizedBox(width: 12),
                if (_rows.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _loading ? null : _import,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Import'),
                  ),
              ],
            ),
          ),
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('File: $_fileName'),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_message!, style: TextStyle(color: _message!.startsWith('Import') ? Colors.green : Colors.red)),
            ),
          const Divider(height: 1),
          Expanded(
            child: _rows.isEmpty
                ? const Center(child: Text('No data loaded. Use the button to pick a file.'))
                : ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (_, i) {
                final r = _rows[i];
                return ListTile(
                  dense: true,
                  title: Text('${r['title']} • ${r['partNumber']}'),
                  subtitle: Text('cat=${r['category']} • uom=${r['uom']} • min=${r['minStock'] ?? 0} • open=${r['openingStock'] ?? 0}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
