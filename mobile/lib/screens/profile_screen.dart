import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _gamification;
  List<dynamic> _rentals = [];
  List<dynamic> _deliveries = [];
  List<dynamic> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getGamification(),
        ApiService.getMyRentals(),
        ApiService.getMyDeliveries(),
        ApiService.getPointLedger(),
      ]);
      setState(() {
        _user = results[0] as Map<String, dynamic>;
        _gamification = results[1] as Map<String, dynamic>;
        _rentals = results[2] as List<dynamic>;
        _deliveries = results[3] as List<dynamic>;
        _ledger = results[4] as List<dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = _user!;
    final g = _gamification!;
    final xp = g['xp'] as int? ?? 0;
    final level = g['level'] as int? ?? 1;
    final xpNext = (level + 1) * (level + 1) * 4.0;
    final xpPct = (xp / xpNext).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('👤  Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await ApiService.logout();
              if (mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFf0fdf4), Color(0xFFdcfce7)]),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF16A34A),
                        child: Text(
                          (user['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            Text(user['email'] as String? ?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                            const SizedBox(height: 6),
                            user['verified'] == true
                                ? const PsStatusChip('available')  // reuse with 'Available' label
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(999)),
                                    child: const Text('Pending verification', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // XP bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Level $level', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('$xp XP', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: xpPct,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: const Color(0xFF16A34A),
                      minHeight: 8,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.4,
                    children: [
                      _StatCard('🌿', '${user['points_balance'] ?? 0}', 'Points'),
                      _StatCard('🚲', '${g['total_rentals'] ?? 0}', 'Rentals'),
                      _StatCard('📦', '${g['total_deliveries'] ?? 0}', 'Deliveries'),
                      _StatCard('🛣️', '${(g['total_km'] as num?)?.toStringAsFixed(0) ?? 0}', 'km ridden'),
                      _StatCard('🌍', '${(g['co2_saved_kg'] as num?)?.toStringAsFixed(1) ?? 0}', 'kg CO₂'),
                      _StatCard('🔥', '${g['streak_days'] ?? 0}', 'Day streak'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'Rentals (${_rentals.length})'),
                  Tab(text: 'Deliveries (${_deliveries.length})'),
                  Tab(text: 'Points (${_ledger.length})'),
                ],
                labelColor: const Color(0xFF16A34A),
                indicatorColor: const Color(0xFF16A34A),
                unselectedLabelColor: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _RentalsList(rentals: _rentals, onRefresh: _load),
            _DeliveriesList(deliveries: _deliveries, onRefresh: _load),
            _LedgerList(ledger: _ledger),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, value, label;
  const _StatCard(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ]),
    );
  }
}

class _RentalsList extends StatelessWidget {
  final List<dynamic> rentals;
  final VoidCallback onRefresh;
  const _RentalsList({required this.rentals, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (rentals.isEmpty) return const PsEmptyState(icon: '🚲', title: 'No rentals yet', subtitle: 'Browse bikes to start riding');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rentals.length,
      itemBuilder: (ctx, i) {
        final r = rentals[i];
        return PsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Rental #${r['id']} — Bike #${r['bike_id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(r['created_at'].toString().substring(0, 10), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                    ]),
                  ),
                  if ((r['total_price'] as num?) != null && r['total_price'] != 0)
                    Text('€${(r['total_price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  PsStatusChip(r['status'] as String? ?? 'pending'),
                ],
              ),
              if (r['status'] == 'pending') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ApiService.startRental(r['id'] as int);
                        onRefresh();
                      } on ApiException catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    child: const Text('Start rental'),
                  )),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await ApiService.cancelRental(r['id'] as int);
                        onRefresh();
                      } on ApiException catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    child: const Text('Cancel'),
                  ),
                ]),
              ],
              if (r['status'] == 'active') ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.endRental(r['id'] as int, 52.52, 13.405);
                      onRefresh();
                    } on ApiException catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Return bike'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DeliveriesList extends StatelessWidget {
  final List<dynamic> deliveries;
  final VoidCallback onRefresh;
  const _DeliveriesList({required this.deliveries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) return const PsEmptyState(icon: '📦', title: 'No deliveries yet', subtitle: 'Browse delivery jobs to earn points');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (ctx, i) {
        final d = deliveries[i];
        return PsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Segment #${d['id']} — Job #${d['job_id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${(d['distance_km'] as num).toStringAsFixed(2)} km', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ])),
              PsPointsBadge(d['earned_points'] as int? ?? 0),
              const SizedBox(width: 8),
              PsStatusChip(d['status'] as String? ?? 'active'),
            ]),
            if (d['status'] == 'active') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.completeSegment(d['id'] as int, 52.52, 13.405);
                      onRefresh();
                    } on ApiException catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  child: const Text('Complete'),
                )),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ApiService.completeSegment(d['id'] as int, 52.52, 13.405, relay: true);
                      onRefresh();
                    } on ApiException catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  child: const Text('Relay drop'),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

class _LedgerList extends StatelessWidget {
  final List<dynamic> ledger;
  const _LedgerList({required this.ledger});

  @override
  Widget build(BuildContext context) {
    if (ledger.isEmpty) return const PsEmptyState(icon: '🌿', title: 'No transactions yet');
    final reversed = ledger.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reversed.length,
      itemBuilder: (_, i) {
        final t = reversed[i];
        final amount = t['amount'] as int? ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: amount >= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(amount >= 0 ? '↑' : '↓', style: TextStyle(color: amount >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444), fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['description'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(t['created_at'].toString().substring(0, 10), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ])),
            Text(
              '${amount >= 0 ? '+' : ''}$amount pts',
              style: TextStyle(fontWeight: FontWeight.w700, color: amount >= 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
            ),
          ]),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }
  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
