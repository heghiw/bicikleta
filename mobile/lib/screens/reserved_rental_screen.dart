import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'unlock_scanner_screen.dart';

class ReservedRentalScreen extends StatefulWidget {
  const ReservedRentalScreen(
      {required this.bike, required this.rental, super.key});
  final Map<String, dynamic> bike;
  final Map<String, dynamic> rental;
  @override
  State<ReservedRentalScreen> createState() => _ReservedRentalScreenState();
}

class _ReservedRentalScreenState extends State<ReservedRentalScreen> {
  Timer? _timer;
  late final DateTime _expiresAt;
  Duration _remaining = Duration.zero;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final created = DateTime.tryParse(widget.rental['created_at'].toString()) ??
        DateTime.now();
    _expiresAt = created.add(const Duration(minutes: 15));
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void _tick() {
    final value = _expiresAt.difference(DateTime.now());
    if (mounted) {
      setState(() => _remaining = value.isNegative ? Duration.zero : value);
    }
  }

  Future<void> _scanAndStart() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => UnlockScannerScreen(
          bikeId: widget.bike['id'] as int,
        ),
      ),
    );
    if (code == null || !mounted) return;
    setState(() => _starting = true);
    try {
      final rental =
          await ApiService.startRental(widget.rental['id'] as int, code);
      final lock = await ApiService.getRentalLock(widget.rental['id'] as int);
      if (!mounted) return;
      final smartLock = lock['lock_type'] == 'smart';
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                icon: Icon(
                    smartLock ? Icons.lock_open_outlined : Icons.key_outlined),
                title:
                    Text(smartLock ? 'Smart lock opened' : 'Unlock the bike'),
                content: Text(smartLock
                    ? 'The connected ${lock['provider'] ?? 'smart'} lock reports ready.'
                    : (lock['instructions'] as String? ??
                        'Follow the owner-provided lock instructions.')),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Start riding'))
                ],
              ));
      if (mounted) {
        context.go('/rental/${rental['id']}');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _cancel() async {
    await ApiService.cancelRental(widget.rental['id'] as int);
    if (mounted) context.go('/explore');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng((widget.bike['current_lat'] as num).toDouble(),
        (widget.bike['current_lon'] as num).toDouble());
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Bike reserved')),
      body: Column(children: [
        Expanded(
            child: FlutterMap(
                options: MapOptions(initialCenter: point, initialZoom: 16),
                children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pedalshare.pedalshare'),
              MarkerLayer(markers: [
                Marker(
                    point: point,
                    width: 52,
                    height: 52,
                    child: Container(
                        decoration: BoxDecoration(
                            color: psOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3)),
                        child:
                            const Icon(Icons.pedal_bike, color: Colors.white)))
              ]),
            ])),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text(widget.bike['title'] as String? ?? 'Reserved bike',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Reservation expires in $minutes:$seconds',
                      style: const TextStyle(
                          color: psOrange, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Go to the bike, then scan the QR code on its lock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          onPressed: _remaining == Duration.zero || _starting
                              ? null
                              : _scanAndStart,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(_starting
                              ? 'Starting…'
                              : 'Scan and start ride'))),
                  TextButton(
                      onPressed: _cancel,
                      child: const Text('Cancel reservation')),
                ]))),
      ]),
    );
  }
}
