import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _bikes = [];
  bool _loading = true;
  String? _error;
  String _selectedType = '';
  double _radius = 10.0;

  @override
  void initState() {
    super.initState();
    _loadBikes();
  }

  Future<void> _loadBikes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bikes = await ApiService.searchBikes(
        radiusKm: _radius,
        type: _selectedType.isEmpty ? null : _selectedType,
      );
      setState(() { _bikes = bikes; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚲  Browse Bikes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBikes),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Type', isDense: true),
                    items: ['', 'city', 'road', 'mountain', 'electric', 'cargo', 'folding']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.isEmpty ? 'All types' : t)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: '10',
                    decoration: const InputDecoration(labelText: 'Radius km', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _radius = double.tryParse(v) ?? 10.0,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _loadBikes, child: const Text('Go')),
              ],
            ),
          ),
          const Divider(height: 1),

          // Bike list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                    : _bikes.isEmpty
                        ? PsEmptyState(
                            icon: '🚲',
                            title: 'No bikes found',
                            subtitle: 'Try expanding your search radius',
                            action: ElevatedButton(onPressed: _loadBikes, child: const Text('Search again')),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _bikes.length,
                            itemBuilder: (_, i) => _BikeCard(
                              bike: _bikes[i],
                              onTap: () => context.push('/bike/${_bikes[i]['id']}'),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showListBikeSheet(context),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('List my bike'),
      ),
    );
  }

  void _showListBikeSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ListBikeSheet(),
    );
  }
}

class _BikeCard extends StatelessWidget {
  final Map<String, dynamic> bike;
  final VoidCallback onTap;
  const _BikeCard({required this.bike, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dist = bike['distance_from_user'] as double?;
    final rating = (bike['avg_rating'] as num?)?.toDouble() ?? 0.0;
    return PsCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo placeholder
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD1FAE5), Color(0xFF6EE7B7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: bike['photo_urls'] != null && (bike['photo_urls'] as List).isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      'http://localhost:8000${bike['photo_urls'][0]}',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Text('🚲', style: TextStyle(fontSize: 48))),
                    ),
                  )
                : const Center(child: Text('🚲', style: TextStyle(fontSize: 48))),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PsStatusChip(bike['status'] as String? ?? 'available'),
                    const SizedBox(width: 8),
                    Text('⭐ ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bike['title'] as String? ?? 'Bike',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dist != null)
                  Text('${dist.toStringAsFixed(1)} km away', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PriceTag('€${bike['hourly_price']}', '/hr'),
                    const SizedBox(width: 16),
                    _PriceTag('€${bike['daily_price']}', '/day'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String amount;
  final String unit;
  const _PriceTag(this.amount, this.unit);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: amount, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 16)),
          TextSpan(text: unit, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ListBikeSheet extends StatefulWidget {
  const _ListBikeSheet();

  @override
  State<_ListBikeSheet> createState() => _ListBikeSheetState();
}

class _ListBikeSheetState extends State<_ListBikeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'city';
  final _hourlyPrice = TextEditingController(text: '3');
  final _dailyPrice = TextEditingController(text: '18');
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('List your bike', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['city','road','mountain','electric','cargo','folding']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v ?? 'city'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _hourlyPrice, decoration: const InputDecoration(labelText: '€/hr'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _dailyPrice, decoration: const InputDecoration(labelText: '€/day'), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    await ApiService.createBike({
                      'title': _title.text,
                      'description': _desc.text,
                      'type': _type,
                      'hourly_price': double.tryParse(_hourlyPrice.text) ?? 3.0,
                      'daily_price': double.tryParse(_dailyPrice.text) ?? 18.0,
                      'deposit': 50.0,
                      'current_lat': 52.52,
                      'current_lon': 13.405,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bike listed! ✅'), backgroundColor: Color(0xFF16A34A)),
                      );
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Publish bike'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
