import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/auth_helpers.dart';

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
  if (iconHex != null && iconHex.isNotEmpty) {
    try {
      final hex = iconHex.replaceAll('#', '');
      final v = int.parse(hex, radix: 16);
      return Color(0xFF000000 | v);
    } catch (_) {}
  }

  final h = categoryId.hashCode;
  final r = 120 + (h & 0x3F);
  final g = 120 + ((h >> 6) & 0x3F);
  final b = 120 + ((h >> 12) & 0x3F);
  return Color.fromARGB(255, r, g, b);
}

class CategoryDonut extends StatefulWidget {
  final List<CategorySlice> slices;
  final String centerLabel;
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
  CategorySlice? _activeSlice;
  Offset? _bubbleAnchor;
  Timer? _hideTimer;

  double _outerR = 0;
  double _innerR = 0;
  late List<_Arc> _arcs;

  static const double _thickness = 18.0;
  static const double _gapRadians = 0.015;
  static const double _startAngle = -math.pi / 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getProfileId(context);
    });
  }

  @override
  void didUpdateWidget(covariant CategoryDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices != widget.slices) {
      _activeSlice = null;
      _bubbleAnchor = null;
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              _CenterTapRegion(
                diameter: _innerR * 2 - 8,
                onTap: widget.onCenterTap,
                child: _CenterLabel(text: widget.centerLabel),
              ),
              if (widget.enableTooltip &&
                  _activeSlice != null &&
                  _bubbleAnchor != null)
                Positioned(
                  left: _bubbleAnchor!.dx - 110,
                  top: _bubbleAnchor!.dy - 48,
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
    final c = Offset(size / 2, size / 2);
    final v = localPos - c;
    final r = v.distance;

    if (r <= _innerR) {
      widget.onCenterTap?.call();
      return;
    }

    if (r > _outerR) return;

    double ang = math.atan2(v.dy, v.dx);
    while (ang < -math.pi) {
      ang += 2 * math.pi;
    }
    while (ang > math.pi) {
      ang -= 2 * math.pi;
    }

    final hit = _findSliceAtAngle(ang);
    if (hit == null) return;

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

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _activeSlice = null;
        _bubbleAnchor = null;
      });
    });

    widget.onSliceTap?.call(hit.slice);
  }

  _Arc? _findSliceAtAngle(double angle) {
    if (_arcs.isEmpty) return null;

    double a = angle;
    while (a < _startAngle) {
      a += 2 * math.pi;
    }
    while (a >= _startAngle + 2 * math.pi) {
      a -= 2 * math.pi;
    }

    for (final arc in _arcs) {
      if (a >= arc.start && a <= arc.end + 1e-6) {
        return arc;
      }
    }
    return null;
  }
}

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
      final c = Offset(size.width / 2, size.height / 2);
      final r = size.width / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = AppColors.kPurple.withOpacity(0.18);
      canvas.drawCircle(c, r - thickness / 2, paint);
      return;
    }

    final rect = Offset.zero & size;
    final outerR = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    for (final arc in arcs) {
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
          fontFamily: AppTextStyles.nunito,
          color: AppColors.kText,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String title;
  final String value;

  const _Bubble({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppGradients.purpleBtn,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.kPurpleDark.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTextStyles.nunito,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTextStyles.nunito,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _Arc {
  final CategorySlice slice;
  final double start;
  final double end;

  const _Arc({
    required this.slice,
    required this.start,
    required this.end,
  });
}