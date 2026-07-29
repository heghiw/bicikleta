import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/address_service.dart';
import '../services/location_service.dart';
import '../theme.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({required this.jobId, super.key});
  final int jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? _job;
  Map<String, dynamic>? _bike;
  String? _error;
  bool _loading = true;
  bool _accepting = false;
  String? _pickupAddress;
  String? _dropoffAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final job = await ApiService.getDeliveryJob(widget.jobId);
      final bike = await ApiService.getBike(job['bike_id'] as int);
      if (!mounted) return;
      setState(() {
        _job = job;
        _bike = bike;
        _loading = false;
      });
      _loadAddresses(job);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAddresses(Map<String, dynamic> job) async {
    final labels = await Future.wait([
      AddressService.label((job['pickup_lat'] as num).toDouble(),
          (job['pickup_lon'] as num).toDouble()),
      AddressService.label((job['dropoff_lat'] as num).toDouble(),
          (job['dropoff_lon'] as num).toDouble()),
    ]);
    if (!mounted) return;
    setState(() {
      _pickupAddress = labels[0];
      _dropoffAddress = labels[1];
    });
  }

  Future<void> _accept() async {
    if (_job == null || _accepting) return;
    setState(() => _accepting = true);
    try {
      final location = await LocationService.current(forceRefresh: true);
      final segment = await ApiService.acceptSegment(
        widget.jobId,
        location.latitude,
        location.longitude,
      );
      if (mounted) context.go('/move/${segment['id']}/active');
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is ApiException ? error.message : error.toString()),
      ));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Move details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? PsEmptyState(
                  icon: '!',
                  title: 'Could not load this job',
                  subtitle: _error,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                )
              : _content(),
      bottomNavigationBar: _job == null ? null : _bottomAction(),
    );
  }

  Widget _content() {
    final job = _job!;
    final pickup = LatLng(
      (job['pickup_lat'] as num).toDouble(),
      (job['pickup_lon'] as num).toDouble(),
    );
    final dropoff = LatLng(
      (job['dropoff_lat'] as num).toDouble(),
      (job['dropoff_lon'] as num).toDouble(),
    );
    final center = LatLng(
      (pickup.latitude + dropoff.latitude) / 2,
      (pickup.longitude + dropoff.longitude) / 2,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 230,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 12.5),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pedalshare.pedalshare',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [pickup, dropoff],
                    strokeWidth: 4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ]),
                MarkerLayer(markers: [
                  _marker(pickup, Icons.pedal_bike, 'Pickup'),
                  _marker(dropoff, Icons.flag, 'Drop-off'),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Text(
              _bike?['title'] as String? ?? 'Bike #${job['bike_id']}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          PsPointsBadge(job['reward_points'] as int? ?? 0),
        ]),
        const SizedBox(height: 4),
        Text(
          '${_bike?['brand'] ?? _bike?['type'] ?? 'Bike'} · Job #${job['id']}',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        PsCard(
          child: Column(children: [
            _StopRow(
              icon: Icons.my_location,
              title: 'Pick up bike',
              address: _pickupAddress,
              coordinates: _coordinates(pickup),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 19),
              child: Divider(height: 24),
            ),
            _StopRow(
              icon: Icons.flag_outlined,
              title: 'Move to destination',
              address: _dropoffAddress,
              coordinates: _coordinates(dropoff),
            ),
          ]),
        ),
        PsCard(
          child: Row(children: [
            Expanded(
                child: _Metric('DISTANCE',
                    '${(job['distance_km'] as num).toStringAsFixed(1)} km')),
            const SizedBox(height: 38, child: VerticalDivider()),
            Expanded(
                child: _Metric('LOCK',
                    _bike?['lock_type'] == 'smart' ? 'Automatic' : 'Manual')),
            const SizedBox(height: 38, child: VerticalDivider()),
            Expanded(
                child: _Metric('STATUS', (job['status'] ?? 'open').toString())),
          ]),
        ),
        const SizedBox(height: 4),
        const Text(
          'How it works',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const _Instruction(
            number: '1', text: 'Accept the move and walk to the bike.'),
        const _Instruction(
            number: '2', text: 'Scan its mandatory QR code before unlocking.'),
        const _Instruction(
            number: '3', text: 'Ride to the destination and confirm parking.'),
      ],
    );
  }

  Widget _bottomAction() {
    final open = _job!['status'] == 'open';
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: FilledButton(
          onPressed: open && !_accepting ? _accept : null,
          child: _accepting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(open ? 'Accept move' : 'Job no longer available'),
        ),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, String label) => Marker(
        point: point,
        width: 54,
        height: 54,
        child: Semantics(
          label: label,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      );

  String _coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
}

class _StopRow extends StatelessWidget {
  const _StopRow(
      {required this.icon,
      required this.title,
      required this.address,
      required this.coordinates});
  final IconData icon;
  final String title;
  final String? address;
  final String coordinates;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(address ?? 'Finding address…',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(coordinates,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(
              radius: 13,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Text(number,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSecondary))),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
