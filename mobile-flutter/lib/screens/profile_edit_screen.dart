import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/ui/ui.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String? _country;
  String? _mobileNumber;
  String? _existingProfilePictureUrl;
  Uint8List? _newProfilePictureBytes;
  String? _newProfilePictureName;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final profile = await _apiService.getMyProfile();
      _nameController.text = profile["name"] ?? "";
      _ageController.text = profile["age"]?.toString() ?? "";
      _country = profile["country"];
      _mobileNumber = profile["mobileNumber"];
      _existingProfilePictureUrl = profile["profilePictureUrl"];
    } catch (e) {
      _loadError = "We couldn't load your profile.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final source = await pickPhotoSource(context, title: "Profile photo");
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newProfilePictureBytes = bytes;
        _newProfilePictureName = picked.name;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Upload new picture first, if one was picked
      if (_newProfilePictureBytes != null) {
        await _apiService.uploadProfilePicture(
          UploadFile(
            _newProfilePictureBytes!,
            _newProfilePictureName ?? "profile.jpg",
          ),
        );
      }

      await _apiService.updateMyProfile(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        country: _country,
        mobileNumber: _mobileNumber,
      );

      if (mounted) {
        context.read<AuthProvider>().updateLocalName(
          _nameController.text.trim(),
        );
        showToast(context, "Profile updated.", tone: Tone.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = "We couldn't update your profile. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildProfileImage() {
    ImageProvider? image;
    if (_newProfilePictureBytes != null) {
      image = MemoryImage(_newProfilePictureBytes!);
    } else if (_existingProfilePictureUrl != null &&
        _existingProfilePictureUrl!.isNotEmpty) {
      final fullUrl = _existingProfilePictureUrl!.startsWith("http")
          ? _existingProfilePictureUrl!
          : "${ApiService.baseUrl.replaceAll('/api', '')}$_existingProfilePictureUrl";
      image = NetworkImage(fullUrl);
    }
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.primarySoft,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? Icon(Icons.person_rounded, size: 52, color: context.scheme.primary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit profile")),
      body: StateView(
        loading: _isLoading,
        error: _loadError,
        onRetry: _loadProfile,
        skeleton: const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Skeleton(height: 240, radius: Radii.lg),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
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
                        child: Material(
                          color: context.scheme.primary,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.white, width: 3),
                          ),
                          child: IconButton(
                            tooltip: "Change profile photo",
                            icon: Icon(
                              Icons.photo_camera_rounded,
                              color: context.scheme.onPrimary,
                              size: 18,
                            ),
                            onPressed: _pickProfilePicture,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xxl),
                AppTextField(
                  label: "Full name",
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Enter your name."
                      : null,
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "Age",
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    return (n == null || n < 16 || n > 120)
                        ? "Enter a valid age."
                        : null;
                  },
                ),
                const SizedBox(height: Space.lg),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "Mobile number",
                    style: context.text.labelMedium!.copyWith(
                      fontSize: 13.5,
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
                IntlPhoneField(
                  initialCountryCode: 'LK',
                  initialValue: _mobileNumber,
                  disableLengthCheck: true,
                  decoration: const InputDecoration(counterText: ""),
                  flagsButtonPadding: const EdgeInsets.only(left: Space.sm),
                  dropdownIconPosition: IconPosition.trailing,
                  dropdownIcon: const Icon(Icons.arrow_drop_down, size: 20),
                  onChanged: (phone) => _mobileNumber = phone.completeNumber,
                  onCountryChanged: (country) => _country = country.name,
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  InlineAlert(_error!),
                ],
                const SizedBox(height: Space.xxl),
                AppButton(
                  label: "Save changes",
                  loading: _isSaving,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
