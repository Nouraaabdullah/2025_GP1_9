// lib/pages/Dashboard/category_chart.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CategorySlice {
  final String id;
  final String name;
  final num value;
  final Color color;
  const CategorySlice({
    required this.id,
    required this.name,
    required this.value,
    required this.color,
  });
}

/* === utilities kept for DashboardPage === */
Color colorFromIconOrSeed({required String categoryId, String? iconHex}) {
  final parsed = _parseHexColorLoose(iconHex);
  return parsed ?? _seededCategoryColor(categoryId);
}

Color? _parseHexColorLoose(String? s) {
  if (s == null) return null;
  var t = s.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.length == 6) t = 'FF$t';
  if (t.length != 8) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(v);
}

Color _seededCategoryColor(String categoryId) {
  final rnd = math.Random(categoryId.hashCode);
  final hue = rnd.nextDouble() * 360.0;
  final sat = 0.65 + rnd.nextDouble() * 0.25;
  final val = 0.75 + rnd.nextDouble() * 0.20;
  return HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
}

/* === Donut === */
class CategoryDonut extends StatefulWidget {
  final List<CategorySlice> slices;
  final String centerLabel;

  final double size;         // square size
  final Alignment alignment; // anchor
  final double thickness;    // ring thickness

  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.size = 240,
    this.alignment = Alignment.center,
    this.thickness = 20,
  });

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  Offset? _tipPos;
  String _tipText = '';
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showTip(Offset local, String text) {
    _hideTimer?.cancel();
    setState(() {
      _tipPos = local;
      _tipText = text;
    });
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _tipPos = null);
    });
  }

  // --- helpers for geometric hit test ---
  double _normAngle(double a) {
    while (a < 0) a += 2 * math.pi;
    while (a >= 2 * math.pi) a -= 2 * math.pi;
    return a;
  }

  bool _angleWithin(double angle, double start, double sweep) {
    final end = _normAngle(start + sweep);
    angle = _normAngle(angle);
    if (sweep <= 0) return false;
    if (start <= end) {
      return angle >= start && angle <= end;
    } else {
      return angle >= start || angle <= end;
    }
  }
  // --------------------------------------

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;

    if (slices.isEmpty) {
      return SizedBox(
        height: widget.size,
        child: Center(child: Text('No category data', style: TextStyle(color: AppColors.textGrey))),
      );
    }

    return Align(
      alignment: widget.alignment,
      child: GestureDetector(
        onTapDown: (d) {
          // Mirror painter geometry
          const deflate = 8.0;
          const gap = 0.012;
          final stroke = widget.thickness;
          const hitSlop = 16.0;

          final rect = Rect.fromLTWH(0, 0, widget.size, widget.size).deflate(deflate);
          final center = rect.center;
          final R = rect.width / 2; // radius to center of stroke
          final inner = R - stroke / 2 - hitSlop;
          final outer = R + stroke / 2 + hitSlop;

          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);

          final dx = local.dx - center.dx;
          final dy = local.dy - center.dy;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r < inner || r > outer) return;

          // angle basis: painter starts at -π/2 (top), clockwise
          var theta = math.atan2(dy, dx);                // -π..π from +X
          var angle = _normAngle(theta - (-math.pi / 2)); // 0 at top, clockwise

          final total = slices.fold<double>(0, (a, s) => a + s.value.toDouble());
          if (total <= 0) return;

          double acc = 0.0;
          for (int i = 0; i < slices.length; i++) {
            final s = slices[i];
            final sweep = (s.value.toDouble() / total) * 2 * math.pi;
            final segStart = acc + gap;
            final segSweep = math.max(0.0, sweep - 2 * gap);

            if (segSweep > 0 && _angleWithin(angle, segStart, segSweep)) {
              // mid point on the band for tooltip
              final mid = segStart + segSweep / 2;
              final tip = Offset(
                center.dx + R * math.cos(mid - math.pi / 2),
                center.dy + R * math.sin(mid - math.pi / 2),
              );
              _showTip(
                Offset(
                  (tip.dx - 90).clamp(0, widget.size - 180),
                  (tip.dy - 44).clamp(0, widget.size - 44),
                ),
                '${s.name}\nAmount: ${s.value.toStringAsFixed(0)} SAR',
              );
              return;
            }
            acc += sweep;
          }
        },
        child: SizedBox(
          height: widget.size,
          width: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(slices: slices, thickness: widget.thickness),
              ),
              Text(
                widget.centerLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color.fromARGB(255, 149, 149, 149),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_tipPos != null)
                Positioned(
                  left: _tipPos!.dx,
                  top: _tipPos!.dy,
                  child: _Bubble(text: _tipText),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final double thickness;
  const _DonutPainter({required this.slices, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value.toDouble());
    if (total <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(8);
    const gap = 0.012; // radians
    var start = -math.pi / 2;

    final bg = Paint()
      ..color = const Color(0xFF3A3A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);

    for (final s in slices) {
      final sweep = (s.value.toDouble() / total) * math.pi * 2;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;

      final segStart = start + gap;
      final segSweep = math.max(0.0, sweep - gap * 2);
      if (segSweep > 0) {
        canvas.drawArc(rect, segStart, segSweep, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices.length != slices.length || old.thickness != thickness;
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12)],
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}
