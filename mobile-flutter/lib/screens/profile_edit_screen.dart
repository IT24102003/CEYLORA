import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String? _country;
  String? _mobileNumber;
  String? _existingProfilePictureUrl;
  File? _newProfilePicture;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _apiService.getMyProfile();
      _nameController.text = profile["name"] ?? "";
      _ageController.text = profile["age"]?.toString() ?? "";
      _country = profile["country"];
      _mobileNumber = profile["mobileNumber"];
      _existingProfilePictureUrl = profile["profilePictureUrl"];
    } catch (e) {
      setState(() => _error = "Failed to load profile.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
    if (picked != null) {
      setState(() => _newProfilePicture = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Upload new picture first, if one was picked
      if (_newProfilePicture != null) {
        await _apiService.uploadProfilePicture(_newProfilePicture!.path);
      }

      await _apiService.updateMyProfile(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        country: _country,
        mobileNumber: _mobileNumber,
      );

      if (mounted) {
        context.read<AuthProvider>().updateLocalName(_nameController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = "Failed to update profile.");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildProfileImage() {
    if (_newProfilePicture != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: kIsWeb
            ? NetworkImage(_newProfilePicture!.path)
            : FileImage(_newProfilePicture!) as ImageProvider,
      );
    }
    if (_existingProfilePictureUrl != null && _existingProfilePictureUrl!.isNotEmpty) {
      final fullUrl = _existingProfilePictureUrl!.startsWith("http")
          ? _existingProfilePictureUrl!
          : "${ApiService.baseUrl.replaceAll('/api', '')}$_existingProfilePictureUrl";
      return CircleAvatar(radius: 50, backgroundImage: NetworkImage(fullUrl));
    }
    return const CircleAvatar(
      radius: 50,
      child: Icon(Icons.person, size: 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  _buildProfileImage(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickProfilePicture,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            IntlPhoneField(
              initialCountryCode: 'LK',
              initialValue: _mobileNumber,
              decoration: const InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
              ),
              onChanged: (phone) {
                _mobileNumber = phone.completeNumber;
              },
              onCountryChanged: (country) {
                _country = country.name;
              },
            ),
            const SizedBox(height: 20),

            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}