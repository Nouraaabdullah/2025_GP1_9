// lib/pages/Dashboard/category_chart.dart
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

class CategoryDonut extends StatelessWidget {
  final List<CategorySlice> slices;
  final String centerLabel;

  // new controls
  final double size;               // overall square size
  final Alignment alignment;       // where to anchor inside parent
  final double thickness;          // ring thickness

  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.size = 240,
    this.alignment = Alignment.center,
    this.thickness = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return SizedBox(
        height: size,
        child: Center(child: Text('No category data', style: TextStyle(color: AppColors.textGrey))),
      );
    }

    return Align(
      alignment: alignment,
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _DonutPainter(slices: slices, thickness: thickness),
            ),
            Text(
              centerLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color.fromARGB(255, 149, 149, 149), fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final double thickness;
  _DonutPainter({required this.slices, required this.thickness});

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
  bool shouldRepaint(covariant _DonutPainter old) {
    if (old.slices.length != slices.length) return true;
    if (old.thickness != thickness) return true;
    for (var i = 0; i < slices.length; i++) {
      if (old.slices[i].value != slices[i].value || old.slices[i].color != slices[i].color) return true;
    }
    return false;
  }
}
