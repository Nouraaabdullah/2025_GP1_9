import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _periodIndex = 0;
  bool _showAllCategories = false;

  // Accent palette (matches SavingsPage vibe)
  static const _violet = Color(0xFF8B5CF6);
  static const _cyan   = Color(0xFF22D3EE);
  static const _amber  = Color(0xFFFFB020);
  static const _rose   = Color(0xFFFF7AB6);
  static const _mint   = Color(0xFF34D399);
  static const _muted  = Color(0xFF8C89B4);

  // Legends
  final List<_LegendItem> _incomeLegends = const [
    _LegendItem('Expenses', '451 SAR', _violet),
    _LegendItem('Earnings', '300 SAR', _cyan),
    _LegendItem('Income',   '151 SAR', _muted),
  ];

  final List<_LegendItem> _monthlyLegends = const [
    _LegendItem('Expenses', '451 SAR', _violet),
    _LegendItem('Earnings', '300 SAR', _cyan),
    _LegendItem('Income',   '151 SAR', _muted),
  ];

  final List<_LegendItem> _categoryLegends = const [
    _LegendItem('Food',      '451 SAR', _rose),
    _LegendItem('Transport', '210 SAR', _cyan),
    _LegendItem('Bills',     '320 SAR', _amber),
    _LegendItem('Shopping',  '165 SAR', _violet),
    _LegendItem('Other',      '90 SAR', _mint),
  ];

  static const double _betweenTitleAndCard = 10; // extra breathing space

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavigationBarHeight + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title (sits cleanly at the very top)
              Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 6,
                    child: Container(
                      width: 220,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.27),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Statistics Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Color(0x33000000),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _HeaderPanel(
                periodIndex: _periodIndex,
                onPeriodChanged: (i) => setState(() => _periodIndex = i),
              ),
              const SizedBox(height: 18),

              // Income Overview
              const _BlockTitle('Income Overview'),
              const SizedBox(height: _betweenTitleAndCard),
              _SectionCard(
                onInfo: () => _showInfo(context, 'Shows remaining income and recent distribution.'),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _ChartSemicircleGauge(percent: 0.50, label: '50% of\nincome left'),
                    const SizedBox(height: 12),
                    _LegendRow(items: _incomeLegends),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Monthly Trends
              const _BlockTitle('Monthly Trends'),
              const SizedBox(height: _betweenTitleAndCard),
              _SectionCard(
                onInfo: () => _showInfo(context, 'Monthly bars for expenses, earnings, and income.'),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _ChartBars(),
                    const SizedBox(height: 12),
                    _LegendRow(items: _monthlyLegends),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Savings Over Time (no legend here)
              const _BlockTitle('Savings Over Time'),
              const SizedBox(height: _betweenTitleAndCard),
              _SectionCard(
                onInfo: () => _showInfo(context, 'Line of savings balance across months.'),
                child: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 10),
                  child: _ChartLinePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category Breakdown
              const _BlockTitle('Category Breakdown'),
              const SizedBox(height: _betweenTitleAndCard),
              _SectionCard(
                onInfo: () => _showInfo(context, 'Your expenses grouped by category.'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const _ChartRing(label: 'Total Expenses\n﷼ 2300'),
                    const SizedBox(height: 12),

                    _CategoryGrid(
                      items: _categoryLegends,
                      showAll: _showAllCategories,
                      initialCount: 3, // 3 per row to avoid crowding
                    ),

                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                      ),
                      onPressed: () => setState(() => _showAllCategories = !_showAllCategories),
                      child: Text(_showAllCategories ? 'Show less' : 'Show more'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onTapSavings:   () {},
        onTapProfile:   () => Navigator.pushReplacementNamed(context, '/profile'),
      ),
    );
  }

  void _showInfo(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text('About this chart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.4)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/* ================= Header with chips (SavingsPage vibe) ================= */
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
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.card.withOpacity(0.7),
                AppColors.card.withOpacity(0.45),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card.withOpacity(0.6),
            AppColors.card.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance: 3000SAR',
              style: TextStyle(color: AppColors.textGrey, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
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

/* ================= Section card with i icon ================= */
class _SectionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onInfo;
  const _SectionCard({required this.child, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card.withOpacity(0.55),
            AppColors.card.withOpacity(0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 2),
            child: child,
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.info_outline, color: AppColors.textGrey),
              onPressed: onInfo,
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= Titles outside the cards ================= */
class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3),
    );
  }
}

/* ================= Legend UI ================= */
class _LegendItem {
  final String title;
  final String value;
  final Color color;
  const _LegendItem(this.title, this.value, this.color);
}

class _LegendRow extends StatelessWidget {
  final List<_LegendItem> items;
  const _LegendRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((e) => _LegendCard(item: e)).toList(),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final _LegendItem item;
  const _LegendCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 86,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LegendDot(color: item.color),
          Column(
            children: [
              Text(item.title, style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(item.value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) {
    // softer glow
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.85),
            color.withOpacity(0.15),
          ],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, spreadRadius: 0.5),
        ],
        border: Border.all(color: color.withOpacity(0.8), width: 1),
      ),
    );
  }
}

/* ============ Category legend: 3 per row, more on expand ============ */
class _CategoryGrid extends StatelessWidget {
  final List<_LegendItem> items;
  final bool showAll;
  final int initialCount;
  const _CategoryGrid({required this.items, required this.showAll, this.initialCount = 3});

  @override
  Widget build(BuildContext context) {
    final visible = showAll ? items : items.take(initialCount).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,                 // less crowded
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 98 / 86,
      ),
      itemBuilder: (_, i) => _LegendCard(item: visible[i]),
    );
  }
}

/* ================= Charts ================= */
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
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: const Color(0xFF3A3A5A), sweep: 180)),
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: Color(0xFF8B5CF6), sweep: 180 * percent * 0.3)),
            CustomPaint(size: const Size(275, 268), painter: _ArcPainter(color: Color(0xFF22D3EE), sweep: 180 * percent)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22.6, fontWeight: FontWeight.w400)),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card.withOpacity(0.8),
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
              color: AppColors.accent,
            ),
          ),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: bars
            .map(
              (v) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 16,
                height: 170 * v,
                decoration: BoxDecoration(
                  color: v > 0.8 ? const Color(0xFF22D3EE) : AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: AppColors.accent.withOpacity(0.18), blurRadius: 6),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChartLinePlaceholder extends StatelessWidget {
  const _ChartLinePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text('Line chart placeholder', style: TextStyle(color: AppColors.textGrey)),
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
    canvas.drawArc(rect.deflate(14), 3.1415926, sweep * 3.1415926 / 180, false, paint);
  }
  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.color != color || old.sweep != sweep;
}
