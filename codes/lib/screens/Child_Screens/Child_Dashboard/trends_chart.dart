import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/auth_helpers.dart';

class TrendsGroupedBars extends StatefulWidget {
  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA, colorB;

  const TrendsGroupedBars({
    super.key,
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
  });

  @override
  State<TrendsGroupedBars> createState() => _TrendsGroupedBarsState();
}

class _TrendsGroupedBarsState extends State<TrendsGroupedBars> {
  Offset? _tipPos;
  String _tipText = '';
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
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
    final n = math.min(
      widget.labels.length,
      math.min(
        widget.seriesA.length,
        widget.seriesB.length,
      ),
    );

    if (n == 0) {
      return const SizedBox(
        height: 190,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(
              fontFamily: AppTextStyles.nunito,
              color: AppColors.kTextSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final maxV = [
      ...widget.seriesA.take(n),
      ...widget.seriesB.take(n),
    ].fold<double>(0, (m, v) => math.max(m, v));

    return SizedBox(
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final groupW = totalW / n;
          const barW = 14.0;
          const gap = 8.0;
          final maxH = (maxV <= 0) ? 1.0 : 160.0;
          double h(double v) => (maxV <= 0) ? 2 : (v / maxV) * maxH;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final dx = d.localPosition.dx;

              final group = (dx / groupW).floor().clamp(0, n - 1);
              final originX =
                  group * groupW + (groupW - (barW * 2 + gap)) / 2;
              final localX = dx - originX;

              int? which;
              if (localX >= 0 && localX <= barW * 2 + gap) {
                if (localX < barW) {
                  which = 0;
                } else if (localX < barW + gap + barW) {
                  which = 1;
                }
              }
              if (which == null) return;

              final a = widget.seriesA[group];
              final b = widget.seriesB[group];
              final val = which == 0 ? a : b;
              final name = which == 0 ? 'Expenses' : 'Earnings';

              final barTop = (200 - 40) - h(val);
              final tip = Offset(
                originX + which * (barW + gap) + barW / 2,
                math.max(0, barTop - 8),
              );

              _showTip(
                Offset(tip.dx, tip.dy),
                '${widget.labels[group]}\n$name\n${val.toStringAsFixed(0)} SAR',
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(n, (i) {
                    final a = widget.seriesA[i];
                    final b = widget.seriesB[i];

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
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.labels[i],
                            style: const TextStyle(
                              fontFamily: AppTextStyles.nunito,
                              color: AppColors.kTextSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                if (_tipPos != null)
                  Positioned(
                    left: (_tipPos!.dx - 110).clamp(0, totalW - 220),
                    top: (_tipPos!.dy).clamp(0, 200 - 68),
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
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.20),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n');

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
    final title = parts.length > 1 ? parts[1] : '';
    final value = parts.length > 2 ? parts[2] : '';

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppGradients.purpleBtn,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.kPurpleDark.withOpacity(0.28),
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
                style: const TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 4),
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (value.isNotEmpty) const SizedBox(height: 4),
            if (value.isNotEmpty)
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}