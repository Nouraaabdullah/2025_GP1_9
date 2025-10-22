// /Users/lamee/Documents/GitHub/2025_GP1_9/lib/screens/Dashboard/category_chart.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// ✅ Auth helper import (will redirect to /login if not signed in)
import '../../utils/auth_helpers.dart';

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

/* === Donut (with precise hit-testing) === */
class CategoryDonut extends StatefulWidget {
  final List<CategorySlice> slices;
  final String centerLabel;

  // Sizing & style
  final double size;             // square canvas size
  final Alignment alignment;
  final double thickness;        // ring thickness (stroke)
  final double centerFontSize;   // center label

  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.size = 240,
    this.alignment = Alignment.center,
    this.thickness = 14,
    this.centerFontSize = 14,
  });

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  // Keep geometry constants in one place so painter & hit-test never drift
  static const double _DEF = 8.0;     // deflate (inset) for the arc rect
  static const double _GAP = 0.012;   // gap between segments (radians)
  static const double _HIT = 16.0;    // radial touch tolerance

  Offset? _tipPos;
  String _tipText = '';
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // ✅ Lightweight auth check; if user is signed out this will navigate to /login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getProfileId(context);
    });
  }

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

  double _norm(double a) {
    while (a < 0) a += 2 * math.pi;
    while (a >= 2 * math.pi) a -= 2 * math.pi;
    return a;
  }

  bool _angleWithin(double angle, double start, double sweep) {
    final end = _norm(start + sweep);
    angle = _norm(angle);
    if (sweep <= 0) return false;
    if (start <= end) return angle >= start && angle <= end;
    return angle >= start || angle <= end; // wrapped
    }

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;

    if (slices.isEmpty) {
      return SizedBox(
        height: widget.size,
        child: Center(
          child: Text('No category data',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ),
      );
    }

    return Align(
      alignment: widget.alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          // === Geometry identical to painter ===
          final square = Rect.fromLTWH(0, 0, widget.size, widget.size);
          final diameter = math.min(square.width, square.height);
          final rect = Rect.fromLTWH(
            (square.width - diameter) / 2 + _DEF,
            (square.height - diameter) / 2 + _DEF,
            diameter - 2 * _DEF,
            diameter - 2 * _DEF,
          );
          final center = rect.center;
          final R = rect.width / 2; // to arc path center
          final inner = R - widget.thickness / 2 - _HIT;
          final outer = R + widget.thickness / 2 + _HIT;

          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);

          final dx = local.dx - center.dx;
          final dy = local.dy - center.dy;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r < inner || r > outer) return;

          // angle basis: painter starts at -π/2 (top), clockwise
          final theta = math.atan2(dy, dx);
          final angle = _norm(theta - (-math.pi / 2));

          final total = slices.fold<double>(0, (a, s) => a + s.value.toDouble());
          if (total <= 0) return;

          double acc = 0.0;
          for (final s in slices) {
            final sweep = (s.value.toDouble() / total) * 2 * math.pi;
            final segStart = acc + _GAP;
            final segSweep = math.max(0.0, sweep - 2 * _GAP);
            if (segSweep > 0 && _angleWithin(angle, segStart, segSweep)) {
              // tooltip position near the arc mid
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
                painter: _DonutPainter(
                  slices: slices,
                  thickness: widget.thickness,
                  deflate: _DEF,
                  gap: _GAP,
                ),
              ),
              Text(
                widget.centerLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: widget.centerFontSize,
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
  final double deflate;
  final double gap;
  const _DonutPainter({
    required this.slices,
    required this.thickness,
    required this.deflate,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.value.toDouble());
    if (total <= 0) return;

    // perfect circle (avoid ellipse)
    final diameter = math.min(size.width, size.height);
    final rect = Rect.fromLTWH(
      (size.width - diameter) / 2 + deflate,
      (size.height - diameter) / 2 + deflate,
      diameter - 2 * deflate,
      diameter - 2 * deflate,
    );

    var start = -math.pi / 2;

    // base track
    final bg = Paint()
      ..color = const Color(0xFF3A3A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);

    // segments
    for (final s in slices) {
      final sweep = (s.value.toDouble() / total) * math.pi * 2;
      final segStart = start + gap;
      final segSweep = math.max(0.0, sweep - 2 * gap);
      if (segSweep > 0) {
        final p = Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, segStart, segSweep, false, p);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices ||
      old.thickness != thickness ||
      old.deflate != deflate ||
      old.gap != gap;
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
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
