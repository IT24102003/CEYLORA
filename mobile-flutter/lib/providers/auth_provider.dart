import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String? _token;
  String? _name;
  String? _role;
  bool _isVerified = true;
  bool _isLoading = false;

  String? get token => _token;
  String? get name => _name;
  String? get role => _role;
  bool get isVerified => _isVerified;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final name = prefs.getString("name");
    final role = prefs.getString("role");
    final isVerified = prefs.getBool("isVerified") ?? true;

    if (token != null) {
      _token = token;
      _name = name;
      _role = role;
      _isVerified = isVerified;
      _apiService.setToken(token);
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", _token!);
    await prefs.setString("name", _name!);
    await prefs.setString("role", _role!);
    await prefs.setBool("isVerified", _isVerified);
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.login(email, password);
      _token = result["token"];
      _name = result["name"];
      _role = result["role"];
      _isVerified = result["isVerified"] ?? true;
      _apiService.setToken(_token!);
      await _persist();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password, int role,
      String country, String mobileNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.register(
          name, email, password, role, country, mobileNumber);
      _token = result["token"];
      _name = result["name"];
      _role = result["role"];
      _isVerified = result["isVerified"] ?? true;
      _apiService.setToken(_token!);
      await _persist();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Used by the Guide/Vehicle Owner registration screens, which handle the multipart
  /// upload themselves and just need the resulting session stored here.
  Future<void> setSessionFromAuthResult(Map<String, dynamic> result) async {
    _token = result["token"];
    _name = result["name"];
    _role = result["role"];
    _isVerified = result["isVerified"] ?? true;
    _apiService.setToken(_token!);
    await _persist();
    notifyListeners();
  }

  /// Called from the Pending Verification screen's "Check Again" button.
  /// Returns true if STILL pending (not yet verified).
  Future<bool> refreshVerificationStatus() async {
    try {
      final profile = await _apiService.getMyProfile();
      _isVerified = profile["isVerified"] ?? true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isVerified", _isVerified);
      notifyListeners();
      return !_isVerified;
    } catch (e) {
      return true; // couldn't confirm, assume still pending
    }
  }

  /// Called after a profile update so the displayed name stays in sync.
  Future<void> updateLocalName(String newName) async {
    _name = newName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", newName);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _name = null;
    _role = null;
    _isVerified = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
