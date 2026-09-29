import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String? _token;
  String? _name;
  String? _role;
  bool _isLoading = false;

  String? get token => _token;
  String? get name => _name;
  String? get role => _role;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final name = prefs.getString("name");
    final role = prefs.getString("role");

    if (token != null) {
      _token = token;
      _name = name;
      _role = role;
      _apiService.setToken(token);
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.login(email, password);
      _token = result["token"];
      _name = result["name"];
      _role = result["role"];
      _apiService.setToken(_token!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", _token!);
      await prefs.setString("name", _name!);
      await prefs.setString("role", _role!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password, int role) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.register(name, email, password, role);
      _token = result["token"];
      _name = result["name"];
      _role = result["role"];
      _apiService.setToken(_token!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", _token!);
      await prefs.setString("name", _name!);
      await prefs.setString("role", _role!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _name = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}