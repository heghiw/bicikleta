import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../services/location_service.dart';

class RouteMatchScreen extends StatefulWidget {
  const RouteMatchScreen({super.key});

  @override
  State<RouteMatchScreen> createState() => _RouteMatchScreenState();
}

class _RouteMatchScreenState extends State<RouteMatchScreen> {
  final _map = MapController();
  bool _rentMode = true;
  List<dynamic> _bikes = [];
  Map<String, dynamic>? _selectedBike;
  LatLng? _origin;
  LatLng? _destination;
  double _maxDetour = 5;
  List<dynamic> _matches = [];
  bool _loading = false;
  String? _error;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadBikes();
  }

  Future<void> _loadBikes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await LocationService.current();
      final bikes = await ApiService.searchBikes(
          userLat: location.latitude,
          userLon: location.longitude,
          radiusKm: 20);
      if (mounted) {
        setState(() {
          _bikes = bikes;
          _currentLocation = location;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _map.move(location, 14);
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final location = await LocationService.current(forceRefresh: true);
      if (!mounted) return;
      setState(() => _origin = location);
      _map.move(location, 14);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _selectPoint(TapPosition _, LatLng point) {
    if (_rentMode) {
      setState(() => _selectedBike = null);
      return;
    }
    setState(() {
      _error = null;
      _matches = [];
      if (_origin == null || _destination != null) {
        _origin = point;
        _destination = null;
      } else {
        _destination = point;
      }
    });
  }

  Future<void> _search() async {
    if (_origin == null || _destination == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matches = await ApiService.searchDirectionalJobs(
        originLat: _origin!.latitude,
        originLon: _origin!.longitude,
        destinationLat: _destination!.latitude,
        destinationLon: _destination!.longitude,
        maxDetourKm: _maxDetour,
      );
      if (mounted) setState(() => _matches = matches);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_rentMode)
        ..._bikes.map((item) => _bikeMarker(item as Map<String, dynamic>)),
      if (!_rentMode && _origin != null)
        _marker(_origin!, Icons.trip_origin,
            Theme.of(context).colorScheme.onSurface),
      if (!_rentMode && _destination != null)
        _marker(_destination!, Icons.flag, const Color(0xFF088F8F)),
      if (!_rentMode)
        ..._matches.map((item) {
          final job = item['job'] as Map<String, dynamic>;
          return _marker(
            LatLng((job['pickup_lat'] as num).toDouble(),
                (job['pickup_lon'] as num).toDouble()),
            Icons.pedal_bike,
            const Color(0xFF088F8F),
          );
        }),
    ];
    final lines = <Polyline>[
      if (!_rentMode && _origin != null && _destination != null)
        Polyline(
            points: [_origin!, _destination!],
            color: Theme.of(context).colorScheme.onSurface,
            strokeWidth: 4),
      if (!_rentMode)
        ..._matches.map((item) {
          final job = item['job'] as Map<String, dynamic>;
          return Polyline(
            points: [
              LatLng((job['pickup_lat'] as num).toDouble(),
                  (job['pickup_lon'] as num).toDouble()),
              LatLng((item['suggested_dropoff_lat'] as num).toDouble(),
                  (item['suggested_dropoff_lon'] as num).toDouble()),
            ],
            color: const Color(0xFF088F8F),
            strokeWidth: 6,
          );
        }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _currentLocation ?? const LatLng(50.0755, 14.4378),
            initialZoom: 13,
            onTap: _selectPoint,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pedalshare.pedalshare',
            ),
            PolylineLayer(polylines: lines),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ],
            ),
          ],
        ),
        Positioned(top: 12, left: 12, right: 12, child: _controls()),
        if (_rentMode && _selectedBike != null)
          Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _bikeDetails(_selectedBike!)),
        if (!_rentMode && _matches.isNotEmpty)
          DraggableScrollableSheet(
            initialChildSize: .28,
            minChildSize: .16,
            maxChildSize: .65,
            builder: (_, controller) => _results(controller),
          ),
      ]),
    );
  }

  Widget _controls() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.pedal_bike),
                        label: Text('Rent')),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.swap_horiz),
                        label: Text('Move')),
                  ],
                  selected: {_rentMode},
                  onSelectionChanged: (selection) => setState(() {
                    _rentMode = selection.first;
                    _selectedBike = null;
                    _error = null;
                  }),
                )),
            const SizedBox(height: 10),
            if (_rentMode) ...[
              Row(children: [
                Expanded(
                    child: Text(
                        _loading
                            ? 'Finding bikes…'
                            : '${_bikes.length} bikes available nearby',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                    tooltip: 'Refresh bikes',
                    onPressed: _loading ? null : _loadBikes,
                    icon: const Icon(Icons.refresh)),
              ]),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ] else ...[
              Row(children: [
                _Step(number: '1', label: 'Start', active: _origin == null),
                const SizedBox(width: 8),
                _Step(
                    number: '2',
                    label: 'Destination',
                    active: _origin != null && _destination == null),
                const Spacer(),
                if (_origin != null)
                  TextButton(
                      onPressed: () => setState(() {
                            _origin = null;
                            _destination = null;
                            _matches = [];
                          }),
                      child: const Text('Reset')),
              ]),
              const SizedBox(height: 6),
              if (_origin == null)
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use current location'),
                    ))
              else if (_destination == null)
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tap your destination on the map'))
              else
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Maximum detour: ${_maxDetour.toStringAsFixed(0)} km')),
              if (_destination != null)
                Slider(
                  value: _maxDetour,
                  min: 1,
                  max: 25,
                  divisions: 24,
                  label: '${_maxDetour.round()} km',
                  onChanged: (v) => setState(() => _maxDetour = v),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_destination != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.route),
                    label: const Text('Find bikes in my direction'),
                  ),
                ),
            ],
          ]),
        ),
      );

  Marker _bikeMarker(Map<String, dynamic> bike) => Marker(
        point: LatLng((bike['current_lat'] as num).toDouble(),
            (bike['current_lon'] as num).toDouble()),
        width: 42,
        height: 42,
        child: Semantics(
          button: true,
          label: bike['title'] as String? ?? 'Available bike',
          child: GestureDetector(
            onTap: () => setState(() => _selectedBike = bike),
            child: Container(
              decoration: BoxDecoration(
                  color: _selectedBike?['id'] == bike['id']
                      ? psOrange
                      : Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: psOrange, width: 1.5)),
              child: Icon(Icons.pedal_bike,
                  size: 20,
                  color: _selectedBike?['id'] == bike['id']
                      ? Colors.white
                      : psOrange),
            ),
          ),
        ),
      );

  Widget _bikeDetails(Map<String, dynamic> bike) => Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: psOrange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.pedal_bike, color: psOrange)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bike['title'] as String? ?? 'Bike',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text('${bike['type']} · €${bike['hourly_price']}/hour',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ])),
              FilledButton(
                  onPressed: () => context.push('/bike/${bike['id']}'),
                  child: const Text('View')),
            ])),
      );

  Widget _results(ScrollController controller) => Material(
        elevation: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(16),
          itemCount: _matches.length,
          itemBuilder: (_, index) {
            final match = _matches[index] as Map<String, dynamic>;
            final job = match['job'] as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.pedal_bike)),
                title: Text(
                    'Bike #${job['bike_id']} · ${match['completion_type']}'),
                subtitle: Text('+${match['added_distance_km']} km · '
                    '${match['pickup_distance_km']} km to pickup'),
                trailing: Text('${match['estimated_reward_points']} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        ),
      );

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
        point: point,
        width: 46,
        height: 46,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Theme.of(context).dividerColor, width: 2)),
          child: Icon(icon, color: color),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.number, required this.label, required this.active});
  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF088F8F)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6)),
            child: Text(number,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]);
}
