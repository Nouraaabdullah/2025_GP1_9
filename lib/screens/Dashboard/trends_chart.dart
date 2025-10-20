import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Grouped bars: A=Expenses, B=Earnings, C=Income.
/// Tap a bar to show a tooltip anchored near that bar; auto-fades after ~2.5s.
class TrendsGroupedBars extends StatefulWidget {
  final List<String> labels;
  final List<double> seriesA; // Expenses
  final List<double> seriesB; // Earnings
  final List<double> seriesC; // Income
  final Color colorA, colorB, colorC;

  const TrendsGroupedBars({
    super.key,
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
  });

  @override
  State<TrendsGroupedBars> createState() => _TrendsGroupedBarsState();
}

class _TrendsGroupedBarsState extends State<TrendsGroupedBars> {
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

  @override
  Widget build(BuildContext context) {
    final n = math.min(widget.labels.length,
        math.min(widget.seriesA.length, math.min(widget.seriesB.length, widget.seriesC.length)));
    if (n == 0) {
      return SizedBox(
        height: 190,
        child: Center(child: Text('No data', style: TextStyle(color: AppColors.textGrey))),
      );
    }

    final maxV = [
      ...widget.seriesA.take(n),
      ...widget.seriesB.take(n),
      ...widget.seriesC.take(n),
    ].fold<double>(0, (m, v) => math.max(m, v));

    return SizedBox(
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final groupW = totalW / n;
          const barW = 12.0;
          const gap = 6.0;
          final maxH = (maxV <= 0) ? 1.0 : 160.0;
          double h(double v) => (maxV <= 0) ? 2 : (v / maxV) * maxH;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final dx = d.localPosition.dx;
              final dy = d.localPosition.dy;

              final group = (dx / groupW).floor().clamp(0, n - 1);
              // bars are centered in group
              final originX = group * groupW + (groupW - (barW * 3 + gap * 2)) / 2;
              final localX = dx - originX;

              int? which;
              if (localX >= 0 && localX <= barW * 3 + gap * 2) {
                if (localX < barW) which = 0;
                else if (localX < barW + gap + barW) which = 1;
                else if (localX < barW + gap + barW + gap + barW) which = 2;
              }
              if (which == null) return;

              final a = widget.seriesA[group];
              final b = widget.seriesB[group];
              final c = widget.seriesC[group];
              final val = which == 0 ? a : which == 1 ? b : c;
              final name = which == 0 ? 'Expenses' : which == 1 ? 'Earnings' : 'Income';

              // bar top y
              final barTop = (200 - 40) - h(val); // height: 200, bottom labels ~40px
              final tip = Offset(originX + which * (barW + gap) + barW / 2, math.max(0, barTop - 8));

              _showTip(Offset(tip.dx, tip.dy), '${widget.labels[group]}\n$name: ${val.toStringAsFixed(0)} SAR');
            },
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(n, (i) {
                    final a = widget.seriesA[i];
                    final b = widget.seriesB[i];
                    final c = widget.seriesC[i];
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _bar(h(a), widget.colorA, width: barW),
                              const SizedBox(width: gap),
                              _bar(h(b), widget.colorB, width: barW),
                              const SizedBox(width: gap),
                              _bar(h(c), widget.colorC, width: barW),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(widget.labels[i],
                              style: TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                ),
                if (_tipPos != null)
                  Positioned(
                    left: (_tipPos!.dx - 90).clamp(0, totalW - 180),
                    top: (_tipPos!.dy).clamp(0, 200 - 48),
                    child: const _Bubble(),
                  ),
                if (_tipPos != null)
                  Positioned(
                    left: (_tipPos!.dx - 90).clamp(0, totalW - 180),
                    top: (_tipPos!.dy).clamp(0, 200 - 48),
                    child: _Bubble(text: _tipText),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bar(double h, Color color, {double width = 10}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: h.clamp(2, 160),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 6)],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({this.text = ''});
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
