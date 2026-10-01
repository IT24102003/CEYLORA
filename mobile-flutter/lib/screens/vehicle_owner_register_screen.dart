import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/registration_widgets.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';

class VehicleOwnerRegisterScreen extends StatefulWidget {
  const VehicleOwnerRegisterScreen({super.key});

  @override
  State<VehicleOwnerRegisterScreen> createState() =>
      _VehicleOwnerRegisterScreenState();
}

class _VehicleOwnerRegisterScreenState
    extends State<VehicleOwnerRegisterScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

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
  String _country =
      "Sri Lanka"; // taken from the phone field's selected country code

  Uint8List? _licensePhotoBytes;
  String? _licensePhotoName;
  final List<UploadFile> _vehiclePhotos = [];
  bool _isSubmitting = false;
  String? _error;
  String? _phoneError;
  String? _licenseError;
  String? _vehiclePhotosError;

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _ageController,
      _regionController,
      _nicController,
      _vehicleNameController,
      _yearController,
      _seatsController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLicensePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _licensePhotoBytes = bytes;
        _licensePhotoName = picked.name;
        _licenseError = null;
      });
    }
  }

  Future<void> _pickVehiclePhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked.isNotEmpty) {
      final uploads = <UploadFile>[];
      for (final x in picked) {
        uploads.add(UploadFile(await x.readAsBytes(), x.name));
      }
      if (!mounted) return;
      setState(() {
        _vehiclePhotos.addAll(uploads);
        _vehiclePhotosError = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _phoneError = (_mobileNumber ?? "").trim().isEmpty
          ? "Enter your mobile number."
          : null;
      _licenseError = _licensePhotoBytes == null
          ? "Please upload a photo of your driving license."
          : null;
      _vehiclePhotosError = _vehiclePhotos.isEmpty
          ? "Please upload at least one photo of your vehicle."
          : null;
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk ||
        _phoneError != null ||
        _licenseError != null ||
        _vehiclePhotosError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

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
        drivingLicensePhoto: UploadFile(
          _licensePhotoBytes!,
          _licensePhotoName ?? "license.jpg",
        ),
        vehicleType: _vehicleType,
        vehicleName: _vehicleNameController.text.trim(),
        manufacturerYear: int.tryParse(_yearController.text.trim()) ?? 0,
        numberOfSeats: int.tryParse(_seatsController.text.trim()) ?? 0,
        vehiclePhotos: _vehiclePhotos,
      );
      await auth.setSessionFromAuthResult(result);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              "Registration failed: ${e.toString().replaceFirst('Exception: ', '')}",
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register a vehicle")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InlineAlert(
                  "An admin reviews your license and vehicle photos before your listing goes live to tourists.",
                  tone: Tone.info,
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader("Personal details"),
                const SizedBox(height: Space.md),
                AppTextField(
                  label: "Full name",
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => requiredField(v, "Enter your full name."),
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "Email",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains("@"))
                      ? "Enter a valid email address."
                      : null,
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "Password",
                  controller: _passwordController,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  helper: "Use at least 6 characters.",
                  validator: (v) => (v == null || v.length < 6)
                      ? "Password must be at least 6 characters."
                      : null,
                ),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Age",
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => requiredField(v, "Required."),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        label: "Region",
                        controller: _regionController,
                        textInputAction: TextInputAction.next,
                        hint: "e.g. Colombo",
                        validator: (v) =>
                            requiredField(v, "Enter your region."),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "NIC number",
                  controller: _nicController,
                  textInputAction: TextInputAction.next,
                  validator: (v) => requiredField(v, "Enter your NIC number."),
                ),
                const SizedBox(height: Space.lg),
                PhoneField(
                  errorText: _phoneError,
                  onChanged: (v) {
                    _mobileNumber = v;
                    if (_phoneError != null) setState(() => _phoneError = null);
                  },
                  onCountryChanged: (c) => setState(() => _country = c),
                ),
                const SizedBox(height: Space.lg),
                PhotoUploadTile(
                  title: "Driving license photo",
                  hint: "Front of your valid driving license.",
                  buttonLabel: _licensePhotoBytes == null
                      ? "Upload photo"
                      : "Change photo",
                  photos: [?_licensePhotoBytes],
                  error: _licenseError,
                  onPick: _pickLicensePhoto,
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader("Vehicle details"),
                const SizedBox(height: Space.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "Vehicle type",
                    style: context.text.labelMedium!.copyWith(
                      fontSize: 13.5,
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  borderRadius: BorderRadius.circular(Radii.md),
                  items: const [
                    DropdownMenuItem(value: "Car", child: Text("Car")),
                    DropdownMenuItem(value: "Van", child: Text("Van")),
                    DropdownMenuItem(value: "Bus", child: Text("Bus")),
                  ],
                  onChanged: (val) =>
                      setState(() => _vehicleType = val ?? "Car"),
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "Vehicle name / model",
                  controller: _vehicleNameController,
                  textInputAction: TextInputAction.next,
                  hint: "e.g. Toyota KDH",
                  validator: (v) => requiredField(v, "Enter the vehicle name."),
                ),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Manufacture year",
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => requiredField(v, "Required."),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppTextField(
                        label: "Seats",
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        validator: (v) => requiredField(v, "Required."),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                PhotoUploadTile(
                  title: "Vehicle photos",
                  hint: "Add at least one clear photo.",
                  buttonLabel: _vehiclePhotos.isEmpty
                      ? "Add photos"
                      : "Add more photos",
                  icon: Icons.photo_library_rounded,
                  photos: [for (final p in _vehiclePhotos) p.bytes],
                  error: _vehiclePhotosError,
                  onPick: _pickVehiclePhotos,
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  InlineAlert(_error!),
                ],
                const SizedBox(height: Space.xxl),
                AppButton(
                  label: "Submit application",
                  loading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
