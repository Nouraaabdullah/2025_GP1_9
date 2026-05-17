import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/auth_helpers.dart';

class MoneyLeftSemicircleGauge
    extends
        StatefulWidget {
  final double percent;
  final String label;
  final double? expenses;
  final double? earnings;

  const MoneyLeftSemicircleGauge({
    super.key,
    required this.percent,
    required this.label,
    this.expenses,
    this.earnings,
  });

  @override
  State<
    MoneyLeftSemicircleGauge
  >
  createState() => _MoneyLeftSemicircleGaugeState();
}

class _MoneyLeftSemicircleGaugeState
    extends
        State<
          MoneyLeftSemicircleGauge
        > {
  Offset? _tipPos;
  String _tipTitle = '';
  String _tipValue = '';
  Timer? _hideTimer;

  static const Size _size = Size(
    275,
    268,
  );
  static const double _stroke = 22.0;
  static const double _deflate = 14.0;
  static const double _hitSlop = 14.0;

  static const _cExpenses = AppColors.kPurple;
  static const _cEarnings = AppColors.kBlue;
  static final _cTrack = AppColors.kPurple.withOpacity(
    0.15,
  );

  double _normAngle(
    double a,
  ) {
    while (a <
        0) {
      a +=
          2 *
          math.pi;
    }
    while (a >=
        2 *
            math.pi) {
      a -=
          2 *
          math.pi;
    }
    return a;
  }

  bool _angleWithin(
    double angle,
    double start,
    double sweep,
  ) {
    final end = _normAngle(
      start +
          sweep,
    );
    angle = _normAngle(
      angle,
    );
    if (sweep <=
        0)
      return false;
    if (start <=
        end) {
      return angle >=
              start &&
          angle <=
              end;
    } else {
      return angle >=
              start ||
          angle <=
              end;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (
        _,
      ) {
        getProfileId(
          context,
        );
      },
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final exp =
        (widget.expenses ??
                0)
            .clamp(
              0,
              double.infinity,
            );
    final ern =
        (widget.earnings ??
                0)
            .clamp(
              0,
              double.infinity,
            );
    final base =
        ern;

    double sweepExp = 0;
    double sweepErn = 0;

if (base > 0) {
  final used = exp.clamp(0, base);
  sweepExp = 180.0 * (used / base);
  sweepErn = 180.0 - sweepExp;
} else {
  sweepErn = 180.0;
}

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown:
            (
              d,
            ) {
              final rect =
                  Rect.fromLTWH(
                    0,
                    0,
                    _size.width,
                    _size.height,
                  ).deflate(
                    _deflate,
                  );
              final center = rect.center;
              final rOuter =
                  rect.width /
                  2;
              final inner =
                  rOuter -
                  _stroke /
                      2 -
                  _hitSlop;
              final outer =
                  rOuter +
                  _stroke /
                      2 +
                  _hitSlop;

              final box =
                  context.findRenderObject()
                      as RenderBox?;
              if (box ==
                  null)
                return;
              final local = box.globalToLocal(
                d.globalPosition,
              );

              final dx =
                  local.dx -
                  center.dx;
              final dy =
                  local.dy -
                  center.dy;
              final r = math.sqrt(
                dx *
                        dx +
                    dy *
                        dy,
              );
              if (r <
                      inner ||
                  r >
                      outer)
                return;

              double angleFromPlusX = _normAngle(
                math.atan2(
                  dy,
                  dx,
                ),
              );
              if (angleFromPlusX <
                  math.pi)
                return;
              final semi =
                  angleFromPlusX -
                  math.pi;

              final expVal = exp;
              final ernVal = ern;
              final baseVal =
                  ernVal;
              double expSweep = 0;
              double ernSweep = 0;

              if (baseVal >
                  0) {
                expSweep =
                    math.pi *
                    (expVal.clamp(
                          0,
                          baseVal,
                        ) /
                        baseVal);
                ernSweep = math.pi - expSweep;
              } else {
                ernSweep = math.pi;
              }

              final startExp = math.pi;
              final startErn =
                  startExp +
                  expSweep;
              final absAngle =
                  semi +
                  math.pi;

              String? title;
              String? value;

              if (_angleWithin(
                absAngle,
                startExp,
                expSweep,
              )) {
                title = 'Expenses';
                value = '${expVal.toStringAsFixed(0)} SAR';
              } else if (_angleWithin(
                absAngle,
                startErn,
                ernSweep,
              )) {
                title = 'Earnings';
                value = '${ernVal.toStringAsFixed(0)} SAR';
              } else {
                return;
              }

              setState(
                () {
                  final left =
                      (local.dx -
                              110)
                          .clamp(
                            0.0,
                            _size.width -
                                220.0,
                          );
                  final top =
                      (local.dy -
                              56)
                          .clamp(
                            0.0,
                            _size.height -
                                68.0,
                          );
                  _tipPos = Offset(
                    left,
                    top,
                  );
                  _tipTitle = title!;
                  _tipValue = value!;
                },
              );

              _hideTimer?.cancel();
              _hideTimer = Timer(
                const Duration(
                  milliseconds: 2200,
                ),
                () {
                  if (mounted) {
                    setState(
                      () => _tipPos = null,
                    );
                  }
                },
              );
            },
        child: SizedBox(
          width: _size.width,
          height: _size.height,
          child: Stack(
            children: [
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
              if (sweepExp >
                  0)
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
              if (sweepErn >
                  0)
                CustomPaint(
                  size: _size,
                  painter: _ArcPainter(
                    color: _cEarnings,
                    startDeg:
                        180 +
                        sweepExp,
                    sweepDeg: sweepErn,
                    stroke: _stroke,
                    deflate: _deflate,
                  ),
                ),
 
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(
                    0,
                    -0.2,
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.nunito,
                      color: AppColors.kText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (_tipPos !=
                  null)
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

class _ArcPainter
    extends
        CustomPainter {
  final double startDeg;
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
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final rect =
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ).deflate(
          deflate,
        );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final startRad =
        startDeg *
        math.pi /
        180.0;
    final sweepRad =
        sweepDeg *
        math.pi /
        180.0;
    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ArcPainter old,
  ) {
    return old.color !=
            color ||
        old.sweepDeg !=
            sweepDeg ||
        old.startDeg !=
            startDeg ||
        old.stroke !=
            stroke ||
        old.deflate !=
            deflate;
  }
}

class _PurpleBubble
    extends
        StatelessWidget {
  final String title;
  final String value;

  const _PurpleBubble({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(
        milliseconds: 120,
      ),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: AppGradients.purpleBtn,
          borderRadius: BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(
              0.35,
            ),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.kPurpleDark.withOpacity(
                0.28,
              ),
              blurRadius: 16,
              offset: const Offset(
                0,
                8,
              ),
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
                fontFamily: AppTextStyles.nunito,
                color: AppColors.kText,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTextStyles.nunito,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
