import 'package:flutter/material.dart';

class AnimalTheme {
  const AnimalTheme._();

  static const lightBackground = Color(0xFFF8F6E8);
  static const lightSurface = Color(0xFFFFFBEC);
  static const lightSurfaceSoft = Color(0xFFF2E8D4);
  static const lightInk = Color(0xFF5F3B1F);
  static const lightMuted = Color(0xFF8A7152);

  static const darkBackground = Color(0xFF17140F);
  static const darkSurface = Color(0xFF221C16);
  static const darkSurfaceSoft = Color(0xFF30271D);
  static const darkInk = Color(0xFFF8EFD2);
  static const darkMuted = Color(0xFFCBBE9E);

  static const teal = Color(0xFF18BFAF);
  static const tealDark = Color(0xFF4DD8CB);
  static const mango = Color(0xFFF5C431);
  static const leaf = Color(0xFF74B843);
  static const coral = Color(0xFFE6635A);
  static const bark = Color(0xFF7B4B25);

  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 22.0;
  static const radiusXl = 28.0;
  static const radiusPill = 999.0;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color paper(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color softPaper(BuildContext context) =>
      isDark(context) ? darkSurfaceSoft : lightSurfaceSoft;

  static Color ink(BuildContext context) => isDark(context) ? darkInk : lightInk;

  static Color muted(BuildContext context) =>
      isDark(context) ? darkMuted : lightMuted;

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF5B4936) : const Color(0xFFD8BF8C);

  static Color warmShadow(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: .28)
      : bark.withValues(alpha: .14);

  static BorderRadius radius(double value) => BorderRadius.circular(value);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
    double radius = radiusLg,
    bool elevated = true,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? paper(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border(context), width: 1.5),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: warmShadow(context),
                blurRadius: isDark(context) ? 18 : 16,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration pillDecoration(
    BuildContext context, {
    bool selected = false,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: color ?? (selected ? scheme.primary : softPaper(context)),
      borderRadius: BorderRadius.circular(radiusPill),
      border: Border.all(
        color: selected ? scheme.primary : border(context),
        width: 1.4,
      ),
    );
  }

  static BoxDecoration softPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return cardDecoration(
      context,
      color: scheme.secondaryContainer
          .withValues(alpha: isDark(context) ? .18 : .42),
      radius: radiusMd,
      elevated: false,
      borderColor: border(context).withValues(alpha: .82),
    );
  }
}
