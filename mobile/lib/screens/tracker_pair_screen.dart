import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class TrackerPairScreen extends StatefulWidget {
  const TrackerPairScreen({required this.bikeId, super.key});
  final int bikeId;

  @override
  State<TrackerPairScreen> createState() => _TrackerPairScreenState();
}

class _TrackerPairScreenState extends State<TrackerPairScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceId = TextEditingController();
  final _activationCode = TextEditingController();
  String _provider = 'generic';
  String _connection = 'rest';
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _tracker;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _activationCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tracker = await ApiService.getTracker(widget.bikeId);
      if (mounted) setState(() => _tracker = tracker);
    } on ApiException catch (error) {
      if (error.message != 'Tracker not connected' && mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pair() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tracker = await ApiService.pairTracker(widget.bikeId, {
        'provider': _provider,
        'provider_device_id': _deviceId.text.trim(),
        'connection_type': _connection,
        if (_activationCode.text.isNotEmpty)
          'activation_code': _activationCode.text,
      });
      if (mounted) setState(() => _tracker = tracker);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('GPS tracker')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_tracker != null) _statusCard() else _pairingForm(),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFB91C1C)))),
                  const SizedBox(height: 20),
                  const PsCard(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Icon(Icons.privacy_tip_outlined,
                            color: Color(0xFF2563EB)),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                'Activation codes are used only during provider validation and are not returned to the app. Live tracking remains unavailable until the provider adapter confirms the device.')),
                      ])),
                ],
              ),
      );

  Widget _statusCard() => PsCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFDBEAFE),
              child: Icon(Icons.gps_fixed, color: Color(0xFF2563EB))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text((_tracker!['provider'] as String).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_tracker!['provider_device_id'] as String,
                    style: const TextStyle(color: Color(0xFF6B7280))),
              ])),
          PsStatusChip(_tracker!['status'] as String),
        ]),
        const SizedBox(height: 16),
        const Text(
            'Waiting for provider validation. Tracking and security alerts will activate after the first authenticated position is received.'),
      ]));

  Widget _pairingForm() => Form(
        key: _formKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Connect your tracker',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
              'Select the provider printed on the device or choose Generic GPS.',
              style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: 'generic', child: Text('Generic GPS'))
            ],
            onChanged: (value) =>
                setState(() => _provider = value ?? 'generic'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deviceId,
            decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'Scan or enter the identifier'),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Enter a valid device ID'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: _activationCode,
              decoration: const InputDecoration(
                  labelText: 'Activation code (optional)'),
              obscureText: true),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _connection,
            decoration: const InputDecoration(labelText: 'Connection type'),
            items: const [
              DropdownMenuItem(value: 'rest', child: Text('Provider API')),
              DropdownMenuItem(value: 'webhook', child: Text('Webhook')),
              DropdownMenuItem(value: 'mqtt', child: Text('MQTT')),
              DropdownMenuItem(
                  value: 'tcp', child: Text('TCP device protocol')),
              DropdownMenuItem(
                  value: 'polling', child: Text('Periodic polling')),
              DropdownMenuItem(
                  value: 'gateway', child: Text('Generic gateway')),
            ],
            onChanged: (value) => setState(() => _connection = value ?? 'rest'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: _saving ? null : _pair,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Register tracker')),
        ]),
      );
}
