import 'package:flutter/material.dart';

const _green = Color(0xFF16A34A);
const _greenLight = Color(0xFFDCFCE7);
const _greenDark = Color(0xFF166534);
const _bg = Color(0xFFF9FAFB);
const _surface = Color(0xFFFFFFFF);
const _text1 = Color(0xFF111827);
const _text2 = Color(0xFF374151);
const _text3 = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _green,
      primary: _green,
      onPrimary: Colors.white,
      secondary: _greenLight,
      onSecondary: _greenDark,
      background: _bg,
      surface: _surface,
      onSurface: _text1,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _text1,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _text1,
      ),
    ),
    cardTheme: CardTheme(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _green, width: 1.5),
      ),
      labelStyle: const TextStyle(color: _text3, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _text1,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _greenLight,
      labelStyle: const TextStyle(color: _greenDark, fontWeight: FontWeight.w600, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _surface,
      selectedItemColor: _green,
      unselectedItemColor: _text3,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(color: _border, space: 1, thickness: 1),
  );
}

// ── Shared widget helpers ────────────────────────────────────────────────────

class PsStatusChip extends StatelessWidget {
  final String status;
  const PsStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final config = {
      'available':   [const Color(0xFFDCFCE7), const Color(0xFF166534), 'Available'],
      'reserved':    [const Color(0xFFFEF3C7), const Color(0xFF92400E), 'Reserved'],
      'in_delivery': [const Color(0xFFDBEAFE), const Color(0xFF1E40AF), 'In Delivery'],
      'offline':     [_bg, _text3, 'Offline'],
      'open':        [const Color(0xFFDCFCE7), const Color(0xFF166534), 'Open'],
      'in_progress': [const Color(0xFFDBEAFE), const Color(0xFF1E40AF), 'In Progress'],
      'completed':   [_bg, _text3, 'Done'],
      'active':      [const Color(0xFFDCFCE7), const Color(0xFF166534), 'Active'],
      'pending':     [const Color(0xFFFEF3C7), const Color(0xFF92400E), 'Pending'],
      'cancelled':   [const Color(0xFFFEE2E2), const Color(0xFF991B1B), 'Cancelled'],
    };
    final c = config[status] ?? [_bg, _text3, status];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c[0] as Color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        c[2] as String,
        style: TextStyle(color: c[1] as Color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PsCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  const PsCard({required this.child, this.onTap, this.padding, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class PsPointsBadge extends StatelessWidget {
  final int points;
  const PsPointsBadge(this.points, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌿', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text('$points pts', style: const TextStyle(color: _greenDark, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

class PsEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const PsEmptyState({required this.icon, required this.title, this.subtitle, this.action, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text2)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(fontSize: 14, color: _text3), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}
