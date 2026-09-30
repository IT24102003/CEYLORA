import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class VehicleOwnerRegisterScreen extends StatefulWidget {
  const VehicleOwnerRegisterScreen({super.key});

  @override
  State<VehicleOwnerRegisterScreen> createState() => _VehicleOwnerRegisterScreenState();
}

class _VehicleOwnerRegisterScreenState extends State<VehicleOwnerRegisterScreen> {
  final ApiService _apiService = ApiService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _regionController = TextEditingController();
  final _nicController = TextEditingController();

  final _vehicleNameController = TextEditingController();
  final _yearController = TextEditingController();
  final _seatsController = TextEditingController();
  String _vehicleType = "Car";

  String? _mobileNumber;
  String _country = "Sri Lanka"; // taken from the phone field's selected country code

  Uint8List? _licensePhotoBytes;
  String? _licensePhotoName;
  final List<UploadFile> _vehiclePhotos = [];
  bool _isSubmitting = false;
  String? _error;

  Future<void> _pickLicensePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _licensePhotoBytes = bytes;
        _licensePhotoName = picked.name;
      });
    }
  }

  Future<void> _pickVehiclePhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1200);
    if (picked.isNotEmpty) {
      final uploads = <UploadFile>[];
      for (final x in picked) {
        uploads.add(UploadFile(await x.readAsBytes(), x.name));
      }
      setState(() => _vehiclePhotos.addAll(uploads));
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
        _mobileNumber!.trim().isEmpty ||
        _vehicleNameController.text.trim().isEmpty ||
        _yearController.text.trim().isEmpty ||
        _seatsController.text.trim().isEmpty) {
      setState(() => _error = "Please fill in all required fields.");
      return;
    }
    if (_licensePhotoBytes == null) {
      setState(() => _error = "Please upload a photo of your driving license.");
      return;
    }
    if (_vehiclePhotos.isEmpty) {
      setState(() => _error = "Please upload at least one photo of your vehicle.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _apiService.registerVehicleOwner(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        region: _regionController.text.trim(),
        nicNumber: _nicController.text.trim(),
        mobileNumber: _mobileNumber!.trim(),
        country: _country,
        drivingLicensePhoto: UploadFile(_licensePhotoBytes!, _licensePhotoName ?? "license.jpg"),
        vehicleType: _vehicleType,
        vehicleName: _vehicleNameController.text.trim(),
        manufacturerYear: int.tryParse(_yearController.text.trim()) ?? 0,
        numberOfSeats: int.tryParse(_seatsController.text.trim()) ?? 0,
        vehiclePhotos: _vehiclePhotos,
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
      appBar: AppBar(title: const Text("Register as a Vehicle Owner")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Fill in your details and your vehicle's details below. An Admin will review "
              "your license and vehicle photos before your listing goes live to tourists.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            const Text("Driving License Photo", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_licensePhotoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_licensePhotoBytes!, height: 140, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(_licensePhotoBytes == null ? "Upload License Photo" : "Change Photo"),
              onPressed: _pickLicensePhoto,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Vehicle Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: const InputDecoration(labelText: "Vehicle Type"),
              items: const [
                DropdownMenuItem(value: "Car", child: Text("Car")),
                DropdownMenuItem(value: "Van", child: Text("Van")),
                DropdownMenuItem(value: "Bus", child: Text("Bus")),
              ],
              onChanged: (val) => setState(() => _vehicleType = val ?? "Car"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleNameController,
              decoration: const InputDecoration(labelText: "Vehicle Name / Model", hintText: "e.g. Toyota KDH"),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    decoration: const InputDecoration(labelText: "Manufacture Year"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _seatsController,
                    decoration: const InputDecoration(labelText: "Number of Seats"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text("Vehicle Photos", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_vehiclePhotos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _vehiclePhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_vehiclePhotos[i].bytes, width: 90, height: 90, fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text("Add Vehicle Photos"),
              onPressed: _pickVehiclePhotos,
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
