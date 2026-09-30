import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Simple currency converter — available to Tourist, Guide and Vehicle Owner accounts
// (opened from their respective home/dashboard screens). Base currency is LKR since
// every price in the app (bookings, earnings, per-km rates) is stored/shown in LKR.
class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

// A short, practical list rather than every ISO currency — covers the tourist's likely
// home currencies plus LKR itself.
const _kCurrencies = [
  "USD", "EUR", "GBP", "AUD", "CAD", "JPY", "CNY", "INR",
  "SGD", "AED", "CHF", "NZD", "KRW", "THB", "MYR", "LKR",
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
      if (mounted) setState(() => _error = "Couldn't load exchange rates. Pull down to retry.");
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
    final fromRate = _fromCurrency == "LKR" ? 1.0 : (_rates![_fromCurrency] as num?)?.toDouble();
    final toRate = _toCurrency == "LKR" ? 1.0 : (_rates![_toCurrency] as num?)?.toDouble();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Currency Converter")),
      body: RefreshIndicator(
        onRefresh: _loadRates,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _fromCurrency,
                          decoration: const InputDecoration(labelText: "From", border: OutlineInputBorder()),
                          items: _kCurrencies
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _fromCurrency = v ?? _fromCurrency),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        tooltip: "Swap",
                        onPressed: _swap,
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _toCurrency,
                          decoration: const InputDecoration(labelText: "To", border: OutlineInputBorder()),
                          items: _kCurrencies
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _toCurrency = v ?? _toCurrency),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_convertedAmount != null)
                    Card(
                      color: Colors.teal.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              "${_amountController.text} $_fromCurrency",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const Icon(Icons.arrow_downward, color: Colors.teal, size: 20),
                            Text(
                              "${_convertedAmount!.toStringAsFixed(2)} $_toCurrency",
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_rates != null)
                    Text(
                      "Rates update roughly every 30 min • Base: LKR",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
      ),
    );
  }
}
