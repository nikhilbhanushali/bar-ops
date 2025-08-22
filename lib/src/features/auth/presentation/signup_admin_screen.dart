// SignupAdminScreen for BarOps: one-time admin signup with setup code
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

const String kSetupCode = 'BAROPS-SETUP-2024'; // Change as needed

class SignupAdminScreen extends ConsumerStatefulWidget {
  const SignupAdminScreen({super.key});

  @override
  ConsumerState<SignupAdminScreen> createState() => _SignupAdminScreenState();
}

class _SignupAdminScreenState extends ConsumerState<SignupAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _setupCodeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _setupCodeController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final repo = ref.read(authRepositoryProvider);
    final error = await repo.signupAdmin(
      displayName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      setupCode: _setupCodeController.text.trim(),
      expectedSetupCode: kSetupCode,
    );
    if (error != null) {
      setState(() { _error = error; _loading = false; });
    } else {
      if (mounted) {
        Navigator.of(context).pop(); // Return to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin account created!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Signup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Name required.' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
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
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required.';
                    if (v.length < 6) return 'Password must be at least 6 characters.';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _setupCodeController,
                  decoration: const InputDecoration(labelText: 'Setup Code'),
                  validator: (v) => v == null || v.isEmpty ? 'Setup code required.' : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signup(),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: const Text('Create Admin Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

