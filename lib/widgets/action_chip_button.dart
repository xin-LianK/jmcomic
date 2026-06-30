import 'package:flutter/material.dart';

import '../theme/animal_theme.dart';

class ActionChipButton extends StatelessWidget {
  const ActionChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AnimalTheme.radiusPill)),
            elevation: 0,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: scheme.onSurface,
            backgroundColor: AnimalTheme.paper(context),
            side: BorderSide(color: AnimalTheme.border(context), width: 1.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AnimalTheme.radiusPill)),
          );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}
