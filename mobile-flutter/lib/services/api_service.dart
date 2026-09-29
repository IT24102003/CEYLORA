import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5220/api";
    } else if (Platform.isAndroid) {
      return "http://10.0.2.2:5220/api"; // Android emulator alias for host localhost
    } else {
      return "http://localhost:5220/api"; // iOS simulator, Windows desktop, etc.
    }
  }

  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        if (_token != null) "Authorization": "Bearer $_token",
      };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Login failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, int role) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "role": role,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Registration failed: ${response.body}");
    }
  }

  Future<List<dynamic>> getDestinations() async {
    final response = await http.get(
      Uri.parse("$baseUrl/destinations?pageSize=50"),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["items"];
    } else {
      throw Exception("Failed to load destinations");
    }
  }

  Future<List<dynamic>> getPackages() async {
    final response = await http.get(
      Uri.parse("$baseUrl/packages?pageSize=50"),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["items"];
    } else {
      throw Exception("Failed to load packages");
    }
  }
}