import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SavingsSparkline extends StatelessWidget {
  final List<double> values;
  const SavingsSparkline({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final v = values;
    if (v.isEmpty || v.every((x) => x == 0)) {
      return Container(
        height: 190,
        decoration: BoxDecoration(color: AppColors.card.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text('No savings data', style: TextStyle(color: AppColors.textGrey)),
      );
    }

    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _SparkPainter(v, AppColors.accent),
        child: Container(
          decoration: BoxDecoration(color: AppColors.card.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 14.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    var maxV = 0.0;
    var minV = double.infinity;
    for (final x in v) {
      if (x > maxV) maxV = x;
      if (x < minV) minV = x;
    }
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final dx = pad + (w * i / math.max(1, v.length - 1));
      final dy = pad + h - ((v[i] - minV) / range) * h;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.v != v || old.color != color;
}
