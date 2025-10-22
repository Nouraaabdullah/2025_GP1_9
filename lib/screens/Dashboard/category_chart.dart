// lib/screens/Dashboard/category_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_helpers.dart';

/// Public model used by Dashboard page
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

/// Exported helper used by Dashboard to derive a color from DB data
Color colorFromIconOrSeed({required String categoryId, String? iconHex}) {
  if (iconHex != null && iconHex.isNotEmpty) {
    try {
      final hex = iconHex.replaceAll('#', '');
      final v = int.parse(hex, radix: 16);
      return Color(0xFF000000 | v);
    } catch (_) {}
  }
  // simple deterministic pastel based on id hash
  final h = categoryId.hashCode;
  final r = 120 + (h & 0x3F); // 120..183
  final g = 120 + ((h >> 6) & 0x3F);
  final b = 120 + ((h >> 12) & 0x3F);
  return Color.fromARGB(255, r, g, b);
}

/// Donut chart with accurate hit-testing for slice taps.
/// - When [enableTooltip] is true: tapping a slice shows the purple bubble
///   with that slice's details. Tapping the center ring text calls [onCenterTap].
/// - When [enableTooltip] is false: any tap calls [onTapAnywhere] (used by weekly tiles).
class CategoryDonut extends StatefulWidget {
  final List<CategorySlice> slices;
  final String centerLabel;

  // Interactions
  final VoidCallback? onCenterTap;
  final bool enableTooltip;
  final VoidCallback? onTapAnywhere;
  final void Function(CategorySlice slice)? onSliceTap;

  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.onCenterTap,
    this.enableTooltip = true,
    this.onTapAnywhere,
    this.onSliceTap,
  });

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  // For purple bubble
  CategorySlice? _activeSlice;
  Offset? _bubbleAnchor; // where to place bubble relative to widget

  // geometry cache
  double _outerR = 0;
  double _innerR = 0;
  late List<_Arc> _arcs; // cumulative arcs for hit-testing
  static const double _thickness = 18.0;
  static const double _gapRadians = 0.015; // small visual gap between slices
  static const double _startAngle = -math.pi / 2; // start at 12 o'clock, clockwise

  @override
  void initState() {
    super.initState();
    // ✅ Lightweight auth check; if user is signed out this will navigate to /login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getProfileId(context);
    });
  }

  @override
  void didUpdateWidget(covariant CategoryDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reset bubble if data changed
    if (oldWidget.slices != widget.slices) {
      _activeSlice = null;
      _bubbleAnchor = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Size: square but let parent control width
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 220.0);
        _outerR = size / 2;
        _innerR = _outerR - _thickness;
        _arcs = _computeArcs(widget.slices);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Donut canvas with gestures
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (d) {
                  if (!widget.enableTooltip) {
                    widget.onTapAnywhere?.call();
                    return;
                  }
                  _handleTap(d.localPosition, size);
                },
                child: CustomPaint(
                  painter: _DonutPainter(
                    slices: widget.slices,
                    arcs: _arcs,
                    thickness: _thickness,
                  ),
                  size: Size.square(size),
                ),
              ),

              // Center label and center-tap detection
              _CenterTapRegion(
                diameter: _innerR * 2 - 8, // small inset
                onTap: widget.onCenterTap,
                child: _CenterLabel(text: widget.centerLabel),
              ),

              // Purple bubble
              if (widget.enableTooltip && _activeSlice != null && _bubbleAnchor != null)
                Positioned(
                  left: _bubbleAnchor!.dx - 110, // half bubble width
                  top: _bubbleAnchor!.dy - 48,   // above anchor
                  child: _Bubble(
                    title: _activeSlice!.name,
                    value: '${_activeSlice!.value.toStringAsFixed(0)} SAR',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Convert value list into arcs with cumulative start/end angles
  List<_Arc> _computeArcs(List<CategorySlice> slices) {
    final total = slices.fold<num>(0, (a, s) => a + s.value).toDouble();
    if (total <= 0) return [];
    final arcs = <_Arc>[];
    double a = _startAngle;
    for (final s in slices) {
      final frac = s.value.toDouble() / total;
      final sweep = frac * 2 * math.pi - _gapRadians;
      final start = a;
      final end = a + sweep;
      arcs.add(_Arc(slice: s, start: start, end: end));
      a = end + _gapRadians;
    }
    return arcs;
  }

  void _handleTap(Offset localPos, double size) {
    // Convert position to polar relative to center
    final c = Offset(size / 2, size / 2);
    final v = localPos - c;
    final r = v.distance;

    // If tap is in the center hole, treat as center tap
    if (r <= _innerR) {
      widget.onCenterTap?.call();
      // Do not toggle bubble here
      return;
    }

    // Ignore taps outside the ring
    if (r > _outerR) {
      return;
    }

    // Compute angle in [0, 2π), same reference as painter
    double ang = math.atan2(v.dy, v.dx); // [-π, π]
    // normalize to [0, 2π)
    while (ang < -math.pi) ang += 2 * math.pi;
    while (ang > math.pi) ang -= 2 * math.pi;

    // Find which arc contains this angle (clockwise from startAngle)
    final hit = _findSliceAtAngle(ang);
    if (hit == null) return;

    // Anchor point roughly at ring middle radius on arc mid-angle
    final midA = (hit.start + hit.end) / 2;
    final midR = (_innerR + _outerR) / 2;
    final anchor = Offset(
      size / 2 + midR * math.cos(midA),
      size / 2 + midR * math.sin(midA),
    );

    setState(() {
      _activeSlice = hit.slice;
      _bubbleAnchor = anchor;
    });

    widget.onSliceTap?.call(hit.slice);
  }

  _Arc? _findSliceAtAngle(double angle) {
    if (_arcs.isEmpty) return null;

    // Bring angle to same zone as arcs by mapping to [startAngle, startAngle + 2π)
    double a = angle;
    while (a < _startAngle) a += 2 * math.pi;
    while (a >= _startAngle + 2 * math.pi) a -= 2 * math.pi;

    for (final arc in _arcs) {
      // For robustness include tiny epsilon at end
      if (a >= arc.start && a <= arc.end + 1e-6) {
        return arc;
      }
    }
    return null;
  }
}

/* ====================== Painters & widgets ====================== */

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final List<_Arc> arcs;
  final double thickness;

  _DonutPainter({
    required this.slices,
    required this.arcs,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || arcs.isEmpty) {
      // Draw faint ring placeholder
      final c = Offset(size.width / 2, size.height / 2);
      final r = size.width / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = const Color(0x22FFFFFF);
      canvas.drawCircle(c, r - thickness / 2, paint);
      return;
    }

    final rect = Offset.zero & size;
    final outerR = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < arcs.length; i++) {
      final arc = arcs[i];
      paint.color = arc.slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: outerR - thickness / 2),
        arc.start,
        arc.end - arc.start,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.thickness != thickness ||
        oldDelegate.arcs != arcs;
  }
}

class _CenterTapRegion extends StatelessWidget {
  final double diameter;
  final VoidCallback? onTap;
  final Widget child;
  const _CenterTapRegion({
    required this.diameter,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(diameter / 2),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CenterLabel extends StatelessWidget {
  final String text;
  const _CenterLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String title;
  final String value;
  const _Bubble({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2553),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}

class _Arc {
  final CategorySlice slice;
  final double start;
  final double end;
  const _Arc({required this.slice, required this.start, required this.end});
}
