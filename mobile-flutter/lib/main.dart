import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/scenic/scenic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status/navigation bars; each screen pads itself with SafeArea.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const CeyloraApp());
}

class CeyloraApp extends StatefulWidget {
  const CeyloraApp({super.key, this.animateScenery = true});

  /// The shared destination backdrop drifts and rotates; tests turn this off so they can settle.
  final bool animateScenery;

  @override
  State<CeyloraApp> createState() => _CeyloraAppState();
}

class _CeyloraAppState extends State<CeyloraApp> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    if (widget.animateScenery) Scenic.instance.start(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final d in Destination.values) {
      precacheImage(AssetImage('assets/backgrounds/${d.slug}.jpg'), context, onError: (_, _) {});
    }
  }

  @override
  void dispose() {
    Scenic.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: MaterialApp(
        title: 'CEYLORA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark, // the app's look is the deep-blue theme
        builder: (context, child) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            ),
            // Keeps content clear of side camera cutouts / rounded corners in landscape.
            child: SafeArea(top: false, bottom: false, child: child ?? const SizedBox.shrink()),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Everyone — Tourist, Guide, VehicleOwner — uses the same app shell, whether or not a
    // Guide/VehicleOwner has been verified by an Admin yet. Verification only controls
    // whether they're shown to other users (handled server-side); it never blocks them from
    // using the app themselves. A Guide/VehicleOwner's dashboard (available status, rating,
    // earnings, assigned/completed trips, profile edit) is the last tab inside HomeScreen.
    return AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.out,
      child: auth.isLoggedIn
          ? const HomeScreen(key: ValueKey('home'))
          : const IntroGate(key: ValueKey('intro-gate')),
    );
  }
}

/// Shows the intro once per install, then the sign-in screen.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key});

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _seen = p.getBool('seenIntro') ?? false);
    });
  }

  Future<void> _finish() async {
    setState(() => _seen = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenIntro', true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.slow,
      child: switch (_seen) {
        null => const Scaffold(key: ValueKey('wait')),
        true => const LoginScreen(key: ValueKey('login')),
        false => IntroScreen(key: const ValueKey('intro'), onDone: _finish),
      },
    );
  }
}
