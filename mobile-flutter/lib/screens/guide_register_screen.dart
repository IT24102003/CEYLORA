import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/registration_widgets.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';

class GuideRegisterScreen extends StatefulWidget {
  const GuideRegisterScreen({super.key});

  @override
  State<GuideRegisterScreen> createState() => _GuideRegisterScreenState();
}

class _GuideRegisterScreenState extends State<GuideRegisterScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _regionController = TextEditingController();
  final _nicController = TextEditingController();
  final _languagesController = TextEditingController();

  String? _mobileNumber;
  String _country =
      "Sri Lanka"; // taken from the phone field's selected country code

  Uint8List? _tourismIdPhotoBytes;
  String? _tourismIdPhotoName;
  bool _isSubmitting = false;
  String? _error;
  String? _phoneError;
  String? _photoError;

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _ageController,
      _regionController,
      _nicController,
      _languagesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTourismIdPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _tourismIdPhotoBytes = bytes;
        _tourismIdPhotoName = picked.name;
        _photoError = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _phoneError = (_mobileNumber ?? "").trim().isEmpty
          ? "Enter your mobile number."
          : null;
      _photoError = _tourismIdPhotoBytes == null
          ? "Please upload a photo of your Tourism ID."
          : null;
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _phoneError != null || _photoError != null) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

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
        tourismIdPhoto: UploadFile(
          _tourismIdPhotoBytes!,
          _tourismIdPhotoName ?? "tourism_id.jpg",
        ),
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
      appBar: AppBar(title: const Text("Become a guide")),
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
                  "After you submit, an admin reviews your Tourism ID before your profile goes live to tourists.",
                  tone: Tone.info,
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader("About you"),
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
                        hint: "e.g. Kandy",
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
                AppTextField(
                  label: "Languages",
                  controller: _languagesController,
                  hint: "e.g. English, Sinhala",
                  helper: "Optional — comma separated.",
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader("Verification"),
                const SizedBox(height: Space.md),
                PhotoUploadTile(
                  title: "Tourism ID photo",
                  hint: "A clear photo of your tourism board ID.",
                  buttonLabel: _tourismIdPhotoBytes == null
                      ? "Upload photo"
                      : "Change photo",
                  photos: [
                    ?_tourismIdPhotoBytes,
                  ],
                  error: _photoError,
                  onPick: _pickTourismIdPhoto,
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
