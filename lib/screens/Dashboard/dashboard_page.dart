// lib/pages/Dashboard/dashboard_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';

// Charts split into separate files
import 'income_chart.dart';
import 'trends_chart.dart';
import 'savings_chart.dart';
import 'category_chart.dart'; // exposes CategorySlice + colorFromIconOrSeed

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _periodIndex = 1; // 0 Weekly, 1 Monthly, 2 Yearly
  bool _showAllCategories = false;

  // Accent palette
  static const _violet = Color(0xFF8B5CF6);
  static const _cyan   = Color(0xFF22D3EE);
  static const _muted  = Color(0xFF8C89B4);

  static const double _betweenTitleAndCard = 10;

  // ===== Data =====
  num _balance = 0;

  List<String> _bucketLabels = [];
  List<num> _seriesExpenses = [];
  List<num> _seriesEarnings = [];
  List<num> _seriesIncome = [];
  List<CategorySlice> _categorySlices = [];
  List<num> _savingsSeries = [];

  bool _loading = true;
  String? _error;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });

    try {
      // final profileId = await _getProfileId();
      // TEMP hardcoded profile_id
      const profileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';

      // 1) Balance
      final prof = await _sb
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', profileId)
          .single();
      _balance = (prof['current_balance'] as num?) ?? 0;

      // 2) Period window
      final now = DateTime.now();
      DateTime start;
      DateTime end;
      if (_periodIndex == 0) {
        start = DateTime(now.year, now.month, 1);
        end   = DateTime(now.year, now.month + 1, 0);
        _bucketLabels = const ['W1','W2','W3','W4'];
      } else if (_periodIndex == 1) {
        start = DateTime(now.year, 1, 1);
        end   = DateTime(now.year, 12, 31);
        _bucketLabels = const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      } else {
        start = DateTime(now.year - 4, 1, 1);
        end   = DateTime(now.year, 12, 31);
      }

      // 3) Query rows
      final trxRows = await _sb
          .from('Transaction')
          .select('type, amount, date, category_id')
          .eq('profile_id', profileId)
          .gte('date', _iso(start))
          .lte('date', _iso(end));

      final fixedIncomeRows = await _sb
          .from('Fixed_Income')
          .select('monthly_income, start_time, end_time')
          .eq('profile_id', profileId);

      final fixedExpenseRows = await _sb
          .from('Fixed_Expense')
          .select('amount')
          .eq('profile_id', profileId);

      final catSummaryRows = await _sb
          .from('Category_Summary')
          .select('total_expense, category_id, record_id');

      final catRows = await _sb
          .from('Category')
          .select('category_id, name, icon_color')
          .eq('profile_id', profileId)
          .eq('is_archived', false);

      final mfrRows = await _sb
          .from('Monthly_Financial_Record')
          .select('period_start, monthly_saving, profile_id')
          .eq('profile_id', profileId)
          .gte('period_start', _iso(DateTime(now.year, 1, 1)))
          .lte('period_start', _iso(DateTime(now.year, 12, 31)));

      // 4) Build buckets
      final buckets = (_periodIndex == 0)
          ? _buildWeeklyBuckets(start, end)
          : (_periodIndex == 1)
              ? _buildMonthlyBuckets(start.year)
              : _buildYearlyBuckets(start.year, end.year);

      // Map category id to name and color (icon_color or seeded)
      final catNameById = <String, String>{
        for (final r in catRows) r['category_id'] as String : (r['name'] as String),
      };
      final catColorById = <String, Color>{
        for (final r in catRows)
          r['category_id'] as String : colorFromIconOrSeed(
            categoryId: r['category_id'] as String,
            iconHex: r['icon_color'] as String?,
          ),
      };

      // Helper to place a date into a bucket index
      int bucketIndex(DateTime d) {
        if (_periodIndex == 0) {
          final dom = d.day;
          if (dom <= 7) return 0;
          if (dom <= 14) return 1;
          if (dom <= 21) return 2;
          return 3;
        } else if (_periodIndex == 1) {
          return d.month - 1;
        } else {
          return d.year - buckets.first.year!;
        }
      }

      // Reset series sized to bucket count
      final n = buckets.length;
      _seriesExpenses = List.filled(n, 0);
      _seriesEarnings = List.filled(n, 0);
      _seriesIncome   = List.filled(n, 0);

      // Transactions
      for (final r in trxRows) {
        final type = (r['type'] as String?) ?? '';
        final amt  = (r['amount'] as num?) ?? 0;
        final date = DateTime.parse(r['date'] as String);
        if (date.isBefore(start) || date.isAfter(end)) continue;
        final i = bucketIndex(date);
        if (i < 0 || i >= n) continue;
        if (type == 'Expense') {
          _seriesExpenses[i] += amt;
        } else if (type == 'Earning') {
          _seriesEarnings[i] += amt;
        }
      }

      // Fixed Income spread by period
      for (final r in fixedIncomeRows) {
        final monthly = (r['monthly_income'] as num?) ?? 0;
        final st = _parseOrNull(r['start_time']);
        final en = _parseOrNull(r['end_time']);
        for (var i = 0; i < n; i++) {
          final mid = buckets[i].middleDate;
          if (mid == null) continue;
          final active = (st == null || !mid.isBefore(st)) && (en == null || !mid.isAfter(en));
          if (!active) continue;
          if (_periodIndex == 0) {
            _seriesIncome[i] += monthly / 4;
          } else if (_periodIndex == 1) {
            _seriesIncome[i] += monthly;
          } else {
            _seriesIncome[i] += monthly * 12;
          }
        }
      }

      // Fixed Expenses
      for (final r in fixedExpenseRows) {
        final monthly = (r['amount'] as num?) ?? 0;
        for (var i = 0; i < n; i++) {
          if (_periodIndex == 0) {
            _seriesExpenses[i] += monthly / 4;
          } else if (_periodIndex == 1) {
            _seriesExpenses[i] += monthly;
          } else {
            _seriesExpenses[i] += monthly * 12;
          }
        }
      }

      // Labels
      if (_periodIndex == 2) {
        _bucketLabels = [for (final b in buckets) '${b.year}'];
      } else if (_periodIndex == 0) {
        _bucketLabels = const ['W1','W2','W3','W4'];
      } else {
        _bucketLabels = const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      }

      // Category totals
      final catTotals = <String, num>{};
      if (_periodIndex == 2) {
        for (final r in catSummaryRows) {
          final cat = r['category_id'] as String?;
          final amt = (r['total_expense'] as num?) ?? 0;
          if (cat == null) continue;
          catTotals[cat] = (catTotals[cat] ?? 0) + amt;
        }
      } else {
        for (final r in catSummaryRows) {
          final cat = r['category_id'] as String?;
          final amt = (r['total_expense'] as num?) ?? 0;
          if (cat == null) continue;
          catTotals[cat] = (catTotals[cat] ?? 0) + amt;
        }
      }

      // Build slices with category colors
      _categorySlices = [
        for (final e in catTotals.entries)
          if (e.value > 0)
            CategorySlice(
              id: e.key,
              name: catNameById[e.key] ?? 'Unknown',
              value: e.value,
              color: catColorById[e.key] ?? colorFromIconOrSeed(categoryId: e.key),
            ),
      ]..sort((a,b) => b.value.compareTo(a.value));

      // Savings sparkline
      final months = <int, num>{};
      for (final r in mfrRows) {
        final p = DateTime.parse(r['period_start'] as String);
        months[p.month] = (r['monthly_saving'] as num?) ?? 0;
      }
      _savingsSeries = [for (var m=1; m<=12; m++) (months[m] ?? 0)];

      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ===== Helpers =====
  String _iso(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  DateTime? _parseOrNull(dynamic s) => (s == null) ? null : DateTime.tryParse(s as String);

  Future<String> _getProfileId() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    final row = await _sb.from('User_Profile').select('profile_id').eq('user_id', uid).single();
    return row['profile_id'] as String;
  }

  List<_Bucket> _buildWeeklyBuckets(DateTime mStart, DateTime mEnd) => [
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 7)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 14)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 21)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 28)),
      ];

  List<_Bucket> _buildMonthlyBuckets(int year) =>
      [for (var m=1; m<=12; m++) _Bucket(year, m, DateTime(year, m, 15))];

  List<_Bucket> _buildYearlyBuckets(int y1, int y2) =>
      [for (var y=y1; y<=y2; y++) _Bucket(y, null, DateTime(y, 6, 15))];

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()))
        : (_error != null)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Text('Could not load dashboard: $_error', style: const TextStyle(color: Colors.white70)),
                ),
              )
            : _buildBody(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: content),
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onTapSavings:   () {},
        onTapProfile:   () => Navigator.pushReplacementNamed(context, '/profile'),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final totalExpenses = _seriesExpenses.fold<num>(0, (a,b) => a+b);
    final totalEarnings = _seriesEarnings.fold<num>(0, (a,b) => a+b);
    final totalIncome   = _seriesIncome.fold<num>(0, (a,b) => a+b);

    final denom = (totalIncome + totalEarnings);
    final left  = math.max(0, denom - totalExpenses);
    final percentLeft = denom <= 0 ? 0.0 : (left / denom).clamp(0, 1).toDouble();

    final incomeLegends = [
      _LegendItem('Expenses', '${totalExpenses.toStringAsFixed(0)} SAR', _violet),
      _LegendItem('Earnings', '${totalEarnings.toStringAsFixed(0)} SAR', _cyan),
      _LegendItem('Income',   '${totalIncome.toStringAsFixed(0)} SAR', _muted),
    ];

    final monthlyLegends = [
      _LegendItem('Expenses', '${totalExpenses.toStringAsFixed(0)} SAR', _violet),
      _LegendItem('Earnings', '${totalEarnings.toStringAsFixed(0)} SAR', _cyan),
      _LegendItem('Income',   '${totalIncome.toStringAsFixed(0)} SAR', _muted),
    ];

    final catItems = [
      for (final s in _categorySlices.take(_showAllCategories ? _categorySlices.length : 5))
        _LegendItem(s.name, '${s.value.toStringAsFixed(0)} SAR', s.color),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavigationBarHeight + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Balance glow
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
                      colors: [AppColors.accent.withOpacity(0.27), Colors.transparent],
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
                  shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 4)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Balance: ${_balance.toStringAsFixed(0)} SAR',
              style: TextStyle(color: AppColors.textGrey, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),

          _HeaderPanel(
            periodIndex: _periodIndex,
            onPeriodChanged: (i) => setState(() { _periodIndex = i; _loadAll(); }),
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
                IncomeSemicircleGauge(percent: percentLeft, label: '${(percentLeft*100).round()}% of\nincome left'),
                const SizedBox(height: 12),
                _LegendRow(items: incomeLegends),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Trends
          const _BlockTitle('Financial Trends'),
          const SizedBox(height: _betweenTitleAndCard),
          _SectionCard(
            onInfo: () => _showInfo(context, 'Comparison bars for expenses, earnings, and income.'),
            child: Column(
              children: [
                const SizedBox(height: 8),
                TrendsGroupedBars(
                  labels: _bucketLabels,
                  seriesA: _seriesExpenses.map((e) => e.toDouble()).toList(),
                  seriesB: _seriesEarnings.map((e) => e.toDouble()).toList(),
                  seriesC: _seriesIncome.map((e) => e.toDouble()).toList(),
                  colorA: _violet,
                  colorB: _cyan,
                  colorC: _muted,
                ),
                const SizedBox(height: 12),
                _LegendRow(items: monthlyLegends),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Savings Over Time
          const _BlockTitle('Savings Over Time'),
          const SizedBox(height: _betweenTitleAndCard),
          _SectionCard(
            onInfo: () => _showInfo(context, 'Line of savings balance across months.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: SavingsSparkline(values: _savingsSeries.map((e) => e.toDouble()).toList()),
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
                CategoryDonut(
                  slices: _categorySlices,
                  centerLabel: 'Total Expenses\n﷼ ${(_seriesExpenses.fold<num>(0,(a,b)=>a+b)).toStringAsFixed(0)}',
                ),
                const SizedBox(height: 12),
                if (_categorySlices.isEmpty)
                  Center(child: Text('No category data', style: TextStyle(color: AppColors.textGrey)))
                else
                  _CategoryGrid(
                    items: catItems,
                    showAll: _showAllCategories,
                    initialCount: 3,
                  ),
                const SizedBox(height: 8),
                if (_categorySlices.length > 3)
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
          const SizedBox(height: 18),

          const _MotivationCard(
            title: 'Small Wins, Big Future',
            subtitle: 'Keep making the little moves those are the ones that quietly build your future.',
          ),
        ],
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

/* ================= Helper data holders ================= */
class _Bucket {
  final int? year;
  final int? month;
  final DateTime? middleDate;
  _Bucket(this.year, this.month, this.middleDate);
}

/* ================= Shared UI bits ================= */
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

class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3),
    );
  }
}

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
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.85), color.withOpacity(0.15)],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, spreadRadius: 0.5)],
        border: Border.all(color: color.withOpacity(0.8), width: 1),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_LegendItem> items;
  final bool showAll;
  final int initialCount;
  const _CategoryGrid({required this.items, required this.showAll, this.initialCount = 3});

  @override
  Widget build(BuildContext context) {
    final visible = showAll ? items : items.take(initialCount).toList();
    if (visible.isEmpty) {
      return Center(child: Text('No categories', style: TextStyle(color: AppColors.textGrey)));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 98 / 86,
      ),
      itemBuilder: (_, i) => _LegendCard(item: visible[i]),
    );
  }
}

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          chip('Weekly', 0),
          const SizedBox(width: 8),
          chip('Monthly', 1),
          const SizedBox(width: 8),
          chip('Yearly', 2),
        ],
      ),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _MotivationCard({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card.withOpacity(0.55), AppColors.card.withOpacity(0.35)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFFFFF7D6), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.star_rounded, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
