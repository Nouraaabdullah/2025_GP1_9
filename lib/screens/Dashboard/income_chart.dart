import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class IncomeSemicircleGauge extends StatelessWidget {
  final double percent; // 0..1
  final String label;
  const IncomeSemicircleGauge({super.key, required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 1);
    return Center(
      child: SizedBox(
        width: 275,
        height: 268,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: const Color(0xFF3A3A5A), sweep: 180)),
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: const Color(0xFF8B5CF6), sweep: 180 * p * 0.3)),
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: const Color(0xFF22D3EE), sweep: 180 * p * 1)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double sweep; // degrees
  final Color color;
  const _ArcPainter({required this.color, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(14), 3.1415926, sweep * 3.1415926 / 180, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.color != color || old.sweep != sweep;
}
