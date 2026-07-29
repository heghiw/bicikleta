import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const _api = '$_base/api/v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _tokenKey = 'pedalshare_access_token';
  static const _timeout = Duration(seconds: 20);

  static String? _token;

  static Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  static bool get isLoggedIn => _token != null;
  static String assetUrl(String path) =>
      path.startsWith('http') ? path : '$_base$path';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<T> _get<T>(String path) async {
    final res = await http
        .get(Uri.parse('$_api$path'), headers: _headers)
        .timeout(_timeout);
    return _handle(res) as T;
  }

  static Future<T> _post<T>(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .post(
          Uri.parse('$_api$path'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _handle(res) as T;
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode == 204) return null;
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      if (res.statusCode == 401) {
        // Never leave the router believing an expired token is a valid session.
        _token = null;
        _storage.delete(key: _tokenKey);
      }
      throw ApiException(
        data['detail']?.toString() ?? 'Request failed (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return data;
  }

  // ── Auth ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('$_api/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    ).timeout(_timeout);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(data['detail']?.toString() ?? 'Login failed');
    }
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
      'POST',
      Uri.parse('$_api/auth/register'),
    );
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.files
        .add(await http.MultipartFile.fromPath('id_document', idDocument.path));
    request.files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(data['detail']?.toString() ?? 'Registration failed');
    }
    return data;
  }

  // ── User ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() => _get('/users/me');
  static Future<Map<String, dynamic>> updateProfile(
      {required String name, required String email}) async {
    final res = await http
        .patch(Uri.parse('$_api/users/me'),
            headers: _headers, body: jsonEncode({'name': name, 'email': email}))
        .timeout(_timeout);
    return _handle(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getPointLedger() =>
      _get('/users/me/points').then((v) => v as List);
  static Future<List<dynamic>> getMyRentals() =>
      _get('/users/me/rentals').then((v) => v as List);
  static Future<List<dynamic>> getMyDeliveries() =>
      _get('/users/me/deliveries').then((v) => v as List);
  static Future<Map<String, dynamic>> getGamification() =>
      _get('/users/me/gamification');

  // ── Bikes ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> searchBikes({
    required double userLat,
    required double userLon,
    double radiusKm = 10.0,
    String? type,
    double? maxHourlyPrice,
  }) async {
    final body = <String, dynamic>{
      'user_lat': userLat,
      'user_lon': userLon,
      'radius_km': radiusKm,
      if (type != null) 'type': type,
      if (maxHourlyPrice != null) 'max_hourly_price': maxHourlyPrice,
    };
    final res = await http
        .post(
          Uri.parse('$_api/bikes/search'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _handle(res) as List;
  }

  static Future<Map<String, dynamic>> getBike(int id) => _get('/bikes/$id');
  static Future<List<dynamic>> getBikeReviews(int id) =>
      _get('/bikes/$id/reviews').then((v) => v as List);
  static Future<List<dynamic>> getMyBikes() =>
      _get('/bikes/mine').then((v) => v as List);
  static Future<Map<String, dynamic>> createBike(Map<String, dynamic> body) =>
      _post('/bikes/', body);
  static Future<Map<String, dynamic>> uploadBikePhotos(
      int bikeId, List<File> photos) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_api/bikes/$bikeId/photos'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    for (final photo in photos) {
      request.files
          .add(await http.MultipartFile.fromPath('photos', photo.path));
    }
    final streamed = await request.send().timeout(_timeout);
    return _handle(await http.Response.fromStream(streamed))
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> pairTracker(
          int bikeId, Map<String, dynamic> body) =>
      _post('/bikes/$bikeId/tracker/pair', body);
  static Future<Map<String, dynamic>> getTracker(int bikeId) =>
      _get('/bikes/$bikeId/tracker');

  // ── Rentals ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> bookBike(
          int bikeId, double lat, double lon, String paymentIntentId) =>
      _post('/rentals/', {
        'bike_id': bikeId,
        'pickup_lat': lat,
        'pickup_lon': lon,
        'payment_intent_id': paymentIntentId
      });
  static Future<Map<String, dynamic>> createPaymentIntent(int bikeId) =>
      _post('/rentals/payment-intent', {'bike_id': bikeId});
  static Future<List<dynamic>> getParkingZones() =>
      _get('/rentals/parking-zones').then((value) => value as List<dynamic>);
  static Future<Map<String, dynamic>> getRentalLock(int id) =>
      _get('/rentals/$id/lock');
  static Future<Map<String, dynamic>> uploadReturnPhoto(
      int id, File photo) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse('$_api/rentals/$id/return-photo'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    return _handle(await http.Response.fromStream(
        await request.send().timeout(_timeout))) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> startRental(int id, String bikeQr) =>
      _post('/rentals/$id/start', {'bike_qr': bikeQr});
  static Future<Map<String, dynamic>> endRental(
          int id, double returnLat, double returnLon, bool lockConfirmed) =>
      _post('/rentals/$id/end', {
        'return_lat': returnLat,
        'return_lon': returnLon,
        'lock_confirmed': lockConfirmed
      });
  static Future<Map<String, dynamic>> cancelRental(int id) =>
      _post('/rentals/$id/cancel');
  static Future<Map<String, dynamic>> getBikeIdentity(int id) =>
      _get('/bikes/$id/identity');
  static Future<Map<String, dynamic>> rotateBikeIdentity(int id) =>
      _post('/bikes/$id/identity/rotate');

  // ── Delivery ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listOpenJobs() =>
      _get('/delivery/jobs').then((v) => v as List);
  static Future<Map<String, dynamic>> getDeliveryJob(int id) =>
      _get('/delivery/jobs/$id');
  static Future<List<dynamic>> searchJobs(
      {required double userLat,
      required double userLon,
      double radiusKm = 20}) async {
    final res = await http
        .post(
          Uri.parse('$_api/delivery/jobs/search'),
          headers: _headers,
          body: jsonEncode({
            'user_lat': userLat,
            'user_lon': userLon,
            'radius_km': radiusKm
          }),
        )
        .timeout(_timeout);
    return _handle(res) as List;
  }

  static Future<List<dynamic>> searchDirectionalJobs({
    required double originLat,
    required double originLon,
    required double destinationLat,
    required double destinationLon,
    required double maxDetourKm,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_api/delivery/jobs/directional-search'),
          headers: _headers,
          body: jsonEncode({
            'origin_lat': originLat,
            'origin_lon': originLon,
            'destination_lat': destinationLat,
            'destination_lon': destinationLon,
            'max_detour_km': maxDetourKm,
          }),
        )
        .timeout(_timeout);
    return _handle(res) as List;
  }

  static Future<Map<String, dynamic>> acceptSegment(
          int jobId, double lat, double lon) =>
      _post(
          '/delivery/jobs/$jobId/accept', {'start_lat': lat, 'start_lon': lon});
  static Future<Map<String, dynamic>> completeSegment(
          int segId, double lat, double lon, {bool relay = false}) =>
      _post('/delivery/segments/$segId/complete',
          {'end_lat': lat, 'end_lon': lon, 'relay': relay});

  // ── Shop ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> listOffers() =>
      _get('/shop/offers').then((v) => v as List);
  static Future<Map<String, dynamic>> redeemOffer(int id) =>
      _post('/shop/offers/$id/redeem');

  // ── Gamification ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLeaderboard() =>
      _get('/gamification/leaderboard').then((v) => v as List);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => message;
}
