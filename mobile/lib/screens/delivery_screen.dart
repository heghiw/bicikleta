import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<dynamic> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final jobs = await ApiService.listOpenJobs();
      setState(() { _jobs = jobs; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(int jobId) async {
    try {
      await ApiService.acceptSegment(jobId, 52.52, 13.405);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Job accepted! Go to Profile to track your delivery.'),
          backgroundColor: Color(0xFF16A34A),
        ));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦  Delivery Jobs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const PsEmptyState(
                  icon: '📦',
                  title: 'No open jobs',
                  subtitle: 'New delivery jobs are posted daily. Check back soon!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _jobs.length,
                  itemBuilder: (_, i) => _JobCard(job: _jobs[i], onAccept: () => _accept(_jobs[i]['id'] as int)),
                ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onAccept;
  const _JobCard({required this.job, required this.onAccept});

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
                    Text('Job #${job['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${(job['distance_km'] as num).toStringAsFixed(1)} km', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text('${job['reward_points']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    const Text('pts', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
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
              ElevatedButton(
                onPressed: job['status'] == 'open' ? onAccept : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                child: const Text('Accept'),
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
  const _RouteRow({required this.fromLat, required this.fromLon, required this.toLat, required this.toLon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: const Color(0xFF16A34A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${fromLat.toStringAsFixed(3)}, ${fromLon.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: const Color(0xFFE5E7EB), style: BorderStyle.solid, width: 1)),
            ),
          ),
        ),
        _Dot(color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${toLat.toStringAsFixed(3)}, ${toLon.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
