import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CurvedDarkSection extends StatelessWidget {
  final double top; // y-offset where the dark section begins
  final Widget child;
  const CurvedDarkSection({super.key, required this.top, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: top,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.all(Radius.circular(48)),
        ),
        child: child,
      ),
    );
  }
}
