import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/registration_widgets.dart';
import '../widgets/ui/ui.dart';

/// Lets a Vehicle Owner edit one of their own vehicles — reached from the Profile tab.
/// Type and price-per-km are shown read-only: they drive the fixed per-type business
/// pricing, so only an Admin can change them. Availability has its own switch on the
/// Dashboard tab, so it isn't duplicated here.
class VehicleEditScreen extends StatefulWidget {
  const VehicleEditScreen({super.key, required this.vehicle});
  final Map<String, dynamic> vehicle;

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: (widget.vehicle["name"] ?? "").toString(),
  );
  late final _regionController = TextEditingController(
    text: (widget.vehicle["region"] ?? "").toString(),
  );
  late final _yearController = TextEditingController(
    text: widget.vehicle["manufacturerYear"] == null
        ? ""
        : "${widget.vehicle["manufacturerYear"]}",
  );
  late final _seatsController = TextEditingController(
    text: "${widget.vehicle["capacity"] ?? ""}",
  );

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _apiService.updateVehicleDetails(
        vehicleId: widget.vehicle["id"] as int,
        name: _nameController.text.trim(),
        manufacturerYear: int.tryParse(_yearController.text.trim()),
        capacity: int.tryParse(_seatsController.text.trim()) ?? 0,
        region: _regionController.text.trim(),
      );
      if (mounted) {
        showToast(context, "Vehicle details updated.", tone: Tone.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst("Exception: ", ""),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (widget.vehicle["type"] ?? "").toString();
    final pricePerKm = widget.vehicle["pricePerKm"];

    return Scaffold(
      appBar: AppBar(title: const Text("Edit vehicle")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InlineAlert(
                  "Vehicle type and per-km rate are set by the admin and can't be "
                  "changed here.",
                  tone: Tone.info,
                ),
                const SizedBox(height: Space.xl),
                AppCard(
                  child: Row(
                    children: [
                      const IconTile(Icons.directions_car_rounded, size: 44),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.isEmpty ? "Vehicle" : type,
                              style: context.text.titleSmall,
                            ),
                            Text(
                              pricePerKm == null
                                  ? "Rate not set"
                                  : "LKR $pricePerKm / km",
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader("Vehicle details"),
                const SizedBox(height: Space.md),
                AppTextField(
                  label: "Vehicle name / model",
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  hint: "e.g. Toyota KDH",
                  validator: (v) => requiredField(v, "Enter the vehicle name."),
                ),
                const SizedBox(height: Space.lg),
                AppTextField(
                  label: "Region",
                  controller: _regionController,
                  textInputAction: TextInputAction.next,
                  hint: "e.g. Colombo",
                  validator: (v) => requiredField(v, "Enter the region."),
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
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  InlineAlert(_error!, tone: Tone.danger),
                ],
                const SizedBox(height: Space.xxl),
                AppButton(
                  label: "Save changes",
                  loading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
