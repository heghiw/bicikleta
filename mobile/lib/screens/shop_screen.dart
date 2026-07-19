import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<dynamic> _offers = [];
  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([ApiService.listOffers(), ApiService.getProfile()]);
      setState(() {
        _offers = results[0] as List<dynamic>;
        _balance = (results[1] as Map<String, dynamic>)['points_balance'] as int? ?? 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _loading = false);
    }
  }

  Future<void> _redeem(int offerId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm redemption'),
        content: Text('Redeem "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Redeem')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final result = await ApiService.redeemOffer(offerId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('🎉 Redeemed!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your discount code:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                  child: SelectableText(
                    result['discount_code'] as String? ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF166534), letterSpacing: 2),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Copy and use at checkout.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
          ),
        );
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
        title: const Text('🎁  Rewards Shop'),
        actions: [
          PsPointsBadge(_balance),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? const PsEmptyState(icon: '🏪', title: 'No offers yet', subtitle: 'Partner offers are coming soon!')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offers.length,
                  itemBuilder: (_, i) => _OfferCard(
                    offer: _offers[i],
                    canAfford: _balance >= (_offers[i]['points_cost'] as int? ?? 0),
                    onRedeem: () => _redeem(_offers[i]['id'] as int, _offers[i]['title'] as String? ?? ''),
                  ),
                ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final bool canAfford;
  final VoidCallback onRedeem;
  const _OfferCard({required this.offer, required this.canAfford, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (offer['partner_name'] as String? ?? '').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Text(offer['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
              if (offer['quantity'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                  child: Text('${offer['quantity']} left', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            offer['description'] as String? ?? '',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${offer['points_cost']} pts',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: canAfford ? onRedeem : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
                  foregroundColor: canAfford ? Colors.white : const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(canAfford ? 'Redeem' : 'Need more pts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
