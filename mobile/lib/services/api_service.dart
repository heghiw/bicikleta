import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your server URL in production
  static const _base = 'http://localhost:8000';

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('ps_token');
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ps_token', token);
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ps_token');
  }

  static bool get isLoggedIn => _token != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': '******',
  };

  static Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: _headers);
    return _handle(res);
  }

  static Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode == 204) return null;
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['detail']?.toString() ?? 'Request failed (${res.statusCode})');
    }
    return data;
  }

  // ── Auth ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_base/api/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw ApiException(data['detail']?.toString() ?? 'Login failed');
    await _saveToken(data['access_token'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required File idDocument,
    required File selfie,
  }) async {
    final request = http.MultipartRequest(
      'POST', Uri.parse('$_base/api/auth/register'),
    );
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.files.add(await http.MultipartFile.fromPath('id_document', idDocument.path));
    request.files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw ApiException(data['detail']?.toString() ?? 'Registration failed');
    return data;
  }

  // ── User ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() => _get('/api/users/me');
  static Future<List<dynamic>> getPointLedger() => _get('/api/users/me/points').then((v) => v as List);
  static Future<List<dynamic>> getMyRentals() => _get('/api/users/me/rentals').then((v) => v as List);
  static Future<List<dynamic>> getMyDeliveries() => _get('/api/users/me/deliveries').then((v) => v as List);
  static Future<Map<String, dynamic>> getGamification() => _get('/api/users/me/gamification');

  // ── Bikes ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> searchBikes({
    double userLat = 52.52,
    double userLon = 13.405,
    double radiusKm = 10.0,
    String? type,
    double? maxHourlyPrice,
  }) async {
    final body = <String, dynamic>{
      'user_lat': userLat, 'user_lon': userLon, 'radius_km': radiusKm,
      if (type != null) 'type': type,
      if (maxHourlyPrice != null) 'max_hourly_price': maxHourlyPrice,
    };
    final res = await http.post(
      Uri.parse('$_base/api/bikes/search'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(res) as List;
  }

  static Future<Map<String, dynamic>> getBike(int id) => _get('/api/bikes/$id');
  static Future<List<dynamic>> getBikeReviews(int id) => _get('/api/bikes/$id/reviews').then((v) => v as List);
  static Future<List<dynamic>> getMyBikes() => _get('/api/bikes/mine').then((v) => v as List);
  static Future<Map<String, dynamic>> createBike(Map<String, dynamic> body) => _post('/api/bikes/', body);

  // ── Rentals ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> bookBike(int bikeId, double lat, double lon) =>
      _post('/api/rentals/', {'bike_id': bikeId, 'pickup_lat': lat, 'pickup_lon': lon});
  static Future<Map<String, dynamic>> startRental(int id) => _post('/api/rentals/$id/start');
  static Future<Map<String, dynamic>> endRental(int id, double returnLat, double returnLon) =>
      _post('/api/rentals/$id/end', {'return_lat': returnLat, 'return_lon': returnLon});
  static Future<Map<String, dynamic>> cancelRental(int id) => _post('/api/rentals/$id/cancel');

  // ── Delivery ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listOpenJobs() => _get('/api/delivery/jobs').then((v) => v as List);
  static Future<List<dynamic>> searchJobs({double userLat = 52.52, double userLon = 13.405, double radiusKm = 20}) async {
    final res = await http.post(
      Uri.parse('$_base/api/delivery/jobs/search'),
      headers: _headers,
      body: jsonEncode({'user_lat': userLat, 'user_lon': userLon, 'radius_km': radiusKm}),
    );
    return _handle(res) as List;
  }
  static Future<Map<String, dynamic>> acceptSegment(int jobId, double lat, double lon) =>
      _post('/api/delivery/jobs/$jobId/accept', {'start_lat': lat, 'start_lon': lon});
  static Future<Map<String, dynamic>> completeSegment(int segId, double lat, double lon, {bool relay = false}) =>
      _post('/api/delivery/segments/$segId/complete', {'end_lat': lat, 'end_lon': lon, 'relay': relay});

  // ── Shop ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listOffers() => _get('/api/shop/offers').then((v) => v as List);
  static Future<Map<String, dynamic>> redeemOffer(int id) => _post('/api/shop/offers/$id/redeem');

  // ── Gamification ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLeaderboard() => _get('/api/gamification/leaderboard').then((v) => v as List);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
