import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Auth helper import (redirects to /login if not signed in)
import '../../utils/auth_helpers.dart';

/// Line sparkline for Savings with tap tooltip next to the point.
/// - `values` are Y values from DB (no placeholders).
/// - `labels` are X labels from DB (same length as values).
class SavingsSparkline extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final bool showPoints;
  final String yAxisTitle;

  const SavingsSparkline({
    super.key,
    required this.values,
    required this.labels,
    this.showPoints = true,
    this.yAxisTitle = 'Monthly savings',
  });

  @override
  State<SavingsSparkline> createState() => _SavingsSparklineState();
}

class _SavingsSparklineState extends State<SavingsSparkline> {
  Offset? _tipPos;
  String _tipText = '';
  Timer? _hideTimer;

  // must match painter’s paddings + spacing
  static const double _leftPad   = 48.0;
  static const double _rightPad  = 12.0;
  static const double _topPad    = 14.0;
  static const double _bottomPad = 28.0;
  static const double _edgeFrac  = 0.06; // inner horizontal padding percentage

  @override
  void initState() {
    super.initState();
    // Lightweight auth check; if signed out, helper will navigate to /login.
    // Does not alter chart behavior otherwise.
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

  @override
  Widget build(BuildContext context) {
    final v = widget.values;
    final labels = widget.labels;

    if (v.isEmpty || v.every((x) => x == 0)) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text('No savings data', style: TextStyle(color: AppColors.textGrey)),
      );
    }

    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, c) {
          final plotW = c.maxWidth - _leftPad - _rightPad;
          final plotH = 220 - _topPad - _bottomPad;
          final count = v.length;

          // value scale
          double maxV = v.reduce((a, b) => a > b ? a : b);
          double minV = v.reduce((a, b) => a < b ? a : b);
          if ((maxV - minV).abs() < 1e-9) { maxV += 1; minV -= 1; }
          final range = maxV - minV;

          // horizontal inner padding so points aren’t at the extreme edges
          double innerW = plotW;
          double startX = _leftPad;
          if (count == 1) {
            innerW = plotW;
            startX = _leftPad;
          } else {
            final pad = plotW * _edgeFrac;
            innerW = plotW - pad * 2;
            startX = _leftPad + pad;
          }

          Offset point(int i) {
            final t = (count == 1) ? 0.5 : i / (count - 1);
            final dx = startX + innerW * t;
            final dy = _topPad + plotH - ((v[i] - minV) / range) * plotH;
            return Offset(dx, dy);
          }

          int indexFromDx(double localDx) {
            if (count == 1) return 0;
            final pad = plotW * _edgeFrac;
            final left = _leftPad + pad;
            final right = _leftPad + plotW - pad;
            final clamped = localDx.clamp(left, right);
            final t = (clamped - left) / (right - left);
            return (t * (count - 1)).round().clamp(0, count - 1);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final idx = indexFromDx(d.localPosition.dx);
              final p = point(idx);
              final label = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
              _showTip(
                p.translate(0, -10),
                '$label\n${widget.yAxisTitle}: ${v[idx].toStringAsFixed(0)} SAR',
              );
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(c.maxWidth, 220),
                  painter: _SparkPainter(
                    values: v,
                    labels: labels,
                    color: AppColors.accent,
                    showPoints: widget.showPoints,
                    yAxisTitle: widget.yAxisTitle,
                    paddings: const EdgeInsets.fromLTRB(_leftPad, _topPad, _rightPad, _bottomPad),
                    edgeFrac: _edgeFrac,
                  ),
                ),
                if (_tipPos != null)
                  Positioned(
                    left: (_tipPos!.dx - 110).clamp(0, c.maxWidth - 220),
                    top: (_tipPos!.dy - 48).clamp(0, 220 - 68),
                    child: _Bubble(text: _tipText),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final bool showPoints;
  final String yAxisTitle;
  final EdgeInsets paddings;
  final double edgeFrac;

  _SparkPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.showPoints,
    required this.yAxisTitle,
    required this.paddings,
    required this.edgeFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = paddings.left, rightPad = paddings.right, topPad = paddings.top, bottomPad = paddings.bottom;
    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - topPad - bottomPad;
    final plot = Rect.fromLTWH(leftPad, topPad, plotW, plotH);

    // grid lines
    final grid = Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 1;
    for (int k = 0; k <= 4; k++) {
      final y = plot.top + plotH * k / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    // centered Y-axis title (rotated)
    final yText = TextPainter(
      text: TextSpan(
        text: yAxisTitle,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    final yCenter = Offset(leftPad / 2, plot.center.dy);
    canvas.translate(yCenter.dx, yCenter.dy);
    canvas.rotate(-math.pi / 2);
    yText.paint(canvas, Offset(-yText.width / 2, -yText.height / 2));
    canvas.restore();

    if (values.isEmpty) return;

    // value scale
    double maxV = values.reduce((a, b) => a > b ? a : b);
    double minV = values.reduce((a, b) => a < b ? a : b);
    if ((maxV - minV).abs() < 1e-9) { maxV += 1; minV -= 1; }
    final range = maxV - minV;

    // horizontal inner padding so points aren’t at the edges
    double innerW = plotW;
    double startX = plot.left;
    if (values.length == 1) {
      innerW = plotW;
      startX = plot.left;
    } else {
      final pad = plotW * edgeFrac;
      innerW = plotW - pad * 2;
      startX = plot.left + pad;
    }

    // build path + points
    final path = Path();
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final t = (values.length == 1) ? 0.5 : i / (values.length - 1);
      final dx = startX + innerW * t;
      final dy = plot.top + plotH - ((values[i] - minV) / range) * plotH;
      final p = Offset(dx, dy);
      pts.add(p);
      if (i == 0) path.moveTo(dx, dy); else path.lineTo(dx, dy);
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);

    if (showPoints) {
      final dot = Paint()..color = color;
      for (final p in pts) {
        canvas.drawCircle(p, 3.2, dot);
      }
    }

    // centered X labels under points (use DB labels)
    final labelStyle = const TextStyle(color: Colors.white70, fontSize: 10);
    for (var i = 0; i < values.length && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = pts[i].dx - tp.width / 2;
      final dy = plot.bottom + 6;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.color != color ||
      old.showPoints != showPoints ||
      old.yAxisTitle != yAxisTitle ||
      old.paddings != paddings ||
      old.edgeFrac != edgeFrac;
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  
  @override
  Widget build(BuildContext context) {
    
    // Expect input like:
    // line 0 -> label (e.g., October)
    // line 1 -> title or "title: value" (e.g., Monthly savings OR Monthly savings: 120 SAR)
    // line 2 -> optional value (e.g., 120 SAR)
    final parts = text.split('\n');

    // Expand short month names to full names
    final months = {
      'Jan': 'January',
      'Feb': 'February',
      'Mar': 'March',
      'Apr': 'April',
      'May': 'May',
      'Jun': 'June',
      'Jul': 'July',
      'Aug': 'August',
      'Sep': 'September',
      'Oct': 'October',
      'Nov': 'November',
      'Dec': 'December',
    };

    final rawLabel = parts.isNotEmpty ? parts[0].trim() : '';
    final label = months[rawLabel] ?? rawLabel;

    String title = parts.length > 1 ? parts[1].trim() : '';
    String value = parts.length > 2 ? parts[2].trim() : '';

    // If the second line was "title: value", split it.
    if (value.isEmpty && title.contains(':')) {
      final idx = title.indexOf(':');
      value = title.substring(idx + 1).trim();
      title = title.substring(0, idx).trim();
    }

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
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
            if (label.isNotEmpty)
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 4),
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (value.isNotEmpty) const SizedBox(height: 4),
            if (value.isNotEmpty)
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
