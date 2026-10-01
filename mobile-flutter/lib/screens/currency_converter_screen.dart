import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/ui/ui.dart';

// Simple currency converter — available to Tourist, Guide and Vehicle Owner accounts
// (opened from Home). Base currency is LKR since every price in the app (bookings,
// earnings, per-km rates) is stored/shown in LKR.
class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

// A short, practical list rather than every ISO currency — covers the tourist's likely
// home currencies plus LKR itself.
const _kCurrencies = [
  "USD",
  "EUR",
  "GBP",
  "AUD",
  "CAD",
  "JPY",
  "CNY",
  "INR",
  "SGD",
  "AED",
  "CHF",
  "NZD",
  "KRW",
  "THB",
  "MYR",
  "LKR",
];

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final ApiService _apiService = ApiService();
  final _amountController = TextEditingController(text: "1000");

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _rates; // 1 LKR = _rates[code]

  String _fromCurrency = "LKR";
  String _toCurrency = "USD";

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rates = await _apiService.getExchangeRates(base: "LKR");
      if (!mounted) return;
      setState(() => _rates = rates);
    } catch (e) {
      if (mounted) setState(() => _error = "We couldn't load exchange rates.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? get _convertedAmount {
    if (_rates == null) return null;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return null;

    // _rates is "1 LKR = X <code>". To convert FROM any currency, first turn the input
    // into LKR, then from LKR into the target currency.
    final fromRate = _fromCurrency == "LKR"
        ? 1.0
        : (_rates![_fromCurrency] as num?)?.toDouble();
    final toRate = _toCurrency == "LKR"
        ? 1.0
        : (_rates![_toCurrency] as num?)?.toDouble();
    if (fromRate == null || toRate == null || fromRate == 0) return null;

    final amountInLkr = amount / fromRate;
    return amountInLkr * toRate;
  }

  void _swap() {
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
  }

  Widget _currencyPicker(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: context.text.labelMedium!.copyWith(
              fontSize: 13.5,
              color: context.scheme.onSurface,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(),
          borderRadius: BorderRadius.circular(Radii.md),
          items: _kCurrencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final converted = _convertedAmount;
    return Scaffold(
      appBar: AppBar(title: const Text("Currency converter")),
      body: RefreshIndicator(
        onRefresh: _loadRates,
        child: StateView(
          loading: _isLoading,
          error: _rates == null ? _error : null,
          onRetry: _loadRates,
          skeleton: const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: Skeleton(height: 220, radius: Radii.lg),
          ),
          child: ListView(
            padding: const EdgeInsets.all(Space.xl),
            children: [
              AppTextField(
                label: "Amount",
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.payments_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _currencyPicker(
                      "From",
                      _fromCurrency,
                      (v) => setState(() => _fromCurrency = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      tooltip: "Swap currencies",
                      onPressed: _swap,
                    ),
                  ),
                  Expanded(
                    child: _currencyPicker(
                      "To",
                      _toCurrency,
                      (v) => setState(() => _toCurrency = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxl),
              AnimatedSwitcher(
                duration: Motion.base,
                child: converted == null
                    ? const SizedBox.shrink()
                    : AppCard(
                        key: ValueKey("$_fromCurrency$_toCurrency"),
                        color: context.palette.primarySoft,
                        padding: const EdgeInsets.all(Space.xxl),
                        child: Column(
                          children: [
                            Text(
                              "${_amountController.text} $_fromCurrency",
                              style: context.text.bodyLarge!.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Icon(
                              Icons.south_rounded,
                              color: context.scheme.primary,
                            ),
                            const SizedBox(height: Space.xs),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                "${converted.toStringAsFixed(2)} $_toCurrency",
                                style: context.text.headlineMedium!.copyWith(
                                  color: context.scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: Space.lg),
              if (_rates != null)
                Text(
                  "Rates refresh about every 30 minutes · Base: LKR",
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
