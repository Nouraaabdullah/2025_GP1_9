import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

/* Theme */
const _bg = Color(0xFF1D1B32);
const _panel = Color(0xFF211E41);
const _card = Color(0xFF211E41);
const _inactive = Color(0xFFA6A6A6);
const _accentPrimary = Color(0xFF4A37E1);
const _accentSecondary = Color(0xFFBA55D6);
const _accentTertiary = Color(0xFF64CFF6);
const _barBg = Color(0xFF8C89B4);

const kFigmaAnim = Duration(milliseconds: 300);
const kFigmaCurve = Curves.easeInOut;

class _DashboardPageState extends State<DashboardPage> {
  final _chartController = PageController();
  final _legendController = PageController(viewportFraction: 0.92);

  int _chartIndex = 0;
  int _periodIndex = 0;

  final List<List<_LegendItem>> _legendsPerPage = [
    const [
      _LegendItem('Income', '451 SAR'),
      _LegendItem('Earnings', '451 SAR'),
      _LegendItem('Expenses', '451 SAR'),
    ],
    const [
      _LegendItem('Food', '451 SAR'),
      _LegendItem('Transport', '210 SAR'),
      _LegendItem('Bills', '320 SAR'),
      _LegendItem('Shopping', '165 SAR'),
      _LegendItem('Other', '90 SAR'),
    ],
    const [
      _LegendItem('Income', '451 SAR'),
      _LegendItem('Earnings', '451 SAR'),
      _LegendItem('Expenses', '451 SAR'),
    ],
  ];

  @override
  void dispose() {
    _chartController.dispose();
    _legendController.dispose();
    super.dispose();
  }

  void _onChartChanged(int i) {
    setState(() => _chartIndex = i);
    _legendController.animateToPage(
      0,
      duration: kFigmaAnim,
      curve: kFigmaCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final legends = _legendsPerPage[_chartIndex];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // extra bottom padding so content stays above the fixed bar
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavigationBarHeight + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderPanel(
                periodIndex: _periodIndex,
                onPeriodChanged: (i) => setState(() => _periodIndex = i),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 280,
                child: PageView(
                  controller: _chartController,
                  onPageChanged: _onChartChanged,
                  children: const [
                    _ChartSemicircleGauge(percent: 0.75, label: '%75\nbalance left'),
                    _ChartRing(label: 'Total Expenses\n2300 SAR'),
                    _ChartBars(),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Legend',
                    style: TextStyle(
                      color: _inactive,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _Dots(count: 3, index: 0),
                ],
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 96,
                child: PageView.builder(
                  controller: _legendController,
                  padEnds: false,
                  itemCount: (legends.length / 3).ceil(),
                  itemBuilder: (context, page) {
                    final start = page * 3;
                    final end = (start + 3).clamp(0, legends.length);
                    final slice = legends.sublist(start, end);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: slice
                          .map((e) => _LegendCard(title: e.title, value: e.value))
                          .toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              const _SectionTitle('Goals Progress'),
              const SizedBox(height: 10),

              const _GoalCardGlowy(
                title: 'Buy a new Car',
                percent: 0.75,
                tip: 'You should save 5% more this week!',
              ),
              const SizedBox(height: 12),
              const _GoalCardGlowy(
                title: 'Buy a new Car',
                percent: 0.75,
                tip: 'You should save 5% more this week!',
              ),

              const SizedBox(height: 14),

              const _MotivationCard(
                title: 'Keep it up!',
                body: 'You’re making great progress.',
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onTapSavings:   () {}, // already here
        onTapProfile:   () => Navigator.pushReplacementNamed(context, '/profile'),
       
      ),
    );
  }
}

/* Header with chips */
class _HeaderPanel extends StatelessWidget {
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;
  const _HeaderPanel({required this.periodIndex, required this.onPeriodChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int i) {
      final selected = periodIndex == i;
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onPeriodChanged(i),
        child: AnimatedContainer(
          duration: kFigmaAnim,
          curve: kFigmaCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _panel, width: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _inactive,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Income: 3000SAR',
            style: TextStyle(
              color: _inactive,
              fontSize: 15.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              chip('Weekly', 0),
              const SizedBox(width: 8),
              chip('Monthly', 1),
              const SizedBox(width: 8),
              chip('Yearly', 2),
            ],
          ),
        ],
      ),
    );
  }
}

/* Legend */
class _LegendItem {
  final String title;
  final String value;
  const _LegendItem(this.title, this.value);
}

class _LegendCard extends StatelessWidget {
  final String title;
  final String value;
  const _LegendCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 86,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: const BoxDecoration(
              color: _bg,
              shape: BoxShape.circle,
            ),
          ),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _inactive,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* Goals with glow dots */
class _GoalCardGlowy extends StatelessWidget {
  final String title;
  final double percent;
  final String tip;
  const _GoalCardGlowy({
    required this.title,
    required this.percent,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF373542),
        borderRadius: BorderRadius.circular(13.4),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 21,
                decoration: BoxDecoration(
                  color: _barBg,
                  borderRadius: BorderRadius.circular(14.5),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) => AnimatedContainer(
                  duration: kFigmaAnim,
                  curve: kFigmaCurve,
                  height: 21,
                  width: c.maxWidth * percent,
                  decoration: BoxDecoration(
                    color: _accentPrimary,
                    borderRadius: BorderRadius.circular(14.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _GlowDot(color: _accentPrimary, size: 28, blur: 28),
              SizedBox(width: 12),
              _GlowDot(color: _accentSecondary, size: 28, blur: 28),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip,
            style: const TextStyle(
              color: _inactive,
              fontSize: 13.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;
  const _GlowDot({required this.color, this.size = 24, this.blur = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.75),
            blurRadius: blur,
            spreadRadius: blur * 0.85,
          ),
        ],
      ),
    );
  }
}

/* Motivation card */
class _MotivationCard extends StatelessWidget {
  final String title;
  final String body;
  const _MotivationCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF8E8FF), Color(0xFFF2EFFF)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF8AF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF696868),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* Chart placeholders */
class _ChartSemicircleGauge extends StatelessWidget {
  final double percent;
  final String label;
  const _ChartSemicircleGauge({required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 275,
        height: 268,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(275, 268),
              painter: _ArcPainter(color: Color(0xFF3A3A5A), sweep: 180),
            ),
            CustomPaint(
              size: const Size(275, 268),
              painter: _ArcPainter(color: _accentSecondary, sweep: 180 * percent * 0.3),
            ),
            CustomPaint(
              size: const Size(275, 268),
              painter: _ArcPainter(color: _accentTertiary, sweep: 180 * percent),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartRing extends StatelessWidget {
  final String label;
  const _ChartRing({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _panel,
            ),
          ),
          Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(18),
            child: CircularProgressIndicator(
              value: 0.72,
              backgroundColor: const Color(0xFF3A3A5A),
              strokeWidth: 22,
              color: _accentPrimary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }
}

class _ChartBars extends StatelessWidget {
  const _ChartBars();

  @override
  Widget build(BuildContext context) {
    final bars = [0.9, 0.55, 0.8, 0.62, 0.95, 0.5, 0.7, 0.6];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: bars
            .map((v) => AnimatedContainer(
                  duration: kFigmaAnim,
                  curve: kFigmaCurve,
                  width: 16,
                  height: 170 * v,
                  decoration: BoxDecoration(
                    color: v > 0.8 ? _accentTertiary : _accentPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double sweep;
  final Color color;
  const _ArcPainter({required this.color, required this.sweep});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(14),
      3.1415926,
      sweep * 3.1415926 / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.color != color || old.sweep != sweep;
}

/* Small helpers */
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Goals Progress',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: kFigmaAnim,
          curve: kFigmaCurve,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF4E4B74),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
