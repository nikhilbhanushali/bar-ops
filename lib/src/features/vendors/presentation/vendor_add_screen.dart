import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vendor_providers.dart';

class VendorAddScreen extends ConsumerStatefulWidget {
  const VendorAddScreen({super.key});

  @override
  ConsumerState<VendorAddScreen> createState() => _VendorAddScreenState();
}

class _VendorAddScreenState extends ConsumerState<VendorAddScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gst = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name..dispose();
    _gst..dispose();
    _address..dispose();
    _contact..dispose();
    _phone..dispose();
    _email..dispose();
    _notes..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(vendorRepoProvider).createVendor(
        name: _name.text,
        gstDetail: _gst.text,
        address: _address.text,
        contactPerson: _contact.text,
        phone: _phone.text,
        email: _email.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendor added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    const sp = 12.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vendor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
                validator: _req,
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _gst,
                decoration: const InputDecoration(labelText: 'GST Detail / GSTIN'),
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: sp),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const CircularProgressIndicator() : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
