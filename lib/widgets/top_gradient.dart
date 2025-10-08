import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopGradient extends StatelessWidget {
  final double height;
  const TopGradient({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.9),
            radius: 1.2,
            colors: [AppColors.g1, AppColors.g2, AppColors.g3],
            stops: [0.10, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}
