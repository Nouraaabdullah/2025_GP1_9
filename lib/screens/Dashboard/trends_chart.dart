import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TrendsGroupedBars extends StatelessWidget {
  final List<String> labels;
  final List<double> seriesA; // Expenses
  final List<double> seriesB; // Earnings
  final List<double> seriesC; // Income
  final Color colorA, colorB, colorC;

  const TrendsGroupedBars({
    super.key,
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
  });

  @override
  Widget build(BuildContext context) {
    final n = math.min(labels.length, math.min(seriesA.length, math.min(seriesB.length, seriesC.length)));
    if (n == 0) {
      return SizedBox(
        height: 170,
        child: Center(child: Text('No data', style: TextStyle(color: AppColors.textGrey))),
      );
    }

    final maxV = [
      ...seriesA.take(n),
      ...seriesB.take(n),
      ...seriesC.take(n),
    ].fold<double>(0, (m, v) => math.max(m, v));

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(n, (i) {
          final a = seriesA[i];
          final b = seriesB[i];
          final c = seriesC[i];
          final maxH = (maxV <= 0) ? 1.0 : 160.0;
          double h(double v) => (maxV <= 0) ? 2 : (v / maxV) * maxH;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bar(h(a), colorA),
                    _bar(h(b), colorB),
                    _bar(h(c), colorC),
                  ],
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _bar(double h, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: h.clamp(2, 160),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 6)],
      ),
    );
  }
}
