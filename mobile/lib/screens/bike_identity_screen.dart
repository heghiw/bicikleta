import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../theme.dart';

class BikeIdentityScreen extends StatefulWidget {
  const BikeIdentityScreen({required this.bikeId, super.key});
  final int bikeId;

  @override
  State<BikeIdentityScreen> createState() => _BikeIdentityScreenState();
}

class _BikeIdentityScreenState extends State<BikeIdentityScreen> {
  Map<String, dynamic>? _identity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final identity = await ApiService.getBikeIdentity(widget.bikeId);
    if (mounted) {
      setState(() {
        _identity = identity;
        _loading = false;
      });
    }
  }

  Future<void> _shareLabel() async {
    final value = _identity!['identity_qr'] as String;
    final painter = QrPainter(
      data: value,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    );
    final data =
        await painter.toImageData(1200, format: ui.ImageByteFormat.png);
    if (data == null) return;
    final file = File(
        '${(await getTemporaryDirectory()).path}/bicikleta-${widget.bikeId}-qr.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Bicikleta bike #${widget.bikeId} identity label',
    ));
  }

  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Replace QR identity?'),
              content: const Text(
                  'The current printed label will stop working immediately.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Replace')),
              ],
            ));
    if (confirmed != true) return;
    final identity = await ApiService.rotateBikeIdentity(widget.bikeId);
    if (mounted) setState(() => _identity = identity);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bike QR label')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(24), children: [
                PsCard(
                    child: Column(children: [
                  const Text('BICIKLETA',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text('Bike #${widget.bikeId}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                          data: _identity!['identity_qr'] as String,
                          size: 230)),
                  const SizedBox(height: 14),
                  const Text('Scan in the Bicikleta app to identify this bike.',
                      textAlign: TextAlign.center),
                ])),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: _shareLabel,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Download or print label')),
                TextButton.icon(
                    onPressed: _rotate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Replace damaged or lost label')),
              ]),
      );
}
