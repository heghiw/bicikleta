import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ActiveRentalScreen extends StatefulWidget {
  const ActiveRentalScreen(
      {required this.bike, required this.rental, super.key});
  final Map<String, dynamic> bike;
  final Map<String, dynamic> rental;
  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  static const _demoMode = bool.fromEnvironment('DEMO_MODE');
  final _map = MapController();
  final _trail = <LatLng>[];
  StreamSubscription<Position>? _location;
  Timer? _timer;
  late LatLng _current;
  late final DateTime _started;
  Duration _elapsed = Duration.zero;
  bool _finishing = false;
  bool _lockConfirmed = false;
  File? _returnPhoto;
  List<dynamic> _zones = [];

  @override
  void initState() {
    super.initState();
    _current = LatLng((widget.bike['current_lat'] as num).toDouble(),
        (widget.bike['current_lon'] as num).toDouble());
    _trail.add(_current);
    _started =
        DateTime.tryParse(widget.rental['start_time']?.toString() ?? '') ??
            DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_started));
      }
    });
    if (!_demoMode) {
      _track();
    }
    ApiService.getParkingZones().then((zones) {
      if (mounted) setState(() => _zones = zones);
    });
  }

  Future<void> _takeReturnPhoto() async {
    final image = await ImagePicker().pickImage(
        source: _demoMode ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600);
    if (image != null && mounted) {
      setState(() => _returnPhoto = File(image.path));
    }
  }

  Future<void> _track() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    _location = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 5))
        .listen((position) {
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _current = point;
        _trail.add(point);
        if (_trail.length > 500) _trail.removeAt(0);
      });
      _map.move(point, 16);
    });
  }

  Future<void> _finish() async {
    if (_returnPhoto == null || !_lockConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add a parking photo and confirm the bike is locked.')));
      return;
    }
    setState(() => _finishing = true);
    try {
      await ApiService.uploadReturnPhoto(
          widget.rental['id'] as int, _returnPhoto!);
      final result = await ApiService.endRental(widget.rental['id'] as int,
          _current.latitude, _current.longitude, _lockConfirmed);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, color: psOrange, size: 56),
                  const SizedBox(height: 12),
                  Text('Ride complete',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('€${(result['total_price'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: psOrange,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const Text('Points and XP added to your progress'),
                  const SizedBox(height: 18),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () {
                            Navigator.pop(sheet);
                            context.go('/progress');
                          },
                          child: const Text('View progress'))),
                ]))),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _location?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inSeconds / 3600;
    final estimate = (hours < .25 ? .25 : hours) *
        (widget.bike['hourly_price'] as num).toDouble();
    final time =
        '${_elapsed.inMinutes.toString().padLeft(2, '0')}:${_elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Active ride'),
              automaticallyImplyLeading: false,
              actions: const [
                Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(child: PsStatusChip('active')))
              ]),
          body: Stack(children: [
            FlutterMap(
                mapController: _map,
                options: MapOptions(initialCenter: _current, initialZoom: 16),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pedalshare.pedalshare'),
                  CircleLayer(
                    circles: _zones
                        .map((zone) => CircleMarker(
                              point: LatLng((zone['lat'] as num).toDouble(),
                                  (zone['lon'] as num).toDouble()),
                              radius: (zone['radius_m'] as num).toDouble(),
                              useRadiusInMeter: true,
                              color: psOrange.withValues(alpha: .12),
                              borderColor: psOrange.withValues(alpha: .7),
                              borderStrokeWidth: 2,
                            ))
                        .toList(),
                  ),
                  if (_trail.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: _trail, color: psOrange, strokeWidth: 5)
                    ]),
                  MarkerLayer(markers: [
                    Marker(
                        point: _current,
                        width: 48,
                        height: 48,
                        child: Container(
                            decoration: BoxDecoration(
                                color: psOrange,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3)),
                            child: const Icon(Icons.navigation,
                                color: Colors.white)))
                  ]),
                ]),
            Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: PsCard(
                    child: Row(children: [
                  Expanded(child: _Metric('TIME', time)),
                  Expanded(
                      child: _Metric(
                          'ESTIMATE', '€${estimate.toStringAsFixed(2)}')),
                  Expanded(
                      child:
                          _Metric('RATE', '€${widget.bike['hourly_price']}/h')),
                ]))),
            Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(widget.bike['title'] as String? ?? 'Bike',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _finishing ? null : _takeReturnPhoto,
                                icon: Icon(_returnPhoto == null
                                    ? Icons.add_a_photo_outlined
                                    : Icons.check_circle_outline),
                                label: Text(_returnPhoto == null
                                    ? 'Parking photo'
                                    : 'Photo added'),
                              ),
                            ),
                          ]),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _lockConfirmed,
                            onChanged: _finishing
                                ? null
                                : (value) => setState(
                                    () => _lockConfirmed = value ?? false),
                            title:
                                const Text('Bike is locked and parked safely'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed: _finishing ? null : _finish,
                                  icon: const Icon(Icons.lock_outline),
                                  label: Text(_finishing
                                      ? 'Finishing…'
                                      : 'Park and finish ride'))),
                        ])))),
          ]),
        ));
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}
