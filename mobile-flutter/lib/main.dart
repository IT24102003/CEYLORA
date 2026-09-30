import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CeyloraApp());
}

class CeyloraApp extends StatelessWidget {
  const CeyloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: MaterialApp(
        title: 'CEYLORA',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          useMaterial3: true,
        ),
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

    if (!auth.isLoggedIn) return const LoginScreen();

    // Everyone — Tourist, Guide, VehicleOwner — uses the same normal app interface,
    // whether or not a Guide/VehicleOwner has been verified by an Admin yet. Verification
    // only controls whether they're shown to other users (handled server-side); it never
    // blocks them from using the app themselves. A Guide/VehicleOwner's dashboard (available
    // status, rating, earnings, assigned/completed trips, profile edit) lives under "My
    // Profile" inside HomeScreen, not as a separate gate here.
    return const HomeScreen();
  }
}
