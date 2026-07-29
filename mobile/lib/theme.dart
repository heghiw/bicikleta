import 'package:flutter/material.dart';

// Bicikleta's product palette: neutral graphite surfaces with one crisp accent.
const psOrange = Color(0xFF088F8F);
const psOrangeSoft = Color(0xFFCCFBF1);
const psOrangeDark = Color(0xFF115E59);
const psBackground = Color(0xFFF5F5F4);
const psSurface = Color(0xFFFFFFFF);
const psText = Color(0xFF1C1917);
const psMuted = Color(0xFF78716C);
const psBorder = Color(0xFFE7E5E4);

ThemeData buildTheme() => _theme(Brightness.light);
ThemeData buildDarkTheme() => _theme(Brightness.dark);

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF111111) : psBackground;
  final surface = dark ? const Color(0xFF1C1C1C) : psSurface;
  final surfaceHigh = dark ? const Color(0xFF262626) : const Color(0xFFFAFAF9);
  final text = dark ? const Color(0xFFF5F5F4) : psText;
  final muted = dark ? const Color(0xFFA8A29E) : psMuted;
  final border = dark ? const Color(0xFF383838) : psBorder;
  final scheme = ColorScheme.fromSeed(
    seedColor: psOrange,
    brightness: brightness,
    primary: psOrange,
    onPrimary: Colors.white,
    secondary: dark ? const Color(0xFF123C3A) : psOrangeSoft,
    onSecondary: dark ? const Color(0xFF5EEAD4) : psOrangeDark,
    surface: surface,
    onSurface: text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    textTheme: (dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
        .apply(bodyColor: text, displayColor: text),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHigh,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: psOrange, width: 1.5)),
      labelStyle: TextStyle(color: muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
      backgroundColor: psOrange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    )),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
      backgroundColor: psOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
      foregroundColor: text,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    )),
    chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF153836) : psOrangeSoft,
        labelStyle: TextStyle(
            color: dark ? const Color(0xFF5EEAD4) : psOrangeDark,
            fontWeight: FontWeight.w600,
            fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: dark ? const Color(0xFF134E4A) : psOrangeSoft,
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          color: s.contains(WidgetState.selected) ? psOrange : muted,
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500)),
    ),
    dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
  );
}

class PsStatusChip extends StatelessWidget {
  final String status;
  const PsStatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final positive = {'available', 'open', 'active'}.contains(status);
    final warning = {'reserved', 'pending'}.contains(status);
    final danger = status == 'cancelled';
    final label = {
          'available': 'Available',
          'in_delivery': 'In delivery',
          'in_progress': 'In progress',
          'completed': 'Done',
          'active': 'Active',
          'pending': 'Pending',
          'cancelled': 'Cancelled',
          'open': 'Open'
        }[status] ??
        status;
    final color = danger
        ? const Color(0xFFDC2626)
        : warning
            ? const Color(0xFFD97706)
            : positive
                ? psOrange
                : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(7)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

class PsCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  const PsCard({required this.child, this.onTap, this.padding, super.key});
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
              padding: padding ?? const EdgeInsets.all(16), child: child)));
}

class PsPointsBadge extends StatelessWidget {
  final int points;
  const PsPointsBadge(this.points, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: psOrange.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8)),
      child: Text('$points pts',
          style: const TextStyle(
              color: psOrange, fontWeight: FontWeight.w700, fontSize: 12)));
}

class PsEmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const PsEmptyState(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.action,
      super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center)
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ])));
}
