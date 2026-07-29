import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'active_move_screen.dart';
import 'active_rental_screen.dart';
import 'reserved_rental_screen.dart';

class RentalFlowLoader extends StatelessWidget {
  const RentalFlowLoader({required this.rentalId, super.key});
  final int rentalId;

  Future<({Map<String, dynamic> rental, Map<String, dynamic> bike})>
      _load() async {
    final rentals = await ApiService.getMyRentals();
    final rental = rentals.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['id'] == rentalId,
        orElse: () => throw ApiException('Rental not found'));
    final bike = await ApiService.getBike(rental['bike_id'] as int);
    return (rental: rental, bike: bike);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: PsEmptyState(
                  icon: '!',
                  title: 'Could not restore rental',
                  subtitle: snapshot.error.toString()));
        }
        final data = snapshot.data!;
        if (data.rental['status'] == 'pending') {
          return ReservedRentalScreen(bike: data.bike, rental: data.rental);
        }
        if (data.rental['status'] == 'active') {
          return ActiveRentalScreen(bike: data.bike, rental: data.rental);
        }
        return Scaffold(
            appBar: AppBar(),
            body: const PsEmptyState(
                icon: '', title: 'This rental is no longer active'));
      });
}

class MoveFlowLoader extends StatelessWidget {
  const MoveFlowLoader({required this.segmentId, super.key});
  final int segmentId;

  Future<({Map<String, dynamic> segment, Map<String, dynamic> job})>
      _load() async {
    final segments = await ApiService.getMyDeliveries();
    final segment = segments.cast<Map<String, dynamic>>().firstWhere(
        (item) => item['id'] == segmentId,
        orElse: () => throw ApiException('Move not found'));
    final job = await ApiService.getDeliveryJob(segment['job_id'] as int);
    return (segment: segment, job: job);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: PsEmptyState(
                  icon: '!',
                  title: 'Could not restore move',
                  subtitle: snapshot.error.toString()));
        }
        final data = snapshot.data!;
        if (data.segment['status'] != 'active') {
          return Scaffold(
              appBar: AppBar(),
              body: const PsEmptyState(
                  icon: '', title: 'This move is no longer active'));
        }
        return ActiveMoveScreen(job: data.job, segment: data.segment);
      });
}
