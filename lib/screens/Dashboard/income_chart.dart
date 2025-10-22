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
  String _tipText = '';
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

          String? text;
          if (_angleWithin(absAngle, startExp, expSweep)) {
            text = 'Expenses: ${expVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(absAngle, startErn, ernSweep)) {
            text = 'Earnings: ${ernVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(absAngle, startInc, incSweep)) {
            text = 'Income: ${incVal.toStringAsFixed(0)} SAR';
          } else {
            return;
          }

          setState(() {
            _tipPos = Offset(
              (local.dx - 90).clamp(0, _size.width - 180),
              (local.dy - 56).clamp(0, _size.height - 48),
            );
            _tipText = text!;
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
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
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

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 150),
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
