import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';

class UnlockScannerScreen extends StatefulWidget {
  const UnlockScannerScreen({required this.bikeId, super.key});
  final int bikeId;

  @override
  State<UnlockScannerScreen> createState() => _UnlockScannerScreenState();
}

class _UnlockScannerScreenState extends State<UnlockScannerScreen> {
  static const _demoMode = bool.fromEnvironment('DEMO_MODE');
  final MobileScannerController _scanner = MobileScannerController();
  bool _handled = false;

  void _returnCode(String? value) {
    final code = value?.trim();
    if (_handled || code == null || code.isEmpty) return;
    _handled = true;
    _scanner.stop();
    Navigator.pop(context, code);
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter QR identity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Bike QR identity',
            hintText: 'BICI:bike:version:signature',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    _returnCode(code);
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Unlock bike'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Flash',
            onPressed: _scanner.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _scanner,
          onDetect: (capture) {
            if (capture.barcodes.isNotEmpty) {
              _returnCode(capture.barcodes.first.rawValue);
            }
          },
        ),
        Center(
          child: Container(
            width: 246,
            height: 246,
            decoration: BoxDecoration(
              border: Border.all(color: psOrange, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Column(children: [
            const Text('Point the camera at the QR code on the bike lock.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            if (_demoMode)
              OutlinedButton.icon(
                onPressed: _enterCode,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54)),
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Enter test identity'),
              ),
          ]),
        ),
      ]),
    );
  }
}
