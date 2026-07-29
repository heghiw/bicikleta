import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';

class AddBikeScreen extends StatefulWidget {
  const AddBikeScreen({super.key});

  @override
  State<AddBikeScreen> createState() => _AddBikeScreenState();
}

class _AddBikeScreenState extends State<AddBikeScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _pricingKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _frameSize = TextEditingController();
  final _serial = TextEditingController();
  final _description = TextEditingController();
  final _hourly = TextEditingController(text: '4');
  final _daily = TextEditingController(text: '24');
  final _deposit = TextEditingController(text: '80');
  final _lockInstructions = TextEditingController();
  final _smartLockDevice = TextEditingController();
  final _picker = ImagePicker();

  int _step = 0;
  String _type = 'city';
  String _lockType = 'manual';
  File? _mainPhoto;
  bool _publishForRent = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _model,
      _color,
      _frameSize,
      _serial,
      _description,
      _hourly,
      _daily,
      _deposit,
      _lockInstructions,
      _smartLockDevice
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (photo != null && mounted) setState(() => _mainPhoto = File(photo.path));
  }

  void _continue() {
    if (_step == 0 && !_detailsKey.currentState!.validate()) return;
    if (_step == 1 && _mainPhoto == null) {
      setState(() => _error = 'Add a clear main photo before continuing.');
      return;
    }
    if (_step == 2 && !_pricingKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _step += 1;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final location = await LocationService.current(forceRefresh: true);
      final bike = await ApiService.createBike({
        'title': _name.text.trim(),
        'description': [
          if (_model.text.trim().isNotEmpty) 'Model: ${_model.text.trim()}',
          if (_color.text.trim().isNotEmpty) 'Color: ${_color.text.trim()}',
          if (_serial.text.trim().isNotEmpty) 'Serial: ${_serial.text.trim()}',
          if (_description.text.trim().isNotEmpty) _description.text.trim(),
        ].join('\n'),
        'type': _type,
        'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        'frame_size':
            _frameSize.text.trim().isEmpty ? null : _frameSize.text.trim(),
        'hourly_price': _publishForRent ? double.parse(_hourly.text) : 0,
        'daily_price': _publishForRent ? double.parse(_daily.text) : 0,
        'deposit': _publishForRent ? double.parse(_deposit.text) : 0,
        'current_lat': location.latitude,
        'current_lon': location.longitude,
        'lock_type': _lockType,
        'lock_instructions':
            _lockType == 'manual' ? _lockInstructions.text.trim() : null,
        'smart_lock_provider': _lockType == 'smart' ? 'demo' : null,
        'smart_lock_device_id':
            _lockType == 'smart' ? _smartLockDevice.text.trim() : null,
      });
      await ApiService.uploadBikePhotos(bike['id'] as int, [_mainPhoto!]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bike registered successfully.')));
      context.pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() =>
            _error = error is ApiException ? error.message : error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add a bike')),
        body: Stepper(
          currentStep: _step,
          onStepTapped: (step) {
            if (step < _step) setState(() => _step = step);
          },
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : (_step == 3 ? _save : _continue),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_step == 3 ? 'Register bike' : 'Continue'),
                ),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 10),
                TextButton(
                    onPressed:
                        _saving ? null : () => setState(() => _step -= 1),
                    child: const Text('Back')),
              ],
            ]),
          ),
          steps: [
            Step(
              title: const Text('Bike details'),
              isActive: _step >= 0,
              content: Form(
                key: _detailsKey,
                child: Column(children: [
                  _field(_name, 'Bike name', required: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Bike type'),
                    items: const [
                      'city',
                      'road',
                      'mountain',
                      'gravel',
                      'electric',
                      'cargo',
                      'folding',
                      'other'
                    ]
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _type = value ?? 'city'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_brand, 'Brand')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_model, 'Model'))
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_color, 'Color')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_frameSize, 'Frame size'))
                  ]),
                  const SizedBox(height: 12),
                  _field(_serial, 'Serial number'),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      minLines: 2,
                      maxLines: 4),
                ]),
              ),
            ),
            Step(
              title: const Text('Main photo'),
              isActive: _step >= 1,
              content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: InkWell(
                        onTap: _pickPhoto,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                              image: _mainPhoto == null
                                  ? null
                                  : DecorationImage(
                                      image: FileImage(_mainPhoto!),
                                      fit: BoxFit.cover)),
                          child: _mainPhoto == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 40),
                                      SizedBox(height: 8),
                                      Text('Choose main photo')
                                    ])
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Use a well-lit photo showing the whole bicycle.',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ]),
            ),
            Step(
              title: const Text('Rental settings'),
              isActive: _step >= 2,
              content: Form(
                key: _pricingKey,
                child: Column(children: [
                  SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('List this bike for rent'),
                      value: _publishForRent,
                      onChanged: (value) =>
                          setState(() => _publishForRent = value)),
                  if (_publishForRent) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _numberField(_hourly, 'Hourly price (€)')),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField(_daily, 'Daily price (€)'))
                    ]),
                    const SizedBox(height: 12),
                    _numberField(_deposit, 'Security deposit (€)'),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'manual',
                            icon: Icon(Icons.key_outlined),
                            label: Text('My lock')),
                        ButtonSegment(
                            value: 'smart',
                            icon: Icon(Icons.lock_open_outlined),
                            label: Text('Smart lock')),
                      ],
                      selected: {_lockType},
                      onSelectionChanged: (value) =>
                          setState(() => _lockType = value.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lockType == 'smart'
                          ? 'Connect a supported automatic lock after registration.'
                          : 'You provide and manage the physical lock for this bike.',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    if (_lockType == 'manual')
                      TextFormField(
                        controller: _lockInstructions,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Lock instructions',
                            hintText:
                                'Where the key or combination is provided'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Add instructions for the renter'
                                : null,
                      )
                    else
                      TextFormField(
                        controller: _smartLockDevice,
                        decoration: const InputDecoration(
                            labelText: 'Smart-lock device ID'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter the lock device ID'
                                : null,
                      ),
                  ],
                ]),
              ),
            ),
            Step(
              title: const Text('Review'),
              isActive: _step >= 3,
              content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.pedal_bike),
                        title: Text(_name.text),
                        subtitle: Text(
                            '${_brand.text} · $_type · ${_frameSize.text}')),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sell_outlined),
                        title: Text(_publishForRent
                            ? 'Listed for rent'
                            : 'Private bike'),
                        subtitle: _publishForRent
                            ? Text(
                                '€${_hourly.text}/hour · €${_daily.text}/day · €${_deposit.text} deposit')
                            : null),
                    const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.gps_fixed),
                        title: Text(
                            'Tracker can be connected after registration')),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: Color(0xFFB91C1C)))),
                  ]),
            ),
          ],
        ),
      );

  TextFormField _field(TextEditingController controller, String label,
          {bool required = false}) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null
            : null,
        textInputAction: TextInputAction.next,
      );

  TextFormField _numberField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          return parsed == null || parsed < 0 ? 'Enter a valid amount' : null;
        },
      );
}
