import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ActiveMoveScreen extends StatefulWidget {
  const ActiveMoveScreen({required this.job, required this.segment, super.key});
  final Map<String, dynamic> job;
  final Map<String, dynamic> segment;

  @override
  State<ActiveMoveScreen> createState() => _ActiveMoveScreenState();
}

class _ActiveMoveScreenState extends State<ActiveMoveScreen> {
  static const _demoMode = bool.fromEnvironment('DEMO_MODE');
  final _map = MapController();
  final _distance = const Distance();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _clock;
  late final DateTime _startedAt;
  late LatLng _current;
  final List<LatLng> _trail = [];
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  String? _locationMessage;
  bool _finishing = false;

  LatLng get _pickup => LatLng((widget.job['pickup_lat'] as num).toDouble(),
      (widget.job['pickup_lon'] as num).toDouble());
  LatLng get _destination => LatLng(
      (widget.job['dropoff_lat'] as num).toDouble(),
      (widget.job['dropoff_lon'] as num).toDouble());
  double get _remainingKm =>
      _distance.as(LengthUnit.Kilometer, _current, _destination);

  @override
  void initState() {
    super.initState();
    _current = _pickup;
    _trail.add(_current);
    _startedAt =
        DateTime.tryParse(widget.segment['started_at']?.toString() ?? '') ??
            DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed.value = DateTime.now().difference(_startedAt);
    });
    if (!_demoMode) {
      _startLocation();
    } else {
      _locationMessage = 'Demo location: Prague';
    }
  }

  Future<void> _startLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() => _locationMessage = 'Location is turned off');
      }
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _locationMessage = 'Location permission is required');
      }
      return;
    }
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _current = point;
        _trail.add(point);
        if (_trail.length > 500) _trail.removeAt(0);
        _locationMessage = null;
      });
      _map.move(point, 15);
    });
  }

  Future<void> _finish() async {
    if (_remainingKm > .5 && !kDebugMode && !_demoMode) return;
    setState(() => _finishing = true);
    try {
      final result = await ApiService.completeSegment(
        widget.segment['id'] as int,
        _destination.latitude,
        _destination.longitude,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: psOrange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.check, color: psOrange, size: 34)),
              const SizedBox(height: 16),
              Text('Move complete',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('+${result['earned_points']} points',
                  style: const TextStyle(
                      color: psOrange,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${result['distance_km']} km moved',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.go('/progress');
                    },
                    child: const Text('View progress'),
                  )),
              TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.go('/delivery');
                  },
                  child: const Text('Find another move')),
            ]),
          ),
        ),
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
    _clock?.cancel();
    _positionSubscription?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Active move'),
            automaticallyImplyLeading: false,
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(child: PsStatusChip('active')))
            ]),
        body: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _pickup, initialZoom: 14),
            children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pedalshare.pedalshare'),
              PolylineLayer(polylines: [
                Polyline(
                    points: [_pickup, _destination],
                    color: psOrange,
                    strokeWidth: 5,
                    pattern: const StrokePattern.dotted()),
                if (_trail.length > 1)
                  Polyline(
                      points: _trail,
                      color: Theme.of(context).colorScheme.onSurface,
                      strokeWidth: 4),
              ]),
              MarkerLayer(markers: [
                _marker(_destination, Icons.flag, psOrange),
                _marker(_current, Icons.navigation,
                    Theme.of(context).colorScheme.onSurface),
              ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ]),
            ],
          ),
          Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: PsCard(
                  child: Row(children: [
                Expanded(
                    child: ValueListenableBuilder<Duration>(
                  valueListenable: _elapsed,
                  builder: (_, elapsed, __) {
                    final minutes = elapsed.inMinutes
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0');
                    final seconds = elapsed.inSeconds
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0');
                    return _Metric(label: 'TIME', value: '$minutes:$seconds');
                  },
                )),
                Expanded(
                    child: _Metric(
                        label: 'REMAINING',
                        value: '${_remainingKm.toStringAsFixed(1)} km')),
                Expanded(
                    child: _Metric(
                        label: 'REWARD',
                        value: '${widget.job['reward_points']} pts')),
              ]))),
          Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_locationMessage != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_locationMessage!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  Row(children: [
                    const Icon(Icons.flag_outlined, color: psOrange),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Move bike to destination',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Finish within 500 m of the destination',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ]))
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _finishing ||
                                (_remainingKm > .5 && !kDebugMode && !_demoMode)
                            ? null
                            : _finish,
                        icon: _finishing
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(
                            (kDebugMode || _demoMode) && _remainingKm > .5
                                ? 'Simulate arrival and finish'
                                : 'Finish move'),
                      )),
                ]),
              ))),
        ]),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2)),
          child: Icon(icon, color: color, size: 22)));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                letterSpacing: .8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}
