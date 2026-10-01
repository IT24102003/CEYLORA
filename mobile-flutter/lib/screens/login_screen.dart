import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/scenic/scenic.dart';
import '../widgets/ui/ui.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<AuthProvider>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Login failed. Check your email and password.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final p = context.palette;

    return Scaffold(
      body: Stack(
        children: [
          const ScenicBackground(reach: 1, scrim: true),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xl),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeInUp(child: const LogoBadge(height: 120)),
                          const SizedBox(height: Space.lg),
                          FadeInUp(
                            index: 1,
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Welcome back",
                                    style: context.text.headlineSmall!.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: Space.xs),
                                  Text(
                                    "Sign in to your account.",
                                    style: context.text.bodyMedium!.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: Space.xl),
                                  AppTextField(
                                    label: "Email",
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    prefixIcon: Icons.mail_outline_rounded,
                                    hint: "you@example.com",
                                    validator: (v) =>
                                        (v == null || !v.contains("@"))
                                        ? "Enter a valid email address."
                                        : null,
                                  ),
                                  const SizedBox(height: Space.lg),
                                  AppTextField(
                                    label: "Password",
                                    controller: _passwordController,
                                    obscure: true,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    prefixIcon: Icons.lock_outline_rounded,
                                    onSubmitted: (_) => _handleLogin(),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? "Enter your password."
                                        : null,
                                  ),
                                  AnimatedSize(
                                    duration: Motion.base,
                                    curve: Motion.out,
                                    child: _error == null
                                        ? const SizedBox(width: double.infinity)
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              top: Space.lg,
                                            ),
                                            child: InlineAlert(_error!),
                                          ),
                                  ),
                                  const SizedBox(height: Space.xl),
                                  AppButton(
                                    label: "Sign in",
                                    loading: isLoading,
                                    onPressed: _handleLogin,
                                  ),
                                  const SizedBox(height: Space.sm),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "New to Ceylora?",
                                        style: context.text.bodyMedium!
                                            .copyWith(color: p.textSecondary),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        ),
                                        child: const Text("Create an account"),
                                      ),
                                    ],
                                  ),
                                ],
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
        ],
      ),
    );
  }
}
