import 'package:geocoding/geocoding.dart';

/// Converts coordinates into short, human-readable labels.
///
/// Results are cached for the app session. If reverse geocoding is unavailable,
/// the coordinate pair remains a reliable fallback.
class AddressService {
  AddressService._();

  static final Map<String, Future<String>> _cache = {};

  static Future<String> label(double latitude, double longitude) {
    final key =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    return _cache.putIfAbsent(key, () => _reverse(latitude, longitude));
  }

  static Future<String> _reverse(double latitude, double longitude) async {
    final fallback =
        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    try {
      final places = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 4));
      if (places.isEmpty) return fallback;
      final place = places.first;
      final street = [place.thoroughfare, place.subThoroughfare]
          .where((value) => value != null && value.isNotEmpty)
          .join(' ');
      final city = place.locality ?? place.subAdministrativeArea;
      final parts = [street, city]
          .where((value) => value != null && value.isNotEmpty)
          .map((value) => value!)
          .toList();
      return parts.isEmpty ? fallback : parts.join(', ');
    } on Object {
      return fallback;
    }
  }
}
