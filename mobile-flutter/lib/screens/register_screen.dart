import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _role = 0; // 0 = Tourist, 1 = Guide
  String? _error;

  Future<void> _handleRegister() async {
    setState(() => _error = null);
    try {
      await context.read<AuthProvider>().register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
            _role,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = "Registration failed. Try a different email.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "I am a..."),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Tourist")),
                DropdownMenuItem(value: 1, child: Text("Guide / Vehicle Owner")),
              ],
              onChanged: (val) => setState(() => _role = val!),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleRegister,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}