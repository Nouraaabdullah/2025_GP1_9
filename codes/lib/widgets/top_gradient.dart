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
            center: Alignment(-0.2, -1), // higher glow
            radius: 1.6,
            colors: [
              Color(0xFF5F4CC7), // soft purple glow (chatbot style)
              Color(0xFF3B2F77), // mid purple
              Color(0xFF1A1833), // deeper purple
              AppColors.bg, // fade smoothly into your dark bg
            ],
            stops: [0.00, 0.28, 0.65, 1.0],
          ),
        ),
      ),
    );
  }
}
