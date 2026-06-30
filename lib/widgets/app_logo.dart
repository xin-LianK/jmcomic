import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'JM 漫画',
      child: SvgPicture.asset(
        'assets/brand/jm_visual_logo.svg',
        height: compact ? 32 : 42,
        fit: BoxFit.contain,
      ),
    );
  }
}
