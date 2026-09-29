import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
  int _role = 0;
  String? _error;

  String _country = "";
  String _mobileNumber = "";

  Future<void> _handleRegister() async {
    setState(() => _error = null);

    if (_mobileNumber.isEmpty || _country.isEmpty) {
      setState(() => _error = "Please enter your mobile number.");
      return;
    }

    try {
      await context.read<AuthProvider>().register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
            _role,
            _country,
            _mobileNumber,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

            // Country select + auto dial code applied to phone field
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'LK', // Sri Lanka default
              onChanged: (phone) {
                _mobileNumber = phone.completeNumber; // includes dial code, e.g. +94771234567
              },
              onCountryChanged: (country) {
                _country = country.name; // e.g. "Sri Lanka"
              },
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
            ElevatedButton(
              onPressed: isLoading ? null : _handleRegister,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}