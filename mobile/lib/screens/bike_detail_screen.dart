import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../services/api_service.dart';
import '../theme.dart';

class BikeDetailScreen extends StatefulWidget {
  final int bikeId;
  const BikeDetailScreen({required this.bikeId, super.key});

  @override
  State<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends State<BikeDetailScreen> {
  Map<String, dynamic>? _bike;
  List<dynamic> _reviews = [];
  bool _loading = true;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getBike(widget.bikeId),
        ApiService.getBikeReviews(widget.bikeId),
      ]);
      setState(() {
        _bike = results[0] as Map<String, dynamic>;
        _reviews = results[1] as List<dynamic>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _bookBike() async {
    if (_bike == null) return;
    setState(() => _booking = true);
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reserve this bike?'),
          content: Text(
              'Rate: €${_bike!['hourly_price']}/hour\nDeposit hold: €${_bike!['deposit']}\n\nThe final ride price is captured when you finish. The unused hold is released.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue to payment')),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final payment = await ApiService.createPaymentIntent(_bike!['id'] as int);
      if (payment['provider'] == 'stripe') {
        final clientSecret = payment['client_secret'] as String?;
        if (clientSecret == null ||
            const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY').isEmpty) {
          throw ApiException('Stripe payment configuration is incomplete');
        }
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Bicikleta',
            style: ThemeMode.system,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }
      final rental = await ApiService.bookBike(
        _bike!['id'] as int,
        (_bike!['current_lat'] as num).toDouble(),
        (_bike!['current_lon'] as num).toDouble(),
        payment['payment_intent_id'] as String,
      );
      if (mounted) {
        context.go('/rental/${rental['id']}');
      }
    } on StripeException catch (e) {
      if (mounted && e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.error.localizedMessage ?? 'Payment failed')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bike == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Bike not found')));
    }

    final bike = _bike!;
    final available = bike['status'] == 'available';
    final rating = (bike['avg_rating'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: bike['photo_urls'] != null &&
                      (bike['photo_urls'] as List).isNotEmpty
                  ? Image.network(
                      ApiService.assetUrl(bike['photo_urls'][0] as String),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _BikePlaceholder())
                  : const _BikePlaceholder(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    PsStatusChip(bike['status'] as String? ?? 'available'),
                    const SizedBox(width: 8),
                    Chip(label: Text(bike['type'] as String? ?? 'city')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(bike['title'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (i) => Icon(Icons.star,
                            size: 16,
                            color: i < rating.round()
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFE5E7EB))),
                    const SizedBox(width: 6),
                    Text('${rating.toStringAsFixed(1)} (${_reviews.length})',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
                if (bike['description'] != null) ...[
                  const SizedBox(height: 16),
                  Text(bike['description'] as String,
                      style: const TextStyle(
                          color: Color(0xFF374151), height: 1.6)),
                ],
                const SizedBox(height: 20),

                // Specs
                if (bike['brand'] != null || bike['frame_size'] != null)
                  _SpecRow(items: [
                    if (bike['brand'] != null)
                      _SpecItem('Brand', bike['brand'].toString()),
                    if (bike['frame_size'] != null)
                      _SpecItem('Frame', bike['frame_size'].toString()),
                  ]),

                const SizedBox(height: 16),

                // Pricing card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _PriceRow('Per hour', '€${bike['hourly_price']}'),
                        const Divider(),
                        _PriceRow('Per day', '€${bike['daily_price']}'),
                        const Divider(),
                        _PriceRow('Deposit', '€${bike['deposit']}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Reviews
                Text('Reviews (${_reviews.length})',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  const PsEmptyState(icon: '', title: 'No reviews yet')
                else
                  ..._reviews.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ...List.generate(
                                        5,
                                        (i) => Icon(Icons.star,
                                            size: 14,
                                            color: i < (r['rating'] as int)
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFE5E7EB))),
                                    const Spacer(),
                                    Text(
                                        r['created_at']
                                            .toString()
                                            .substring(0, 10),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                                if (r['comment'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(r['comment'].toString(),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: available
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _booking ? null : _bookBike,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: _booking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Book this bike',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            )
          : null,
    );
  }
}

class _BikePlaceholder extends StatelessWidget {
  const _BikePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.pedal_bike_outlined, size: 72)),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final List<_SpecItem> items;
  const _SpecRow({required this.items});
  @override
  Widget build(BuildContext context) {
    return Row(
        children: items
            .expand((item) => [
                  _SpecChip(label: item.label, value: item.value),
                  const SizedBox(width: 8),
                ])
            .toList());
  }
}

class _SpecItem {
  final String label;
  final String value;
  const _SpecItem(this.label, this.value);
}

class _SpecChip extends StatelessWidget {
  final String label;
  final String value;
  const _SpecChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String price;
  const _PriceRow(this.label, this.price);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          Text(price,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF088F8F))),
        ],
      ),
    );
  }
}
