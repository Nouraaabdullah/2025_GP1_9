// /Users/lamee/Documents/GitHub/2025_GP1_9/lib/screens/Dashboard/income_chart.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// ✅ Auth helper import (redirects to /login if not signed in)
import '../../utils/auth_helpers.dart';

class IncomeSemicircleGauge extends StatefulWidget {
  final double percent;
  final String label;
  final double? expenses;
  final double? earnings;
  final double? income;

  const IncomeSemicircleGauge({
    super.key,
    required this.percent,
    required this.label,
    this.expenses,
    this.earnings,
    this.income,
  });

  @override
  State<IncomeSemicircleGauge> createState() => _IncomeSemicircleGaugeState();
}

class _IncomeSemicircleGaugeState extends State<IncomeSemicircleGauge> {
  Offset? _tipPos;
  String _tipTitle = '';
  String _tipValue = '';
  Timer? _hideTimer;

  // Geometry (kept in one place so painter + hit-test always match)
  static const Size _size = Size(275, 268);
  static const double _stroke = 22.0;   // ring thickness
  static const double _deflate = 14.0;  // arc inset
  static const double _hitSlop = 14.0;  // extra touch tolerance

  // Colors (match Dashboard legends)
  static const _cExpenses = Color(0xFF8B5CF6);
  static const _cEarnings = Color(0xFF22D3EE);
  static const _cIncome   = Color(0xFF8C89B4);
  static const _cTrack    = Color(0xFF3A3A5A);

  // ----- helpers -------------------------------------------------
  double _normAngle(double a) {
    while (a < 0) a += 2 * math.pi;
    while (a >= 2 * math.pi) a -= 2 * math.pi;
    return a;
  }

  bool _angleWithin(double angle, double start, double sweep) {
    // angles in [0..2π), sweep >= 0
    final end = _normAngle(start + sweep);
    angle = _normAngle(angle);
    if (sweep <= 0) return false;
    if (start <= end) {
      return angle >= start && angle <= end;
    } else {
      // wrap-around
      return angle >= start || angle <= end;
    }
  }
  // ---------------------------------------------------------------

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

  @override
  Widget build(BuildContext context) {
    final exp = (widget.expenses ?? 0).clamp(0, double.infinity);
    final ern = (widget.earnings ?? 0).clamp(0, double.infinity);
    final inc = (widget.income ?? 0).clamp(0, double.infinity);
    final base = (ern + inc);

    // Compute sweeps in degrees for drawing
    double sweepExp = 0, sweepErn = 0, sweepInc = 0;
    if (base > 0) {
      final used = exp.clamp(0, base);
      sweepExp = 180.0 * (used / base);
      final remain = 180.0 - sweepExp;

      final denom = (ern + inc);
      final erShare = denom <= 0 ? 0.5 : (ern / denom);
      final incShare = 1 - erShare;

      sweepErn = remain * erShare;
      sweepInc = remain * incShare;
    } else {
      // fallback to percent split if we don't have base values
      final p = widget.percent.clamp(0, 1);
      sweepErn = 180.0 * p;
      sweepInc = 180.0 - sweepErn;
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          // Geometry identical to painter
          final rect = Rect.fromLTWH(0, 0, _size.width, _size.height).deflate(_deflate);
          final center = rect.center;
          final R = rect.width / 2;
          final inner = R - _stroke / 2 - _hitSlop;
          final outer = R + _stroke / 2 + _hitSlop;

          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);

          final dx = local.dx - center.dx;
          final dy = local.dy - center.dy;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r < inner || r > outer) return;

          // Painter starts at 180° (π) and sweeps clockwise across the BOTTOM semicircle.
          // So compute the true polar angle (0..2π from +X), ensure we are in [π..2π),
          // then map that to a 0..π "semicircle" angle by subtracting π.
          double angleFromPlusX = _normAngle(math.atan2(dy, dx)); // 0..2π
          if (angleFromPlusX < math.pi) return; // touches on the top half are ignored
          final semi = angleFromPlusX - math.pi; // 0..π along the painted semicircle

          // Build sweeps in radians for hit-test using same math as drawing
          final expVal = exp;
          final ernVal = ern;
          final incVal = inc;
          final baseVal = ernVal + incVal;

          double expSweep = 0, ernSweep = 0, incSweep = 0;
          if (baseVal > 0) {
            expSweep = math.pi * (expVal.clamp(0, baseVal) / baseVal);
            final remain = math.pi - expSweep;
            final denom = (ernVal + incVal);
            final erShare = denom <= 0 ? 0.5 : (ernVal / denom);
            ernSweep = remain * erShare;
            incSweep = remain * (1 - erShare);
          } else {
            final p = widget.percent.clamp(0, 1);
            ernSweep = math.pi * p;
            incSweep = math.pi - ernSweep;
          }

          // Segments along the semicircle (0..π)
          final startExp = math.pi;                // in painter space this is 180°
          final startErn = startExp + expSweep;    // continues clockwise
          final startInc = startErn + ernSweep;

          // Convert our local semicircle angle (0..π) to the painter's absolute space (π..2π)
          final absAngle = semi + math.pi;

          String? title;
          String? value;
          if (_angleWithin(absAngle, startExp, expSweep)) {
            title = 'Expenses';
            value = '${expVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(absAngle, startErn, ernSweep)) {
            title = 'Earnings';
            value = '${ernVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(absAngle, startInc, incSweep)) {
            title = 'Income';
            value = '${incVal.toStringAsFixed(0)} SAR';
          } else {
            return;
          }

          setState(() {
            // Anchor bubble near tap, with some clamping inside widget
            final left = (local.dx - 110).clamp(0.0, _size.width - 220.0);
            final top  = (local.dy - 56).clamp(0.0, _size.height - 68.0);
            _tipPos = Offset(left, top);
            _tipTitle = title!;
            _tipValue = value!;
          });
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _tipPos = null);
          });
        },
        child: SizedBox(
          width: _size.width,
          height: _size.height,
          child: Stack(
            children: [
              // Track
              CustomPaint(
                size: _size,
                painter: _ArcPainter(
                  color: _cTrack,
                  startDeg: 180,
                  sweepDeg: 180,
                  stroke: _stroke,
                  deflate: _deflate,
                ),
              ),
              // Expenses, then Earnings, then Income
              if (sweepExp > 0)
                CustomPaint(
                  size: _size,
                  painter: _ArcPainter(
                    color: _cExpenses,
                    startDeg: 180,
                    sweepDeg: sweepExp,
                    stroke: _stroke,
                    deflate: _deflate,
                  ),
                ),
              if (sweepErn > 0)
                CustomPaint(
                  size: _size,
                  painter: _ArcPainter(
                    color: _cEarnings,
                    startDeg: 180 + sweepExp,
                    sweepDeg: sweepErn,
                    stroke: _stroke,
                    deflate: _deflate,
                  ),
                ),
              if (sweepInc > 0)
                CustomPaint(
                  size: _size,
                  painter: _ArcPainter(
                    color: _cIncome,
                    startDeg: 180 + sweepExp + sweepErn,
                    sweepDeg: sweepInc,
                    stroke: _stroke,
                    deflate: _deflate,
                  ),
                ),
              Positioned.fill(
                child: Align(
                alignment: const Alignment(0, -0.2), // move up (negative Y = higher)
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
             

              if (_tipPos != null)
                Positioned(
                  left: _tipPos!.dx,
                  top: _tipPos!.dy,
                  child: const SizedBox(), // placeholder to keep layout stable
                ),
              if (_tipPos != null)
                Positioned(
                  left: _tipPos!.dx,
                  top: _tipPos!.dy,
                  child: _PurpleBubble(
                    title: _tipTitle,
                    value: _tipValue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double startDeg; // absolute degrees from +X axis
  final double sweepDeg;
  final Color color;
  final double stroke;
  final double deflate;

  const _ArcPainter({
    required this.color,
    required this.startDeg,
    required this.sweepDeg,
    required this.stroke,
    required this.deflate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(deflate);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final startRad = startDeg * math.pi / 180.0;
    final sweepRad = sweepDeg * math.pi / 180.0;
    canvas.drawArc(rect, startRad, sweepRad, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.color != color ||
      old.sweepDeg != sweepDeg ||
      old.startDeg != startDeg ||
      old.stroke != stroke ||
      old.deflate != deflate;
}

/// Purple bubble styled like CategoryDonut tooltip
class _PurpleBubble extends StatelessWidget {
  final String title;
  final String value;
  const _PurpleBubble({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2553), // deep purple card
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
