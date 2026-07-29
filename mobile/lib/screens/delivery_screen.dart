import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/address_service.dart';
import '../theme.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<dynamic> _jobs = [];
  bool _loading = true;
  String? _error;

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
      final jobs = await ApiService.listOpenJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open jobs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? PsEmptyState(
                  icon: '!',
                  title: 'Could not load open jobs',
                  subtitle: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('Try again')),
                )
              : _jobs.isEmpty
                  ? const PsEmptyState(
                      icon: '',
                      title: 'No open jobs',
                      subtitle: 'New bike moves are posted throughout the day.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      itemBuilder: (_, i) => _JobCard(
                        job: _jobs[i],
                        onOpen: () =>
                            context.push('/delivery/${_jobs[i]['id']}'),
                      ),
                    ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onOpen;
  const _JobCard({required this.job, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Job #${job['id']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${(job['distance_km'] as num).toStringAsFixed(1)} km',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text('${job['reward_points']}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF088F8F))),
                    const Text('pts',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF115E59))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteRow(
            fromLat: (job['pickup_lat'] as num).toDouble(),
            fromLon: (job['pickup_lon'] as num).toDouble(),
            toLat: (job['dropoff_lat'] as num).toDouble(),
            toLon: (job['dropoff_lon'] as num).toDouble(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              PsStatusChip(job['status'] as String? ?? 'open'),
              const Spacer(),
              OutlinedButton(
                onPressed: onOpen,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10)),
                child: const Text('View details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final double fromLat, fromLon, toLat, toLon;
  const _RouteRow(
      {required this.fromLat,
      required this.fromLon,
      required this.toLat,
      required this.toLon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AddressRow(
          dotColor: const Color(0xFF088F8F),
          label: 'Pickup',
          address: AddressService.label(fromLat, fromLon),
        ),
        Container(
          height: 18,
          margin: const EdgeInsets.only(left: 4),
          alignment: Alignment.centerLeft,
          child: const VerticalDivider(width: 1),
        ),
        _AddressRow(
          dotColor: const Color(0xFFEF4444),
          label: 'Drop-off',
          address: AddressService.label(toLat, toLon),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow(
      {required this.dotColor, required this.label, required this.address});
  final Color dotColor;
  final String label;
  final Future<String> address;

  @override
  Widget build(BuildContext context) => Row(children: [
        _Dot(color: dotColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: address,
            builder: (_, snapshot) => Text(
              snapshot.data ?? 'Finding address…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
