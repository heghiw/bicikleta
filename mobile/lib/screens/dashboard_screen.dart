import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../services/location_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _bikes = const [];
  List<dynamic> _tasks = const [];
  Map<String, dynamic>? _activeSegment;
  Map<String, dynamic>? _activeJob;
  Map<String, dynamic>? _currentRental;
  String? _error;
  bool _loading = true;

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
      final location = await LocationService.current();
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.searchBikes(
            userLat: location.latitude,
            userLon: location.longitude,
            radiusKm: 10),
        ApiService.listOpenJobs(),
        ApiService.getMyDeliveries(),
        ApiService.getMyRentals(),
      ]);
      if (!mounted) return;
      final segments = results[3] as List<dynamic>;
      final active = segments
          .cast<Map<String, dynamic>?>()
          .whereType<Map<String, dynamic>>()
          .where((segment) => segment['status'] == 'active')
          .firstOrNull;
      Map<String, dynamic>? activeJob;
      if (active != null) {
        activeJob = await ApiService.getDeliveryJob(active['job_id'] as int);
        if (!mounted) return;
      }
      final currentRental = (results[4] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((rental) =>
              rental['status'] == 'pending' || rental['status'] == 'active')
          .firstOrNull;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _bikes = results[1] as List<dynamic>;
        _tasks = results[2] as List<dynamic>;
        _activeSegment = active;
        _activeJob = activeJob;
        _currentRental = currentRental;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.isUnauthorized) {
        context.go('/login');
        return;
      }
      setState(() {
        _error = error is ApiException ? error.message : error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bicikleta'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Notifications are coming in the next milestone.')),
            ),
            icon: const Badge(
                smallSize: 7, child: Icon(Icons.notifications_outlined)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .7,
                      child: PsEmptyState(
                        icon: '!',
                        title: 'Could not load your dashboard',
                        subtitle: _error,
                        action: ElevatedButton(
                            onPressed: _load, child: const Text('Try again')),
                      ),
                    ),
                  ])
                : _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final name = (_profile?['name'] as String?)?.split(' ').first ?? 'Rider';
    final points = _profile?['points_balance'] as int? ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_currentRental != null) ...[
          PsCard(
            onTap: () => context.push('/rental/${_currentRental!['id']}'),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: psOrange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                      _currentRental!['status'] == 'active'
                          ? Icons.navigation
                          : Icons.timer_outlined,
                      color: psOrange)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      _currentRental!['status'] == 'active'
                          ? 'Ride in progress'
                          : 'Bike reserved',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              const Text('Resume',
                  style:
                      TextStyle(color: psOrange, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right, color: psOrange),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        if (_activeSegment != null && _activeJob != null) ...[
          PsCard(
            onTap: () => context.push('/move/${_activeSegment!['id']}/active'),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: psOrange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.navigation, color: psOrange)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Move in progress',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Tap to return to the journey',
                        style: TextStyle(fontSize: 12))
                  ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        Text('Good morning, $name',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Row(children: [
          Icon(Icons.location_on_outlined, size: 16),
          SizedBox(width: 4),
          Text('Current location')
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: psOrange, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium_outlined,
                color: psOrange, size: 28),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('PLAYER BALANCE',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  Text('$points pts',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                ])),
            TextButton(
                onPressed: () => context.push('/shop'),
                child: const Text('Rewards')),
          ]),
        ),
        const SizedBox(height: 22),
        Text('Quick actions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          _Action(
              icon: Icons.pedal_bike,
              label: 'Rent',
              onTap: () => context.go('/explore')),
          _Action(
              icon: Icons.local_shipping_outlined,
              label: 'Move',
              onTap: () => context.push('/delivery')),
          _Action(
              icon: Icons.add_circle_outline,
              label: 'Add bike',
              onTap: () => context.go('/my-bikes')),
          _Action(
              icon: Icons.gps_fixed,
              label: 'Track',
              onTap: () => context.go('/my-bikes')),
        ]),
        const SizedBox(height: 24),
        _SectionHeader(
            title: 'Bikes near you', onTap: () => context.go('/explore')),
        const SizedBox(height: 8),
        if (_bikes.isEmpty)
          const PsCard(child: Text('No nearby bikes found. Pull to refresh.'))
        else
          ..._bikes.take(3).map((bike) => PsCard(
                onTap: () => context.push('/bike/${bike['id']}'),
                child: Row(children: [
                  const CircleAvatar(child: Icon(Icons.pedal_bike)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(bike['title'] as String? ?? 'Bike',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('€${bike['hourly_price']}/hr',
                      style: const TextStyle(
                          color: Color(0xFF088F8F),
                          fontWeight: FontWeight.w800)),
                ]),
              )),
        const SizedBox(height: 16),
        _SectionHeader(
            title: 'Open moves', onTap: () => context.push('/delivery')),
        const SizedBox(height: 8),
        if (_tasks.isEmpty)
          const PsCard(child: Text('No open bike moves nearby.'))
        else
          ..._tasks.take(2).map((task) => PsCard(
                onTap: () => context.push('/delivery'),
                child: Row(children: [
                  const CircleAvatar(
                      backgroundColor: Color(0xFFCCFBF1),
                      child: Icon(Icons.inventory_2_outlined,
                          color: Color(0xFF0F766E))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Move #${task['id']}',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  PsPointsBadge(task['reward_points'] as int? ?? 0),
                ]),
              )),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: psOrange)),
                const SizedBox(height: 7),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
        TextButton(onPressed: onTap, child: const Text('See all')),
      ]);
}
