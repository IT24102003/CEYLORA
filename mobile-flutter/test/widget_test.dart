import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ceylora_app/main.dart';
import 'package:ceylora_app/widgets/ui/ui.dart';

void main() {
  setUp(() {
    // No network in tests: fall back to the platform font instead of fetching Fira Sans.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'seenIntro': true});
  });

  testWidgets('first launch shows the intro before sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CeyloraApp(animateScenery: false));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Sri Lanka'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
  });

  testWidgets('signed-out users land on the redesigned sign-in screen', (tester) async {
    await tester.pumpWidget(const CeyloraApp(animateScenery: false));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('sign-in validates before calling the API', (tester) async {
    await tester.pumpWidget(const CeyloraApp(animateScenery: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('AppButton shows a spinner and ignores taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: AppButton(label: 'Save', loading: true, onPressed: () => taps++)),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(taps, 0);
  });

  testWidgets('booking status badge maps API enum values to labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Column(children: [BookingStatusBadge(3), BookingStatusBadge('OnGoing')])),
    ));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
  });
}
