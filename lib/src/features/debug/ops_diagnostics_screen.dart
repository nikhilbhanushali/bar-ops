import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OpsDiagnosticsScreen extends StatefulWidget {
  const OpsDiagnosticsScreen({super.key});

  @override
  State<OpsDiagnosticsScreen> createState() => _OpsDiagnosticsScreenState();
}

class _OpsDiagnosticsScreenState extends State<OpsDiagnosticsScreen> {
  final _log = <String>[];
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  void _append(String line) {
    setState(() => _log.insert(0, line));
  }

  String _fmtErr(Object e) {
    final type = e.runtimeType.toString();
    var msg = e.toString();
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);

    // Try to read common fields dynamically (works on web/native)
    try { final code = (e as dynamic).code; if (code != null) msg = '$code: $msg'; } catch (_) {}
    try { final message = (e as dynamic).message; if (message != null && message is String && message.isNotEmpty) msg = message; } catch (_) {}

    return '[$type] $msg';
  }

  Future<void> _checkProfile() async {
    _append('Checking users/{uid} …');
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _append('❌ Not signed in');
      return;
    }
    try {
      final snap = await _db.collection('users').doc(uid).get();
      _append(snap.exists
          ? '✅ Profile exists. role=${snap.data()?['role']}, status=${snap.data()?['status']}'
          : '⚠️ Profile missing at users/$uid');
    } catch (e) {
      _append('❌ ${_fmtErr(e)}');
    }
  }

  Future<void> _touchCounters() async {
    _append('Testing write to meta/counters …');
    try {
      await _db.runTransaction((txn) async {
        final ref = _db.collection('meta').doc('counters');
        final snap = await txn.get(ref);
        final current = (snap.data()?['inventoryNext'] as int?) ?? 0;
        txn.set(ref, {'inventoryNext': current + 1, 'diagLast': DateTime.now().toIso8601String()}, SetOptions(merge: true));
      });
      _append('✅ meta/counters write ok');
    } catch (e) {
      _append('❌ ${_fmtErr(e)}');
    }
  }

  Future<void> _touchIndex() async {
    _append('Testing create/delete on inventory_index …');
    final key = 'diag|${_auth.currentUser?.uid ?? ''}|${Random().nextInt(999999)}';
    final ref = _db.collection('inventory_index').doc(key);
    try {
      await ref.set({'createdAt': DateTime.now().toIso8601String(), 'by': _auth.currentUser?.uid ?? ''});
      await ref.delete();
      _append('✅ inventory_index create/delete ok');
    } catch (e) {
      _append('❌ ${_fmtErr(e)}');
    }
  }

  Future<void> _readSubmissions() async {
    _append('Reading inventory_submissions (status=pending) …');
    try {
      final q = await _db.collection('inventory_submissions')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      _append('✅ submissions read ok, count=${q.docs.length}');
    } catch (e) {
      _append('❌ ${_fmtErr(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(onPressed: _checkProfile, child: const Text('Check Profile')),
                FilledButton(onPressed: _touchCounters, child: const Text('Write Counters')),
                FilledButton(onPressed: _touchIndex, child: const Text('Index Create/Delete')),
                FilledButton(onPressed: _readSubmissions, child: const Text('Read Submissions')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(_log[i]),
            ),
          ),
        ],
      ),
    );
  }
}
