import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const _demoMode = bool.fromEnvironment('DEMO_MODE');
  static const _demoLocation = LatLng(50.0755, 14.4378);
  static LatLng? _lastKnown;

  static Future<LatLng> current({bool forceRefresh = false}) async {
    if (_demoMode) return _demoLocation;
    if (!forceRefresh && _lastKnown != null) return _lastKnown!;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Turn on location services to continue.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Enable location permission for Bicikleta in system settings.');
    }
    final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high));
    return _lastKnown = LatLng(position.latitude, position.longitude);
  }
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}
