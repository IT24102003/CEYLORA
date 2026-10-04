/// Payment screen
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';
import 'review_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isPaying = false;
  bool _paid = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _isPaying = true;
      _error = null;
    });
    try {
      await _apiService.createPayment(
        bookingId: widget.booking["id"],
        amount: (widget.booking["totalPrice"] as num).toDouble(),
      );
      if (mounted) setState(() => _paid = true);
    } catch (e) {
      if (mounted) setState(() => _error = "Payment failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_paid ? "Payment" : "Pay for booking"),
        automaticallyImplyLeading: !_paid,
      ),
      body: AnimatedSwitcher(
        duration: Motion.slow,
        switchInCurve: Motion.out,
        child: _paid ? _buildSuccess() : _buildPaymentForm(),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(Space.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: context.palette.primarySoft,
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Booking #${widget.booking["id"]}",
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Space.xs),
                Text("Amount due", style: context.text.bodySmall),
                Text(
                  "LKR ${widget.booking["totalPrice"]}",
                  style: context.text.headlineMedium!.copyWith(
                    color: context.scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xxl),
          Row(
            children: [
              Expanded(
                child: Text("Card details", style: context.text.titleMedium),
              ),
              const StatusBadge(
                "Sandbox",
                tone: Tone.warning,
                icon: Icons.science_outlined,
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            "This is a test payment — no real money is charged.",
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          const AppTextField(
            label: "Card number",
            hint: "4242 4242 4242 4242",
            keyboardType: TextInputType.number,
            prefixIcon: Icons.credit_card_rounded,
            autofillHints: [AutofillHints.creditCardNumber],
          ),
          const SizedBox(height: Space.lg),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: "Expiry",
                  hint: "12/28",
                  keyboardType: TextInputType.datetime,
                  autofillHints: [AutofillHints.creditCardExpirationDate],
                ),
              ),
              SizedBox(width: Space.md),
              Expanded(
                child: AppTextField(
                  label: "CVV",
                  hint: "123",
                  keyboardType: TextInputType.number,
                  obscure: true,
                  autofillHints: [AutofillHints.creditCardSecurityCode],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.lg),
            InlineAlert(_error!),
          ],
          const SizedBox(height: Space.xxl),
          AppButton(
            label: "Pay LKR ${widget.booking["totalPrice"]}",
            icon: Icons.lock_rounded,
            loading: _isPaying,
            onPressed: _pay,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      key: const ValueKey('success'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: Motion.slow,
              curve: Motion.spring,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const IconTile(
                Icons.check_rounded,
                tone: Tone.success,
                size: 96,
              ),
            ),
            const SizedBox(height: Space.xl),
            Text("Payment successful", style: context.text.headlineSmall),
            const SizedBox(height: Space.sm),
            Text(
              "We've received your payment for booking #${widget.booking["id"]}.",
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            ),
            const SizedBox(height: Space.sm),
            Text(
              "If this trip hasn't been confirmed yet, our team will assign a guide and vehicle shortly.",
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: Space.xxl),
            AppButton(
              label: "Back to home",
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
            ),
            const SizedBox(height: Space.sm),
            AppButton(
              label: "Leave a review",
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(bookingId: widget.booking["id"]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
