import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ceylora_app/providers/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    setUp(() {
      // No session saved unless a test says otherwise.
      SharedPreferences.setMockInitialValues({});
    });

    test('starts logged out before tryAutoLogin runs', () {
      final auth = AuthProvider();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.token, isNull);
      expect(auth.role, isNull);
      expect(auth.isVerified, isTrue); // defaults to verified until proven otherwise
    });

    test('tryAutoLogin restores a previously saved session', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'saved-token',
        'name': 'Nimal Perera',
        'role': 'Tourist',
        'isVerified': true,
      });
      final auth = AuthProvider();

      await auth.tryAutoLogin();

      expect(auth.isLoggedIn, isTrue);
      expect(auth.token, 'saved-token');
      expect(auth.name, 'Nimal Perera');
      expect(auth.role, 'Tourist');
    });

    test('tryAutoLogin leaves the session empty when nothing was saved', () async {
      final auth = AuthProvider();

      await auth.tryAutoLogin();

      expect(auth.isLoggedIn, isFalse);
    });

    test('setSessionFromAuthResult stores the session and persists it to SharedPreferences', () async {
      final auth = AuthProvider();

      await auth.setSessionFromAuthResult({
        'token': 'new-token',
        'name': 'Kamal',
        'role': 'Guide',
        'isVerified': false, // pending Admin review, same as a fresh Guide self-registration
      });

      expect(auth.isLoggedIn, isTrue);
      expect(auth.role, 'Guide');
      expect(auth.isVerified, isFalse);

      // A fresh AuthProvider restoring from SharedPreferences (e.g. the app being
      // relaunched) should see exactly the same session that was just persisted.
      final restored = AuthProvider();
      await restored.tryAutoLogin();
      expect(restored.token, 'new-token');
      expect(restored.role, 'Guide');
      expect(restored.isVerified, isFalse);
    });

    test('logout clears both the in-memory state and SharedPreferences', () async {
      final auth = AuthProvider();
      await auth.setSessionFromAuthResult({
        'token': 't', 'name': 'N', 'role': 'Tourist', 'isVerified': true,
      });
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.token, isNull);
      expect(auth.name, isNull);
      expect(auth.role, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);
    });

    test('updateLocalName updates the in-memory name and persists it', () async {
      final auth = AuthProvider();
      await auth.setSessionFromAuthResult({
        'token': 't', 'name': 'Old Name', 'role': 'Tourist', 'isVerified': true,
      });

      await auth.updateLocalName('New Name');

      expect(auth.name, 'New Name');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('name'), 'New Name');
    });
  });
}
