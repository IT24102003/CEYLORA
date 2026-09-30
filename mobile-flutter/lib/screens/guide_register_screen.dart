import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class GuideRegisterScreen extends StatefulWidget {
  const GuideRegisterScreen({super.key});

  @override
  State<GuideRegisterScreen> createState() => _GuideRegisterScreenState();
}

class _GuideRegisterScreenState extends State<GuideRegisterScreen> {
  final ApiService _apiService = ApiService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _regionController = TextEditingController();
  final _nicController = TextEditingController();
  final _languagesController = TextEditingController();

  String? _mobileNumber;
  String _country = "Sri Lanka"; // taken from the phone field's selected country code

  Uint8List? _tourismIdPhotoBytes;
  String? _tourismIdPhotoName;
  bool _isSubmitting = false;
  String? _error;

  Future<void> _pickTourismIdPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _tourismIdPhotoBytes = bytes;
        _tourismIdPhotoName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _ageController.text.trim().isEmpty ||
        _regionController.text.trim().isEmpty ||
        _nicController.text.trim().isEmpty ||
        _mobileNumber == null ||
        _mobileNumber!.trim().isEmpty) {
      setState(() => _error = "Please fill in all required fields.");
      return;
    }
    if (_tourismIdPhotoBytes == null) {
      setState(() => _error = "Please upload a photo of your Tourism ID.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _apiService.registerGuide(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        region: _regionController.text.trim(),
        nicNumber: _nicController.text.trim(),
        mobileNumber: _mobileNumber!.trim(),
        country: _country,
        languages: _languagesController.text.trim(),
        tourismIdPhoto: UploadFile(_tourismIdPhotoBytes!, _tourismIdPhotoName ?? "tourism_id.jpg"),
      );
      if (mounted) {
        await context.read<AuthProvider>().setSessionFromAuthResult(result);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Show the real error (temporarily) instead of a generic guess, so it's clear what failed.
      setState(() => _error = "Registration failed: ${e.toString().replaceFirst('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register as a Guide")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Fill in your details below. After you submit, an Admin will review your "
              "Tourism ID before your profile goes live to tourists.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name")),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: "Age"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(controller: _regionController, decoration: const InputDecoration(labelText: "Region")),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _nicController, decoration: const InputDecoration(labelText: "NIC Number")),
            const SizedBox(height: 12),
            IntlPhoneField(
              initialCountryCode: 'LK',
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
              flagsButtonPadding: const EdgeInsets.only(left: 6),
              dropdownIconPosition: IconPosition.trailing,
              dropdownIcon: const Icon(Icons.arrow_drop_down, size: 20),
              onChanged: (phone) => _mobileNumber = phone.completeNumber,
              onCountryChanged: (country) => setState(() => _country = country.name),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _languagesController,
              decoration: const InputDecoration(labelText: "Languages (optional)", hintText: "e.g. English, Sinhala"),
            ),
            const SizedBox(height: 16),
            const Text("Tourism ID Photo", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_tourismIdPhotoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_tourismIdPhotoBytes!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(_tourismIdPhotoBytes == null ? "Upload Tourism ID Photo" : "Change Photo"),
              onPressed: _pickTourismIdPhoto,
            ),
            const SizedBox(height: 20),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Submit Application"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
