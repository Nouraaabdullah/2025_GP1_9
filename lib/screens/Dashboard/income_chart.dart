import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Semicircle gauge where the base = earnings + income.
/// Violet = expenses (spent), remaining arc is split proportionally:
/// cyan = earnings share, muted = income share.
/// Tap anywhere on the arc to get a tooltip near your tap. Tooltip auto-fades.
class IncomeSemicircleGauge extends StatefulWidget {
  final double percent; // 0..1, shown in the center text
  final String label;

  // Optional pieces so the gauge can split the semicircle correctly
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
  Offset? _tipPos;      // local position for tooltip
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

  @override
  Widget build(BuildContext context) {
    final exp = (widget.expenses ?? 0).clamp(0, double.infinity);
    final ern = (widget.earnings ?? 0).clamp(0, double.infinity);
    final inc = (widget.income ?? 0).clamp(0, double.infinity);
    final base = (ern + inc);

    // compute sweeps across 180 degrees (start at 180°, clockwise)
    double sweepExp = 0, sweepErn = 0, sweepInc = 0;
    if (base > 0) {
      final used = exp.clamp(0, base);
      final remain = (base - used);
      sweepExp = 180.0 * (used / base);
      final remainSweep = 180.0 - sweepExp;
      final erShare = ern == 0 && inc == 0 ? 0.5 : (ern / (ern + inc == 0 ? 1 : (ern + inc)));
      final incShare = 1 - erShare;
      sweepErn = remainSweep * erShare;
      sweepInc = remainSweep * incShare;
    } else {
      // Fallback to percent when no base data
      final p = widget.percent.clamp(0, 1);
      sweepExp = 0;
      sweepErn = 180.0 * p;
      sweepInc = 0;
    }

    final size = const Size(275, 268);

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          final box = d.localPosition;
          // Prepare tooltip text
          final left = base > 0 ? (base - exp).clamp(0, base) : 0;
          final txt = 'Expenses: ${exp.toStringAsFixed(0)} SAR\n'
              'Earnings: ${ern.toStringAsFixed(0)} SAR\n'
              'Income: ${inc.toStringAsFixed(0)} SAR\n'
              'Left: ${left.toStringAsFixed(0)} SAR';
          _showTip(box, txt);
        },
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // arcs
              CustomPaint(size: size, painter: _ArcPainter(color: const Color(0xFF3A3A5A), startDeg: 180, sweep: 180)),
              if (sweepExp > 0) CustomPaint(size: size, painter: _ArcPainter(color: const Color(0xFF8B5CF6), startDeg: 180, sweep: sweepExp)),
              if (sweepErn > 0) CustomPaint(size: size, painter: _ArcPainter(color: const Color(0xFF22D3EE), startDeg: 180 + sweepExp, sweep: sweepErn)),
              if (sweepInc > 0) CustomPaint(size: size, painter: _ArcPainter(color: const Color(0xFF8C89B4), startDeg: 180 + sweepExp + sweepErn, sweep: sweepInc)),
              // Center label
              Positioned.fill(
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              // Tooltip near tap
              if (_tipPos != null)
                Positioned(
                  left: (_tipPos!.dx - 90).clamp(0, size.width - 180),
                  top: (_tipPos!.dy - 56).clamp(0, size.height - 48),
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
  final double startDeg; // degrees
  final double sweep;    // degrees
  final Color color;
  const _ArcPainter({required this.color, required this.startDeg, required this.sweep});

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
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}
