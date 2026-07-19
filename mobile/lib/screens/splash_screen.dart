import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      context.go(ApiService.isLoggedIn ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCFCE7),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚲', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text(
                'PedalShare',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rent. Ride. Earn.',
                style: TextStyle(fontSize: 16, color: Color(0xFF166534), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
