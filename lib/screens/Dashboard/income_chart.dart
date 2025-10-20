import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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

  // --- helpers ---------------------------------------------------

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

  // ---------------------------------------------------------------

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
      final p = widget.percent.clamp(0, 1);
      sweepErn = 180.0 * p;
      sweepInc = 180.0 - sweepErn;
    }

    const Size size = Size(275, 268);

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          // geometry identical to painter
          const stroke = 22.0;
          const deflate = 14.0;
          const hitSlop = 14.0;

          final rect =
              Rect.fromLTWH(0, 0, size.width, size.height).deflate(deflate);
          final center = rect.center;
          final R = rect.width / 2;
          final inner = R - stroke / 2 - hitSlop;
          final outer = R + stroke / 2 + hitSlop;

          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);

          final dx = local.dx - center.dx;
          final dy = local.dy - center.dy;
          final r = math.sqrt(dx * dx + dy * dy);

          if (r < inner || r > outer) return;

          // Convert to 0..π (semicircle, top=0, clockwise)
          var theta = math.atan2(dy, dx);
          var angle = _normAngle(theta + math.pi / 2);

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

          final startExp = 0.0;
          final startErn = startExp + expSweep;
          final startInc = startErn + ernSweep;

          String? text;
          if (_angleWithin(angle, startExp, expSweep)) {
            text = 'Expenses: ${expVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(angle, startErn, ernSweep)) {
            text = 'Earnings: ${ernVal.toStringAsFixed(0)} SAR';
          } else if (_angleWithin(angle, startInc, incSweep)) {
            text = 'Income: ${incVal.toStringAsFixed(0)} SAR';
          } else {
            return;
          }

          setState(() {
            _tipPos = Offset(
              (local.dx - 90).clamp(0, size.width - 180),
              (local.dy - 56).clamp(0, size.height - 48),
            );
            _tipText = text!;
          });
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _tipPos = null);
          });
        },
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _ArcPainter(
                    color: const Color(0xFF3A3A5A),
                    startDeg: 180,
                    sweep: 180),
              ),
              if (sweepExp > 0)
                CustomPaint(
                  size: size,
                  painter: _ArcPainter(
                      color: const Color(0xFF8B5CF6),
                      startDeg: 180,
                      sweep: sweepExp),
                ),
              if (sweepErn > 0)
                CustomPaint(
                  size: size,
                  painter: _ArcPainter(
                      color: const Color(0xFF22D3EE),
                      startDeg: 180 + sweepExp,
                      sweep: sweepErn),
                ),
              if (sweepInc > 0)
                CustomPaint(
                  size: size,
                  painter: _ArcPainter(
                      color: const Color(0xFF8C89B4),
                      startDeg: 180 + sweepExp + sweepErn,
                      sweep: sweepInc),
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
  final double startDeg;
  final double sweep;
  final Color color;
  const _ArcPainter({
    required this.color,
    required this.startDeg,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(14);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final startRad = startDeg * math.pi / 180.0;
    final sweepRad = sweep * math.pi / 180.0;
    canvas.drawArc(rect, startRad, sweepRad, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.color != color || old.sweep != sweep || old.startDeg != startDeg;
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
