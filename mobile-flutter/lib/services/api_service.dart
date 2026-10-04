import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Bytes + filename for an image/document to upload. Using raw bytes (read via
// XFile.readAsBytes()) instead of a file path works on every platform, including
// Flutter Web — MultipartFile.fromPath() needs dart:io and fails there.
class UploadFile {
  final Uint8List bytes;
  final String filename;
  UploadFile(this.bytes, this.filename);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Flip this to true to point the app at the deployed backend
  // (https://ceylora-production.up.railway.app) instead of a local
  // `dotnet run` instance — useful for a demo/grading build that doesn't
  // need the backend running on this machine. Leave it false for day-to-day
  // development against localhost.
  static const bool useDeployedBackend = false;
  static const String deployedBaseUrl =
      "https://ceylora-production.up.railway.app/api";

  static String get baseUrl {
    if (useDeployedBackend) return deployedBaseUrl;

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
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Login failed: ${response.body}");
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
    }
    throw Exception("Registration failed: ${response.body}");
  }

  // ---------------- GUIDE / VEHICLE OWNER REGISTRATION (multipart, with document upload) ----------------

  Future<Map<String, dynamic>> registerGuide({
    required String name,
    required String email,
    required String password,
    required int age,
    required String region,
    required String nicNumber,
    required String mobileNumber,
    String? country,
    String? languages,
    required UploadFile tourismIdPhoto,
  }) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/auth/register-guide"));
    request.fields.addAll({
      "name": name,
      "email": email,
      "password": password,
      "age": "$age",
      "region": region,
      "nicNumber": nicNumber,
      "mobileNumber": mobileNumber,
      if (country != null && country.isNotEmpty) "country": country,
      if (languages != null && languages.isNotEmpty) "languages": languages,
    });
    request.files.add(http.MultipartFile.fromBytes(
      "tourismIdPhoto",
      tourismIdPhoto.bytes,
      filename: tourismIdPhoto.filename,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception("Registration failed: ${response.body}");
  }

  Future<Map<String, dynamic>> registerVehicleOwner({
    required String name,
    required String email,
    required String password,
    required int age,
    required String region,
    required String nicNumber,
    required String mobileNumber,
    String? country,
    required UploadFile drivingLicensePhoto,
    required String vehicleType,
    required String vehicleName,
    required int manufacturerYear,
    required int numberOfSeats,
    required List<UploadFile> vehiclePhotos,
  }) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/auth/register-vehicle-owner"));
    request.fields.addAll({
      "name": name,
      "email": email,
      "password": password,
      "age": "$age",
      "region": region,
      "nicNumber": nicNumber,
      "mobileNumber": mobileNumber,
      if (country != null && country.isNotEmpty) "country": country,
      "vehicleType": vehicleType,
      "vehicleName": vehicleName,
      "manufacturerYear": "$manufacturerYear",
      "numberOfSeats": "$numberOfSeats",
    });
    request.files.add(http.MultipartFile.fromBytes(
      "drivingLicensePhoto",
      drivingLicensePhoto.bytes,
      filename: drivingLicensePhoto.filename,
    ));
    for (final photo in vehiclePhotos) {
      request.files.add(http.MultipartFile.fromBytes(
        "vehiclePhotos",
        photo.bytes,
        filename: photo.filename,
      ));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception("Registration failed: ${response.body}");
  }

  // ---------------- VEHICLE OWNER DASHBOARD ----------------

  Future<Map<String, dynamic>?> getMyVehicleOwnerProfile() async {
    final response = await http.get(Uri.parse("$baseUrl/vehicle-owners/me"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<List<dynamic>> getMyVehicles() async {
    final response = await http.get(Uri.parse("$baseUrl/vehicles/my"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<void> toggleVehicleAvailability(int vehicleId, bool isAvailable) async {
    final response = await http.put(
      Uri.parse("$baseUrl/vehicles/$vehicleId/availability"),
      headers: _headers,
      body: jsonEncode(isAvailable),
    );
    if (response.statusCode != 204) {
      String message = "Failed to update availability";
      try { message = jsonDecode(response.body)["message"] ?? message; } catch (_) {}
      throw Exception(message);
    }
  }

  /// Lets a Vehicle Owner edit their own vehicle's basic details (name, region,
  /// manufacture year, seats) from the Profile tab. Type and price-per-km stay
  /// Admin-controlled, and availability has its own toggleVehicleAvailability call.
  Future<void> updateVehicleDetails({
    required int vehicleId,
    String? name,
    int? manufacturerYear,
    required int capacity,
    required String region,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/vehicles/$vehicleId/details"),
      headers: _headers,
      body: jsonEncode({
        "name": name,
        "manufacturerYear": manufacturerYear,
        "capacity": capacity,
        "region": region,
      }),
    );
    if (response.statusCode != 204) {
      String message = "Failed to update vehicle details";
      try { message = jsonDecode(response.body)["message"] ?? message; } catch (_) {}
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>?> getVehicleOwnerEarnings(int vehicleOwnerId) async {
    final response = await http.get(Uri.parse("$baseUrl/vehicle-owners/$vehicleOwnerId/earnings"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<List<dynamic>> getMyVehicleAssignments() async {
    final response = await http.get(Uri.parse("$baseUrl/assignments/my-vehicle"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ---------------- USER PROFILE ----------------

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await http.get(Uri.parse("$baseUrl/users/me"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
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
    if (response.statusCode != 204) throw Exception("Failed to update profile");
  }

  Future<String> uploadProfilePicture(UploadFile file) async {
    final uri = Uri.parse("$baseUrl/users/me/profile-picture");
    final request = http.MultipartRequest("POST", uri);
    if (_token != null) request.headers["Authorization"] = "Bearer $_token";
    request.files.add(http.MultipartFile.fromBytes("file", file.bytes, filename: file.filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["profilePictureUrl"];
    }
    throw Exception("Failed to upload profile picture");
  }

  // ---------------- DESTINATIONS / PACKAGES / HOTELS / VEHICLES / GUIDES ----------------

  Future<List<dynamic>> getDestinations({String? search, String? region, String? category, String? sortBy}) async {
    final uri = Uri.parse("$baseUrl/destinations").replace(queryParameters: {
      "pageSize": "50",
      if (search != null && search.isNotEmpty) "search": search,
      if (region != null && region.isNotEmpty) "region": region,
      if (category != null && category.isNotEmpty) "category": category,
      if (sortBy != null && sortBy.isNotEmpty) "sortBy": sortBy,
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load destinations");
  }

  Future<List<dynamic>> getPackages({String? search}) async {
    final uri = Uri.parse("$baseUrl/packages").replace(queryParameters: {
      "pageSize": "50",
      if (search != null && search.isNotEmpty) "search": search,
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load packages");
  }

  Future<List<dynamic>> getHotels({String? search, String? region, int? minStars, String? sortBy}) async {
    final uri = Uri.parse("$baseUrl/hotels").replace(queryParameters: {
      "pageSize": "50",
      if (search != null && search.isNotEmpty) "search": search,
      if (region != null && region.isNotEmpty) "region": region,
      if (minStars != null) "minStars": "$minStars",
      if (sortBy != null && sortBy.isNotEmpty) "sortBy": sortBy,
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load hotels");
  }

  Future<List<dynamic>> getVehicles({String? search, String? region, String? type, String? sortBy, bool? available}) async {
    final uri = Uri.parse("$baseUrl/vehicles").replace(queryParameters: {
      "pageSize": "50",
      if (search != null && search.isNotEmpty) "search": search,
      if (region != null && region.isNotEmpty) "region": region,
      if (type != null && type.isNotEmpty) "type": type,
      if (sortBy != null && sortBy.isNotEmpty) "sortBy": sortBy,
      if (available != null) "available": available.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load vehicles");
  }

  Future<List<dynamic>> getGuides({String? search, String? region, bool? available}) async {
    final uri = Uri.parse("$baseUrl/guides").replace(queryParameters: {
      "pageSize": "50",
      if (search != null && search.isNotEmpty) "search": search,
      if (region != null && region.isNotEmpty) "region": region,
      if (available != null) "available": available.toString(),
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["items"];
    throw Exception("Failed to load guides");
  }

  // ---------------- FAVORITES ----------------

  Future<List<dynamic>> getFavorites({String? itemType}) async {
    final uri = Uri.parse("$baseUrl/favorites").replace(queryParameters: {
      if (itemType != null) "itemType": itemType,
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load favorites");
  }

  Future<bool> isFavorite(String itemType, int itemId) async {
    final uri = Uri.parse("$baseUrl/favorites/check")
        .replace(queryParameters: {"itemType": itemType, "itemId": "$itemId"});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body) == true;
    return false;
  }

  Future<void> addFavorite(String itemType, int itemId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/favorites"),
      headers: _headers,
      body: jsonEncode({"itemType": itemType, "itemId": itemId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add favorite");
    }
  }

  Future<void> removeFavorite(String itemType, int itemId) async {
    final uri = Uri.parse("$baseUrl/favorites")
        .replace(queryParameters: {"itemType": itemType, "itemId": "$itemId"});
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception("Failed to remove favorite");
    }
  }

  Future<void> toggleGuideAvailability(int guideId, bool isAvailable) async {
    final response = await http.put(
      Uri.parse("$baseUrl/guides/$guideId/availability"),
      headers: _headers,
      body: jsonEncode(isAvailable),
    );
    if (response.statusCode != 204) {
      String message = "Failed to update availability";
      try { message = jsonDecode(response.body)["message"] ?? message; } catch (_) {}
      throw Exception(message);
    }
  }

  // ---------------- CURRENCY CONVERTER ----------------
  // Uses a free, no-API-key exchange rate service directly (not our own backend) — rates
  // change often enough that hardcoding them would go stale, and this app has no billing/
  // subscription for a paid FX API. Cache the result briefly in-memory so the converter
  // screen doesn't re-fetch on every keystroke.
  static Map<String, dynamic>? _cachedRates;
  static DateTime? _ratesCachedAt;

  Future<Map<String, dynamic>> getExchangeRates({String base = "LKR"}) async {
    if (_cachedRates != null &&
        _ratesCachedAt != null &&
        DateTime.now().difference(_ratesCachedAt!) < const Duration(minutes: 30)) {
      return _cachedRates!;
    }
    final response = await http.get(Uri.parse("https://open.er-api.com/v6/latest/$base"));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body["result"] == "success") {
        _cachedRates = body["rates"] as Map<String, dynamic>;
        _ratesCachedAt = DateTime.now();
        return _cachedRates!;
      }
    }
    throw Exception("Failed to load exchange rates. Check your internet connection.");
  }

  Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    final response = await http.get(
      Uri.parse("$baseUrl/weather/forecast?lat=$lat&lon=$lon"),
      headers: _headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> getWeatherForDay(double lat, double lon, int daysFromNow) async {
    final response = await http.get(
      Uri.parse("$baseUrl/weather/forecast-day?lat=$lat&lon=$lon&daysFromNow=$daysFromNow"),
      headers: _headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  /// Distance-based vehicle charge between two points (used to estimate trip cost).
  Future<Map<String, dynamic>?> getDistanceQuote({
    required int vehicleId,
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/vehicles/distance-quote"),
      headers: _headers,
      body: jsonEncode({
        "vehicleId": vehicleId,
        "startLat": startLat,
        "startLon": startLon,
        "endLat": endLat,
        "endLon": endLon,
      }),
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

  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async {
    final response = await http.get(Uri.parse("$baseUrl/bookings/$bookingId/details"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load booking details: ${response.body}");
  }

  Future<Map<String, dynamic>> createBooking({
    required int packageId,
    required int groupSize,
    required DateTime startDate,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/bookings"),
      headers: _headers,
      body: jsonEncode({
        "packageId": packageId,
        "groupSize": groupSize,
        "travelDate": startDate.toIso8601String(),
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

  Future<List<dynamic>> getReviewsForBooking(int bookingId) async {
    final response = await http.get(Uri.parse("$baseUrl/reviews/booking/$bookingId"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<void> submitReview({
    required int bookingId,
    required int rating,
    String? comment,
    int? hotelRating,
    int? vehicleRating,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/reviews"),
      headers: _headers,
      body: jsonEncode({
        "bookingId": bookingId,
        "rating": rating,
        "comment": comment,
        "hotelRating": hotelRating,
        "vehicleRating": vehicleRating,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to submit review");
    }
  }

  // ---------------- BOOKING CANCELLATION ----------------

  Future<void> cancelBooking(int bookingId) async {
    final response = await http.put(
      Uri.parse("$baseUrl/bookings/$bookingId/cancel"),
      headers: _headers,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception("Failed to cancel booking: ${response.body}");
    }
  }

  // ---------------- NOTIFICATIONS ----------------

  Future<List<dynamic>> getNotifications({bool unreadOnly = false}) async {
    final uri = Uri.parse("$baseUrl/notifications").replace(queryParameters: {
      if (unreadOnly) "unreadOnly": "true",
    });
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load notifications");
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await http.get(Uri.parse("$baseUrl/notifications/unread-count"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body)["count"] ?? 0;
    return 0;
  }

  Future<void> markNotificationRead(int id) async {
    await http.put(Uri.parse("$baseUrl/notifications/$id/read"), headers: _headers);
  }

  Future<void> markAllNotificationsRead() async {
    await http.put(Uri.parse("$baseUrl/notifications/read-all"), headers: _headers);
  }

  // ---------------- GUIDE DASHBOARD ----------------

  Future<Map<String, dynamic>?> getMyGuideProfile() async {
    final response = await http.get(Uri.parse("$baseUrl/guides/me"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<List<dynamic>> getMyAssignments() async {
    final response = await http.get(Uri.parse("$baseUrl/assignments/my"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>?> getGuideEarnings(int guideId) async {
    final response = await http.get(Uri.parse("$baseUrl/guides/$guideId/earnings"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  // Guide starts/ends the assigned trip — moves the booking's trip status
  // (Confirmed -> OnGoing -> Ended) shown on Admin/Tourist/Guide/Vehicle Owner sides.
  Future<void> startTrip(int assignmentId) async {
    final response = await http.put(Uri.parse("$baseUrl/assignments/$assignmentId/start"), headers: _headers);
    if (response.statusCode != 204) throw Exception("Failed to start trip: ${response.body}");
  }

  Future<void> endTrip(int assignmentId) async {
    final response = await http.put(Uri.parse("$baseUrl/assignments/$assignmentId/end"), headers: _headers);
    if (response.statusCode != 204) {
      String message = "Failed to end tour";
      try { message = jsonDecode(response.body)["message"] ?? message; } catch (_) {}
      throw Exception(message);
    }
  }

  // ---------------- IN-APP CHAT (Tourist <-> Guide) ----------------

  Future<List<dynamic>> getChatMessages(int bookingId) async {
    final response = await http.get(Uri.parse("$baseUrl/chat/$bookingId/messages"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 403) throw Exception("You don't have access to this chat.");
    throw Exception("Failed to load chat messages");
  }

  Future<Map<String, dynamic>> sendChatMessage(int bookingId, String message) async {
    final response = await http.post(
      Uri.parse("$baseUrl/chat/$bookingId/messages"),
      headers: _headers,
      body: jsonEncode({"message": message}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to send message: ${response.body}");
  }

  /// Map of bookingId -> unread message count, for badges on booking/assignment lists.
  Future<Map<int, int>> getChatUnreadCounts() async {
    final response = await http.get(Uri.parse("$baseUrl/chat/unread-counts"), headers: _headers);
    if (response.statusCode != 200) return {};
    final List<dynamic> data = jsonDecode(response.body);
    return {for (final row in data) row["bookingId"] as int: row["unread"] as int};
  }

  /// All chat threads for the current user (Tourist or Guide) — feeds the "Chats" list
  /// screen reached from the home-screen chat icon.
  Future<List<dynamic>> getChatThreads() async {
    final response = await http.get(Uri.parse("$baseUrl/chat/threads"), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load chats");
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

  /// Calls the AI to generate a plan WITHOUT persisting it, so the tourist can review/edit first.
  Future<Map<String, dynamic>> previewAgentWorkflow(String objective) async {
    final response = await http.post(
      Uri.parse("$baseUrl/agent-workflows/preview"),
      headers: _headers,
      body: jsonEncode({"objective": objective}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to preview trip plan: ${response.body}");
  }

  /// Submits the tourist's final (possibly edited) plan for admin approval.
  /// [days] entries can carry their own "destinationIds" (List<int>) and "hotelId" (int?),
  /// since each day can now have a different set of destinations & hotel.
  Future<Map<String, dynamic>> submitTripPlan({
    required String objective,
    int? bookingId,
    required List<int> destinationIds,
    int? hotelId,
    int? guideId,
    int? vehicleId,
    required List<Map<String, dynamic>> days,
    double? estimatedTotalCost,
    DateTime? plannedStartDate,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/agent-workflows/submit-plan"),
      headers: _headers,
      body: jsonEncode({
        "objective": objective,
        "bookingId": bookingId,
        "destinationIds": destinationIds,
        "hotelId": hotelId,
        "guideId": guideId,
        "vehicleId": vehicleId,
        "days": days,
        "estimatedTotalCost": estimatedTotalCost,
        "plannedStartDate": plannedStartDate?.toIso8601String(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to submit trip plan: ${response.body}");
  }
}