import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _gamification;
  List<dynamic> _rentals = [];
  List<dynamic> _deliveries = [];
  List<dynamic> _ledger = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getGamification(),
        ApiService.getMyRentals(),
        ApiService.getMyDeliveries(),
        ApiService.getPointLedger(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as Map<String, dynamic>;
        _gamification = results[1] as Map<String, dynamic>;
        _rentals = results[2] as List<dynamic>;
        _deliveries = results[3] as List<dynamic>;
        _ledger = results[4] as List<dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        context.go('/login');
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _user?['name'] as String? ?? '');
    final email = TextEditingController(text: _user?['email'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Text('Edit profile',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                style: const TextStyle(fontSize: 16, height: 1.2),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(fontSize: 12),
                  floatingLabelStyle: TextStyle(fontSize: 12),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 16, height: 1.2),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(fontSize: 12),
                  floatingLabelStyle: TextStyle(fontSize: 12),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                ),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(fontSize: 14))),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        final updated = await ApiService.updateProfile(
            name: name.text.trim(), email: email.text.trim());
        if (mounted) {
          setState(() => _user = updated);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profile updated')));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    name.dispose();
    email.dispose();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _user == null || _gamification == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: PsEmptyState(
          icon: '!',
          title: 'Could not load your profile',
          subtitle: _error,
          action:
              FilledButton(onPressed: _load, child: const Text('Try again')),
        ),
      );
    }

    final user = _user!;
    final g = _gamification!;
    final xp = g['xp'] as int? ?? 0;
    final level = g['level'] as int? ?? 1;
    final xpNext = (level + 1) * (level + 1) * 4.0;
    final xpPct = (xp / xpNext).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Profile menu',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              if (value == 'edit') await _editProfile();
              if (value == 'theme') {
                if (!context.mounted) return;
                await ThemeController.setMode(
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark);
              }
              if (value == 'logout') {
                await ApiService.logout();
                if (context.mounted) context.go('/login');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit profile')),
              PopupMenuItem(value: 'theme', child: Text('Switch theme')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: psOrange,
                        child: Text(
                          (user['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] as String? ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                            Text(user['email'] as String? ?? '',
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 13)),
                            const SizedBox(height: 6),
                            user['verified'] == true
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: psOrange.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Text('Verified account',
                                        style: TextStyle(
                                            color: psOrange,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius:
                                            BorderRadius.circular(999)),
                                    child: const Text('Pending verification',
                                        style: TextStyle(
                                            color: Color(0xFF92400E),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
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
                      Text('Level $level',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('$xp XP',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: xpPct,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: psOrange,
                      minHeight: 8,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats grid
                  GridView(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 96,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(Icons.bolt_outlined,
                          '${user['points_balance'] ?? 0}', 'Points'),
                      _StatCard(Icons.pedal_bike_outlined,
                          '${g['total_rentals'] ?? 0}', 'Rentals'),
                      _StatCard(Icons.swap_horiz,
                          '${g['total_deliveries'] ?? 0}', 'Moves'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/progress'),
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: const Text('Progress'),
                      ),
                    ),
                  ]),
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
                  Tab(text: 'Moves (${_deliveries.length})'),
                  Tab(text: 'Points (${_ledger.length})'),
                ],
                labelColor: psOrange,
                indicatorColor: psOrange,
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

// Kept temporarily for compatibility with older saved profile states.
// ignore: unused_element
class _Achievements extends StatelessWidget {
  const _Achievements({required this.gamification});
  final Map<String, dynamic> gamification;

  @override
  Widget build(BuildContext context) {
    final rentals = gamification['total_rentals'] as int? ?? 0;
    final deliveries = gamification['total_deliveries'] as int? ?? 0;
    final km = (gamification['total_km'] as num?)?.toDouble() ?? 0;
    final streak = gamification['streak_days'] as int? ?? 0;
    final badges = [
      (Icons.pedal_bike_outlined, 'First ride', rentals >= 1),
      (Icons.route_outlined, '100 km club', km >= 100),
      (Icons.local_shipping_outlined, 'Bike mover', deliveries >= 10),
      (Icons.local_fire_department_outlined, '7-day streak', streak >= 7),
    ];
    final nextTarget = streak < 7 ? 7 : 14;
    final progress = (streak / nextTarget).clamp(0.0, 1.0);
    return Column(children: [
      SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: badges.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final badge = badges[index];
            return Container(
              width: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: badge.$3
                    ? psOrange.withValues(alpha: .10)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: badge.$3
                        ? psOrange.withValues(alpha: .4)
                        : Theme.of(context).dividerColor),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(badge.$1,
                        size: 20,
                        color: badge.$3
                            ? psOrange
                            : Theme.of(context).disabledColor),
                    const Spacer(),
                    Text(badge.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badge.$3
                                ? null
                                : Theme.of(context).disabledColor)),
                  ]),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.bolt, size: 18, color: psOrange),
            const SizedBox(width: 8),
            Expanded(
                child: Text('$nextTarget-day streak bonus',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const Text('+100 pts',
                style: TextStyle(color: psOrange, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 6),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('$streak of $nextTarget days',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ]),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _StatCard(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor)),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: psOrange),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11)),
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
    if (rentals.isEmpty) {
      return const PsEmptyState(
          icon: '',
          title: 'No rentals yet',
          subtitle: 'Browse bikes to start riding');
    }
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
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rental #${r['id']} — Bike #${r['bike_id']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(r['created_at'].toString().substring(0, 10),
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 12)),
                        ]),
                  ),
                  if ((r['total_price'] as num?) != null &&
                      r['total_price'] != 0)
                    Text('€${(r['total_price'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  PsStatusChip(r['status'] as String? ?? 'pending'),
                ],
              ),
              if (r['status'] == 'pending') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ctx.push('/rental/${r['id']}');
                        onRefresh();
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text(e.message)));
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
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text(e.message)));
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
                      await ctx.push('/rental/${r['id']}');
                      onRefresh();
                    } on ApiException catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Resume ride'),
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
    if (deliveries.isEmpty) {
      return const PsEmptyState(
          icon: '',
          title: 'No deliveries yet',
          subtitle: 'Browse open bike moves to earn points');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (ctx, i) {
        final d = deliveries[i];
        return PsCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Segment #${d['id']} — Job #${d['job_id']}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${(d['distance_km'] as num).toStringAsFixed(2)} km',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ])),
              PsPointsBadge(d['earned_points'] as int? ?? 0),
              const SizedBox(width: 8),
              PsStatusChip(d['status'] as String? ?? 'active'),
            ]),
            if (d['status'] == 'active') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ctx.push('/move/${d['id']}/active');
                    onRefresh();
                  },
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Resume move'),
                ),
              ),
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
    if (ledger.isEmpty) {
      return const PsEmptyState(icon: '', title: 'No transactions yet');
    }
    final reversed = ledger.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reversed.length,
      itemBuilder: (_, i) {
        final t = reversed[i];
        final amount = t['amount'] as int? ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: amount >= 0
                    ? const Color(0xFFCCFBF1)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                  child: Text(amount >= 0 ? '↑' : '↓',
                      style: TextStyle(
                          color: amount >= 0
                              ? const Color(0xFF088F8F)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t['description'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(t['created_at'].toString().substring(0, 10),
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                ])),
            Text(
              '${amount >= 0 ? '+' : ''}$amount pts',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: amount >= 0
                      ? const Color(0xFF088F8F)
                      : const Color(0xFFEF4444)),
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: Theme.of(context).colorScheme.surface, child: tabBar);
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
