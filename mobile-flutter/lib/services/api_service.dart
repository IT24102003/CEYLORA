import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5220/api";
    } else if (Platform.isAndroid) {
      return "http://10.0.2.2:5220/api";
    } else {
      return "http://localhost:5220/api";
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

  // ---------------- AUTH ----------------

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

  Future<Map<String, dynamic>> register(String name, String email, String password,
      int role, String country, String mobileNumber) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "role": role,
        "country": country,
        "mobileNumber": mobileNumber,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Registration failed: ${response.body}");
    }
  }

  // ---------------- USER PROFILE ----------------

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await http.get(Uri.parse("$baseUrl/users/me"), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to load profile");
  }

  Future<void> updateMyProfile({
    required String name,
    int? age,
    String? country,
    String? mobileNumber,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users/me"),
      headers: _headers,
      body: jsonEncode({
        "name": name,
        "age": age,
        "country": country,
        "mobileNumber": mobileNumber,
      }),
    );

    if (response.statusCode != 204) {
      throw Exception("Failed to update profile");
    }
  }

  Future<String> uploadProfilePicture(String filePath) async {
    final uri = Uri.parse("$baseUrl/users/me/profile-picture");
    final request = http.MultipartRequest("POST", uri);
    if (_token != null) request.headers["Authorization"] = "Bearer $_token";
    request.files.add(await http.MultipartFile.fromPath("file", filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["profilePictureUrl"];
    }
    throw Exception("Failed to upload profile picture");
  }

  // ---------------- DESTINATIONS / PACKAGES / HOTELS / VEHICLES / GUIDES ----------------

  Future<List<dynamic>> getDestinations() async {
    final response = await http.get(Uri.parse("$baseUrl/destinations?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load destinations");
  }

  Future<List<dynamic>> getPackages() async {
    final response = await http.get(Uri.parse("$baseUrl/packages?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load packages");
  }

  Future<List<dynamic>> getHotels() async {
    final response = await http.get(Uri.parse("$baseUrl/hotels?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load hotels");
  }

  Future<List<dynamic>> getVehicles() async {
    final response = await http.get(Uri.parse("$baseUrl/vehicles?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load vehicles");
  }

  Future<List<dynamic>> getGuides() async {
    final response = await http.get(Uri.parse("$baseUrl/guides?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load guides");
  }

  Future<void> toggleGuideAvailability(int guideId, bool isAvailable) async {
    final response = await http.put(
      Uri.parse("$baseUrl/guides/$guideId/availability"),
      headers: _headers,
      body: jsonEncode(isAvailable),
    );
    if (response.statusCode != 204) throw Exception("Failed to update availability");
  }

  Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    final response = await http.get(
      Uri.parse("$baseUrl/weather/forecast?lat=$lat&lon=$lon"),
      headers: _headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  // ---------------- BOOKINGS / PAYMENTS / REVIEWS ----------------

  Future<List<dynamic>> getMyBookings() async {
    final response = await http.get(Uri.parse("$baseUrl/bookings?pageSize=50"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load bookings");
  }

  Future<Map<String, dynamic>> createBooking({required int packageId, required int groupSize}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/bookings"),
      headers: _headers,
      body: jsonEncode({
        "packageId": packageId,
        "groupSize": groupSize,
        "travelDate": DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to create booking: ${response.body}");
  }

  Future<Map<String, dynamic>> createPayment({required int bookingId, required double amount}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/payments"),
      headers: _headers,
      body: jsonEncode({"bookingId": bookingId, "amount": amount}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Payment failed: ${response.body}");
  }

  Future<void> submitReview({required int bookingId, required int rating, String? comment}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/reviews"),
      headers: _headers,
      body: jsonEncode({"bookingId": bookingId, "rating": rating, "comment": comment}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to submit review");
    }
  }

  // ---------------- AGENTIC AI ----------------

  Future<Map<String, dynamic>> startAgentWorkflow(String objective, {int? bookingId}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/agent-workflows/start"),
      headers: _headers,
      body: jsonEncode({"objective": objective, "bookingId": bookingId}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to start workflow: ${response.body}");
  }
}