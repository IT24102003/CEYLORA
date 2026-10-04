import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../providers/auth_provider.dart';
import '../widgets/ui/ui.dart';
import 'guide_register_screen.dart';
import 'vehicle_owner_register_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  static const int _role =
      0; // this form is Tourist-only; Guide/VehicleOwner have their own forms
  String? _error;
  String? _phoneError;

  String _country = "Sri Lanka"; // matches initialCountryCode: 'LK' below — only changes if user picks a different country
  String _mobileNumber = "";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _error = null;
      _phoneError = null;
    });

    final formOk = _formKey.currentState!.validate();
    if (_mobileNumber.isEmpty || _country.isEmpty) {
      setState(() => _phoneError = "Please enter your mobile number.");
      return;
    }
    if (!formOk) return;

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
      if (mounted) {
        setState(
          () => _error = "Registration failed. Try a different email address.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Start your journey",
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          "Create a traveller account to plan and book tours.",
                          style: context.text.bodyLarge!.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.xxl),
                        AppTextField(
                          label: "Full name",
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? "Enter your full name."
                              : null,
                        ),
                        const SizedBox(height: Space.lg),
                        AppTextField(
                          label: "Email",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          prefixIcon: Icons.mail_outline_rounded,
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
                          autofillHints: const [AutofillHints.newPassword],
                          prefixIcon: Icons.lock_outline_rounded,
                          helper: "Use at least 6 characters.",
                          validator: (v) => (v == null || v.length < 6)
                              ? "Password must be at least 6 characters."
                              : null,
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
                        // Country select + auto dial code applied to phone field
                        IntlPhoneField(
                          decoration: InputDecoration(
                            errorText: _phoneError,
                            counterText: "",
                          ),
                          flagsButtonPadding: const EdgeInsets.only(
                            left: Space.sm,
                          ),
                          dropdownIconPosition: IconPosition.trailing,
                          dropdownIcon: const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                          ),
                          initialCountryCode: 'LK', // Sri Lanka default
                          disableLengthCheck: true,
                          onChanged: (phone) {
                            _mobileNumber = phone.completeNumber; // includes dial code, e.g. +94771234567
                            if (_phoneError != null) {
                              setState(() => _phoneError = null);
                            }
                          },
                          onCountryChanged: (country) {
                            _country = country.name; // e.g. "Sri Lanka"
                          },
                        ),
                        AnimatedSize(
                          duration: Motion.base,
                          curve: Motion.out,
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: Space.lg),
                                  child: InlineAlert(_error!),
                                ),
                        ),
                        const SizedBox(height: Space.xxl),
                        AppButton(
                          label: "Create tourist account",
                          loading: isLoading,
                          onPressed: _handleRegister,
                        ),
                        const SizedBox(height: Space.xxxl),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.md,
                              ),
                              child: Text(
                                "Want to work with tourists?",
                                style: context.text.bodySmall,
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        _RoleCard(
                          icon: Icons.hiking_rounded,
                          title: "Become a guide",
                          subtitle: "Lead tours and share your region.",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GuideRegisterScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        _RoleCard(
                          icon: Icons.directions_car_rounded,
                          title: "Register a vehicle",
                          subtitle: "List your vehicle for tourist tours.",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const VehicleOwnerRegisterScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTile(icon, tone: Tone.accent),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(
                  subtitle,
                  style: context.text.bodyMedium!.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.palette.textTertiary,
          ),
        ],
      ),
    );
  }
}
