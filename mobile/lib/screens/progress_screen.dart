import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ApiService.getGamification();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: _data == null
          ? _error != null
              ? PsEmptyState(
                  icon: '',
                  title: 'Could not load progress',
                  subtitle: _error,
                  action: FilledButton(
                      onPressed: _load, child: const Text('Try again')))
              : const Center(child: CircularProgressIndicator())
          : _content(context, _data!),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> data) {
    final xp = data['xp'] as int? ?? 0;
    final level = data['level'] as int? ?? 1;
    final rentals = data['total_rentals'] as int? ?? 0;
    final deliveries = data['total_deliveries'] as int? ?? 0;
    final km = (data['total_km'] as num?)?.toDouble() ?? 0;
    final streak = data['streak_days'] as int? ?? 0;
    final nextLevelXp = (level + 1) * (level + 1) * 4;
    final achievements = [
      _Achievement(Icons.pedal_bike_outlined, 'First ride',
          'Complete one rental', rentals >= 1),
      _Achievement(Icons.route_outlined, '100 km club', 'Ride 100 kilometres',
          km >= 100),
      _Achievement(Icons.swap_horiz, 'Bike mover', 'Complete 10 bike moves',
          deliveries >= 10),
      _Achievement(Icons.local_fire_department_outlined, 'Week streak',
          'Ride on seven consecutive days', streak >= 7),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      PsCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Level $level',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text('$xp / $nextLevelXp XP',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 14),
        LinearProgressIndicator(
            value: (xp / nextLevelXp).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 8),
        Text('${nextLevelXp - xp} XP to the next level',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      const SizedBox(height: 12),
      Text('Achievements',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ...achievements.map((item) => PsCard(
              child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: item.unlocked
                        ? psOrange.withValues(alpha: .12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(item.icon,
                    color: item.unlocked
                        ? psOrange
                        : Theme.of(context).disabledColor)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(item.description,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
            Icon(item.unlocked ? Icons.check_circle : Icons.lock_outline,
                color:
                    item.unlocked ? psOrange : Theme.of(context).disabledColor,
                size: 20),
          ]))),
      const SizedBox(height: 12),
      PsCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt, color: psOrange),
          SizedBox(width: 8),
          Expanded(
              child: Text('14-day streak bonus',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          Text('+100 pts',
              style: TextStyle(color: psOrange, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
            value: (streak / 14).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(7)),
        const SizedBox(height: 8),
        Text('$streak of 14 days',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
    ]);
  }
}

class _Achievement {
  const _Achievement(this.icon, this.title, this.description, this.unlocked);
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
}
