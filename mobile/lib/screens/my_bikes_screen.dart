import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../theme.dart';

class MyBikesScreen extends StatefulWidget {
  const MyBikesScreen({super.key});

  @override
  State<MyBikesScreen> createState() => _MyBikesScreenState();
}

class _MyBikesScreenState extends State<MyBikesScreen> {
  late Future<List<dynamic>> _bikes;

  @override
  void initState() {
    super.initState();
    _bikes = ApiService.getMyBikes();
  }

  void _reload() => setState(() => _bikes = ApiService.getMyBikes());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Bikes')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await context.push<bool>('/my-bikes/add');
            if (created == true) _reload();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add bike'),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _bikes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return PsEmptyState(
                  icon: '!',
                  title: 'Could not load your bikes',
                  subtitle: snapshot.error.toString(),
                  action: ElevatedButton(
                      onPressed: _reload, child: const Text('Try again')));
            }
            final bikes = snapshot.data ?? const [];
            if (bikes.isEmpty) {
              return const PsEmptyState(
                  icon: '+',
                  title: 'Add your first bike',
                  subtitle:
                      'Register a bicycle, connect its tracker, and choose whether to list it.');
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bikes.length,
                itemBuilder: (context, index) {
                  final bike = bikes[index] as Map<String, dynamic>;
                  return PsCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          const CircleAvatar(
                              radius: 25, child: Icon(Icons.pedal_bike)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(bike['title'] as String? ?? 'Bike',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                                Text(
                                    bike['brand'] as String? ??
                                        bike['type']?.toString() ??
                                        '',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280))),
                              ])),
                          PsStatusChip(
                              bike['status'] as String? ?? 'available'),
                        ]),
                        const SizedBox(height: 14),
                        const Row(children: [
                          Icon(Icons.gps_fixed,
                              size: 17, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text('Tracker setup required',
                              style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600))
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () => context
                                      .push('/my-bikes/${bike['id']}/identity'),
                                  icon: const Icon(Icons.qr_code_2),
                                  label: const Text('QR label'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () => context
                                      .push('/my-bikes/${bike['id']}/tracker'),
                                  icon: const Icon(Icons.gps_fixed),
                                  label: const Text('Tracker'))),
                        ]),
                      ]));
                },
              ),
            );
          },
        ),
      );
}
