import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/route_match_screen.dart';
import 'screens/my_bikes_screen.dart';
import 'screens/add_bike_screen.dart';
import 'screens/tracker_pair_screen.dart';
import 'screens/bike_detail_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/bike_identity_screen.dart';
import 'screens/flow_loader_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const stripeKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    await Stripe.instance.applySettings();
  }
  await Future.wait([ApiService.init(), ThemeController.init()]);
  runApp(const PedalShareApp());
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = ApiService.isLoggedIn;
    final onAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    final onSplash = state.matchedLocation == '/';
    if (onSplash) return null;
    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(
        path: '/login', builder: (_, __) => const AuthScreen(isLogin: true)),
    GoRoute(
        path: '/register',
        builder: (_, __) => const AuthScreen(isLogin: false)),
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(
            path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/explore', builder: (_, __) => const RouteMatchScreen()),
        GoRoute(path: '/my-bikes', builder: (_, __) => const MyBikesScreen()),
        GoRoute(
            path: '/my-bikes/add', builder: (_, __) => const AddBikeScreen()),
        GoRoute(
          path: '/my-bikes/:id/tracker',
          builder: (_, state) =>
              TrackerPairScreen(bikeId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/my-bikes/:id/identity',
          builder: (_, state) => BikeIdentityScreen(
              bikeId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/bike/:id',
          builder: (_, state) =>
              BikeDetailScreen(bikeId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(path: '/delivery', builder: (_, __) => const DeliveryScreen()),
        GoRoute(
          path: '/delivery/:id',
          builder: (_, state) =>
              JobDetailScreen(jobId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
        GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
        GoRoute(
          path: '/move/:id/active',
          builder: (_, state) =>
              MoveFlowLoader(segmentId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/rental/:id',
          builder: (_, state) => RentalFlowLoader(
              rentalId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    ),
  ],
);

class PedalShareApp extends StatelessWidget {
  const PedalShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (_, mode, __) => MaterialApp.router(
        title: 'Bicikleta',
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({required this.child, super.key});

  static int _indexFromLocation(String loc) {
    if (loc.startsWith('/explore') || loc.startsWith('/bike/')) {
      return 1;
    }
    if (loc.startsWith('/rental/')) return 1;
    if (loc.startsWith('/delivery') || loc.startsWith('/move/')) return 2;
    if (loc.startsWith('/my-bikes')) return 3;
    if (loc.startsWith('/profile') ||
        loc.startsWith('/shop') ||
        loc.startsWith('/progress')) {
      return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFromLocation(loc),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/explore');
              break;
            case 2:
              context.go('/delivery');
              break;
            case 3:
              context.go('/my-bikes');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map'),
          NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz),
              label: 'Jobs'),
          NavigationDestination(
              icon: Icon(Icons.pedal_bike_outlined),
              selectedIcon: Icon(Icons.pedal_bike),
              label: 'My Bikes'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
