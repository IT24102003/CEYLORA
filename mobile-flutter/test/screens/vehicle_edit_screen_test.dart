import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ceylora_app/screens/vehicle_edit_screen.dart';
import 'package:ceylora_app/widgets/ui/ui.dart';

// Covers the Vehicle Owner "edit my vehicle" feature's own business rule: Type and
// PricePerKm are fixed, Admin-controlled business pricing, so this form must show them
// read-only and must never let a Vehicle Owner submit without the required fields filled.
void main() {
  setUp(() {
    // No network in tests: fall back to the platform font instead of fetching Fira Sans.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final vehicle = <String, dynamic>{
    "id": 1,
    "name": "Toyota HiAce",
    "region": "Kandy",
    "manufacturerYear": 2020,
    "capacity": 8,
    "type": "Van",
    "pricePerKm": 180,
  };

  Widget buildScreen() => MaterialApp(
        theme: AppTheme.light,
        home: VehicleEditScreen(vehicle: vehicle),
      );

  testWidgets("pre-fills the form with the vehicle's current details", (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Toyota HiAce'), findsOneWidget);
    expect(find.text('Kandy'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('shows vehicle type and price-per-km as read-only, not as editable fields',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Van'), findsOneWidget);
    expect(find.text('LKR 180 / km'), findsOneWidget);

    // Only 4 editable fields: name, region, manufacture year, seats. Type and PricePerKm
    // drive the fixed per-type business pricing and are deliberately excluded here —
    // only an Admin can change them (see VehicleOwnerUpdateDto on the backend).
    expect(find.byType(AppTextField), findsNWidgets(4));
  });

  testWidgets('blocks saving and shows validation errors when required fields are cleared',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    final nameField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Vehicle name / model'),
      matching: find.byType(TextFormField),
    );
    final regionField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Region'),
      matching: find.byType(TextFormField),
    );

    await tester.enterText(nameField, '');
    await tester.enterText(regionField, '');

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.text('Enter the vehicle name.'), findsOneWidget);
    expect(find.text('Enter the region.'), findsOneWidget);
  });
}
