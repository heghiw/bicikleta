import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bike_detail_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const PedalShareApp());
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = ApiService.isLoggedIn;
    final onAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    final onSplash = state.matchedLocation == '/';
    if (onSplash) return null;
    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const AuthScreen(isLogin: true)),
    GoRoute(path: '/register', builder: (_, __) => const AuthScreen(isLogin: false)),
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/bike/:id',
          builder: (_, state) => BikeDetailScreen(bikeId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(path: '/delivery', builder: (_, __) => const DeliveryScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
      ],
    ),
  ],
);

class PedalShareApp extends StatelessWidget {
  const PedalShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PedalShare',
      theme: buildTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({required this.child, super.key});

  static int _indexFromLocation(String loc) {
    if (loc.startsWith('/delivery')) return 1;
    if (loc.startsWith('/shop')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexFromLocation(loc),
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home'); break;
            case 1: context.go('/delivery'); break;
            case 2: context.go('/shop'); break;
            case 3: context.go('/profile'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_bike), label: 'Bikes'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Deliver'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard_outlined), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
