// ForgotPasswordDialog for BarOps: email input, sends reset link, shows result
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  ConsumerState<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _success = null; });
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.sendPasswordResetEmail(_emailController.text.trim());
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      setState(() { _success = 'Reset link sent! Check your email.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email required.';
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
                if (!emailRegex.hasMatch(v)) return 'Invalid email.';
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendReset(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_success!, style: const TextStyle(color: Colors.green)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _sendReset,
          child: const Text('Send Reset Link'),
        ),
      ],
    );
  }
}

