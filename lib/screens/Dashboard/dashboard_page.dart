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

  // Filtered (for charts 2–4)
  List<String> _bucketLabels = [];
  List<num> _seriesExpenses = [];
  List<num> _seriesEarnings = [];
  List<num> _seriesIncome = [];
  List<CategorySlice> _categorySlices = [];
  List<num> _savingsSeries = [];
  List<String> _savingsLabels = [];
  // NEW: Raw series & buckets for Income Overview (no “drop empty”)
  List<_Bucket> _allBuckets = [];
  List<num> _rawExpenses = [];
  List<num> _rawEarnings = [];
  List<num> _rawIncome   = [];
  List<String> _rawLabels = [];

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

    // ---- helpers ----
    String _iso(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    DateTime? _parseOrNull(dynamic s) => (s == null) ? null : DateTime.tryParse(s as String);
    int _lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0).day;
    int _weekIndexFromDay(int day) => (day <= 7) ? 0 : (day <= 14) ? 1 : (day <= 22) ? 2 : 3;

    // months whose PAYDAY is in [st, en]
    int _monthsActiveByPayday(DateTime? st, DateTime? en, int year, int payday) {
      int cnt = 0;
      for (int m = 1; m <= 12; m++) {
        final pd = math.min(payday, _lastDayOfMonth(year, m));
        final payDate = DateTime(year, m, pd);
        final afterStart = (st == null) || !payDate.isBefore(st);
        final beforeEnd  = (en == null) || !payDate.isAfter(en);
        if (afterStart && beforeEnd) cnt++;
      }
      return cnt;
    }

    try {
      // final profileId = await _getProfileId();
      const profileId = '135dee2a-e3ec-47c3-abf5-8f4ed707c3db';

      // 1) balance
      final prof = await _sb
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', profileId)
          .single();
      _balance = (prof['current_balance'] as num?) ?? 0;

      // 2) range
      final now = DateTime.now();
      late DateTime rangeStart, rangeEnd;
      if (_periodIndex == 0) {
        rangeStart = DateTime(now.year, now.month, 1);
        rangeEnd   = DateTime(now.year, now.month + 1, 0);
      } else if (_periodIndex == 1) {
        rangeStart = DateTime(now.year, 1, 1);
        rangeEnd   = DateTime(now.year, 12, 31);
      } else {
        rangeStart = DateTime(now.year - 4, 1, 1);
        rangeEnd   = DateTime(now.year, 12, 31);
      }

      // 3) queries
      final trxRows = await _sb
          .from('Transaction')
          .select('type, amount, date, category_id')
          .eq('profile_id', profileId)
          .gte('date', _iso(rangeStart))
          .lte('date', _iso(rangeEnd));

      final fixedIncomeRows = await _sb
          .from('Fixed_Income')
          .select('monthly_income, start_time, end_time, payday')
          .eq('profile_id', profileId);

      final fixedExpenseRows = await _sb
          .from('Fixed_Expense')
          .select('amount, category_id, due_date, start_time, end_time')
          .eq('profile_id', profileId);

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

      // 4) buckets
      final buckets = (_periodIndex == 0)
          ? _buildWeeklyBuckets(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0))
          : (_periodIndex == 1)
              ? _buildMonthlyBuckets(rangeStart.year)
              : _buildYearlyBuckets(rangeStart.year, rangeEnd.year);
      _allBuckets = buckets; // save raw buckets

      // maps
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

      int bucketIndex(DateTime d) {
        if (_periodIndex == 0) {
          // Weekly: W1=1–7, W2=8–14, W3=15–22, W4=23–end
          final dom = d.day;
          if (dom <= 7)  return 0;
          if (dom <= 14) return 1;
          if (dom <= 22) return 2; // <-- was 21
          return 3;
        } else if (_periodIndex == 1) {
          return d.month - 1;
        } else {
          return d.year - (buckets.first.year ?? d.year);
        }
      }


      // 5) reset series (RAW + filtered)
      final n = buckets.length;
      // raw (no filtering)
      _rawExpenses = List.filled(n, 0);
      _rawEarnings = List.filled(n, 0);
      _rawIncome   = List.filled(n, 0);
      // to-be-filtered (start same as raw; will be filtered later)
      _seriesExpenses = List.filled(n, 0);
      _seriesEarnings = List.filled(n, 0);
      _seriesIncome   = List.filled(n, 0);

      // 6) variable transactions by their actual date
      for (final r in trxRows) {
        final type = (r['type'] as String?) ?? '';
        final amt  = (r['amount'] as num?) ?? 0;
        final date = DateTime.parse(r['date'] as String);
        if (date.isBefore(rangeStart) || date.isAfter(rangeEnd)) continue;
        final i = bucketIndex(date);
        if (i < 0 || i >= n) continue;
        if (type == 'Expense') {
          _rawExpenses[i]   += amt;  // <- included in first chart
          _seriesExpenses[i] += amt; // <- included in trends/category
        } else if (type == 'Earning') {
          _rawEarnings[i]   += amt;
          _seriesEarnings[i] += amt;
        }
      }


      // 7) fixed income (monthly fix + weekly spread)
      for (final r in fixedIncomeRows) {
        final monthly = (r['monthly_income'] as num?) ?? 0;
        final st = _parseOrNull(r['start_time']);
        final en = _parseOrNull(r['end_time']);
        final payday = (r['payday'] as int?) ?? 1;

        for (var i = 0; i < n; i++) {
          if (_periodIndex == 2) {
            final y = buckets[i].year!;
            final monthsActive = _monthsActiveByPayday(st, en, y, payday);
            if (monthsActive > 0) {
              _rawIncome[i]   += monthly * monthsActive;
              _seriesIncome[i] += monthly * monthsActive;
            }
          } else if (_periodIndex == 1) {
            // Month counts if the month overlaps [st, en]
            final y = buckets[i].year!, m = buckets[i].month!;
            final firstDay = DateTime(y, m, 1);
            final lastDay  = DateTime(y, m + 1, 0);
            final overlaps =
                (st == null || !lastDay.isBefore(st)) &&
                (en == null || !firstDay.isAfter(en));
            if (overlaps) {
              _rawIncome[i]   += monthly;
              _seriesIncome[i] += monthly;
            }
          } else {
            // WEEKLY → distribute monthly/4 if month is active
            final ref = buckets[i].middleDate!;
            final pd = math.min(payday, _lastDayOfMonth(ref.year, ref.month));
            final payDate = DateTime(ref.year, ref.month, pd);
            final activeMonth = (st == null || !payDate.isBefore(st)) && (en == null || !payDate.isAfter(en));
            if (activeMonth) {
              _rawIncome[i]   += monthly / 4;
              _seriesIncome[i] += monthly / 4;
            }
          }
        }
      }

      // 8) fixed expenses (due_date aware): monthly to the due-month, weekly to the due-week, yearly sums
      for (final r in fixedExpenseRows) {
        final monthly = (r['amount'] as num?) ?? 0;
        final dueDay  = (r['due_date'] as int?) ?? 1;
        final st = _parseOrNull(r['start_time']);
        final en = _parseOrNull(r['end_time']);

        for (var i = 0; i < n; i++) {
          if (_periodIndex == 2) {
            final y = buckets[i].year!;
            final monthsActive = _monthsActiveByPayday(st, en, y, dueDay);
            if (monthsActive > 0) {
              _rawExpenses[i]   += monthly * monthsActive;
              _seriesExpenses[i] += monthly * monthsActive;
            }
          } else if (_periodIndex == 1) {
            final ref = DateTime(buckets[i].year!, buckets[i].month!, 15);
            final dd  = math.min(dueDay, _lastDayOfMonth(ref.year, ref.month));
            final dueDate = DateTime(ref.year, ref.month, dd);
            final active = (st == null || !dueDate.isBefore(st)) && (en == null || !dueDate.isAfter(en));
            if (active) {
              _rawExpenses[i]   += monthly;
              _seriesExpenses[i] += monthly;
            }
          } else {
            // weekly → place the full amount in the week that contains the due-day (for the current month)
            final ref = buckets[i].middleDate!;
            final dd  = math.min(dueDay, _lastDayOfMonth(ref.year, ref.month));
            final dueDate = DateTime(ref.year, ref.month, dd);
            final active = (st == null || !dueDate.isBefore(st)) && (en == null || !dueDate.isAfter(en));
            if (active) {
              final idx = _weekIndexFromDay(dd);
              if (idx == i) {
                _rawExpenses[i]   += monthly;
                _seriesExpenses[i] += monthly;
              }
            }
          }
        }
      }

      // 9) labels (raw & filtered)
      if (_periodIndex == 2) {
        _rawLabels = [for (final b in buckets) '${b.year}'];
      } else if (_periodIndex == 0) {
        _rawLabels = const ['W1','W2','W3','W4'];
      } else {
        _rawLabels = const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      }

      // 10) filter out empty buckets for charts (2–4), but KEEP raw for Income Overview
      final filtered = _filterEmpty(_rawLabels, _seriesExpenses, _seriesEarnings, _seriesIncome);
      _bucketLabels   = filtered.labels;
      _seriesExpenses = filtered.expenses;
      _seriesEarnings = filtered.earnings;
      _seriesIncome   = filtered.income;

      // 11) Category totals (variable + fixed expenses) for the selected window
      final catTotals = <String, num>{};

      // variable expenses from Transaction by actual date in range
      for (final r in trxRows) {
        if ((r['type'] as String?) != 'Expense') continue;
        final catId = r['category_id'] as String?;
        if (catId == null) continue;
        final amt = (r['amount'] as num?) ?? 0;
        final date = DateTime.parse(r['date'] as String);
        if (date.isBefore(rangeStart) || date.isAfter(rangeEnd)) continue;
        catTotals[catId] = (catTotals[catId] ?? 0) + amt;
      }

      // fixed expenses add by due date occurrence within the range
      for (final r in fixedExpenseRows) {
        final monthly = (r['amount'] as num?) ?? 0;
        final catId   = r['category_id'] as String?;
        if (catId == null) continue;
        final dueDay  = (r['due_date'] as int?) ?? 1;
        final st = _parseOrNull(r['start_time']);
        final en = _parseOrNull(r['end_time']);

        DateTime iter = DateTime(rangeStart.year, rangeStart.month, 1);
        final endIter = DateTime(rangeEnd.year, rangeEnd.month, 1);
        while (!iter.isAfter(endIter)) {
          final dd = math.min(dueDay, _lastDayOfMonth(iter.year, iter.month));
          final dueDate = DateTime(iter.year, iter.month, dd);
          final inUserRange = !dueDate.isBefore(rangeStart) && !dueDate.isAfter(rangeEnd);
          final active = (st == null || !dueDate.isBefore(st)) && (en == null || !dueDate.isAfter(en));
          if (inUserRange && active) {
            catTotals[catId] = (catTotals[catId] ?? 0) + monthly;
          }
          iter = DateTime(iter.year, iter.month + 1, 1);
        }
      }

      _categorySlices = [
        for (final e in catTotals.entries)
          if (e.value > 0)
            CategorySlice(
              id: e.key,
              name: catNameById[e.key] ?? 'Unknown',
              value: e.value,
              color: catColorById[e.key] ?? colorFromIconOrSeed(categoryId: e.key),
            ),
      ]..sort((a, b) => b.value.compareTo(a.value));

      // 12) Savings — ONLY modifies _savingsSeries (+ _savingsLabels if present)
      _savingsSeries = [];
      List<String> _tmpSavingsLabels = [];

      if (_periodIndex == 0) {
        // ===== WEEKLY (current month) =====
        final now = DateTime.now();
        final weeklyVals = List<num>.filled(4, 0);

        // A) Fixed Income → monthly/4 to each week if this month's payday is active
        for (final r in fixedIncomeRows) {
          final monthly = (r['monthly_income'] as num?) ?? 0;
          final st = _parseOrNull(r['start_time']);
          final en = _parseOrNull(r['end_time']);
          final payday = (r['payday'] as int?) ?? 1;

          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          final payDate = DateTime(now.year, now.month, payday.clamp(1, lastDay));
          final active = (st == null || !payDate.isBefore(st)) && (en == null || !payDate.isAfter(en));
          if (!active) continue;

          final perWeek = monthly / 4;
          for (int i = 0; i < 4; i++) weeklyVals[i] += perWeek;
        }

        // B) Variable transactions → bucket by actual day
        for (final r in trxRows) {
          final d = DateTime.parse(r['date'] as String);
          if (d.year != now.year || d.month != now.month) continue;
          final idx = (d.day <= 7) ? 0 : (d.day <= 14) ? 1 : (d.day <= 22) ? 2 : 3;
          final amt = (r['amount'] as num?) ?? 0;
          final type = (r['type'] as String?) ?? '';
          if (type == 'Earning') {
            weeklyVals[idx] += amt;
          } else if (type == 'Expense') {
            weeklyVals[idx] -= amt;
          }
        }

        // C) Fixed expenses → charge in the week that contains the due day
        for (final r in fixedExpenseRows) {
          final monthly = (r['amount'] as num?) ?? 0;
          final dueDay  = (r['due_date'] as int?) ?? 1;
          final st = _parseOrNull(r['start_time']);
          final en = _parseOrNull(r['end_time']);

          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          final dd = dueDay.clamp(1, lastDay);
          final dueDate = DateTime(now.year, now.month, dd);
          final active = (st == null || !dueDate.isBefore(st)) && (en == null || !dueDate.isAfter(en));
          if (!active) continue;

          final idx = (dd <= 7) ? 0 : (dd <= 14) ? 1 : (dd <= 22) ? 2 : 3;
          weeklyVals[idx] -= monthly;
        }

        // D) Carry any negative forward: clamp week to 0, subtract deficit from next week
        for (int i = 0; i < 4; i++) {
          if (weeklyVals[i] < 0) {
            final deficit = -weeklyVals[i];
            weeklyVals[i] = 0;
            if (i + 1 < 4) weeklyVals[i + 1] -= deficit;
          }
        }

        // E) Only show available (non-zero) weeks, with labels
        const wLabels = ['W1','W2','W3','W4'];
        for (int i = 0; i < 4; i++) {
          if (weeklyVals[i] != 0) {
            _savingsSeries.add(weeklyVals[i]);
            _tmpSavingsLabels.add(wLabels[i]);
          }
        }

      } else if (_periodIndex == 1) {
        // ===== MONTHLY (current year) =====
        final byMonth = List<num>.filled(12, 0);
        for (final r in mfrRows) {
          final d = DateTime.parse(r['period_start'] as String);
          final s = (r['monthly_saving'] as num?) ?? 0;
          if (d.isBefore(rangeStart) || d.isAfter(rangeEnd)) continue;
          byMonth[d.month - 1] += s;
        }
        const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        for (var i = 0; i < 12; i++) {
          if (byMonth[i] != 0) {
            _savingsSeries.add(byMonth[i]);
            _tmpSavingsLabels.add(monthNames[i]);
          }
        }

      } else {
        // ===== YEARLY (ALL years) =====
        final allMfr = await _sb
            .from('Monthly_Financial_Record')
            .select('period_start, monthly_saving')
            .eq('profile_id', profileId);

        final byYear = <int, num>{};
        for (final r in allMfr) {
          final d = DateTime.parse(r['period_start'] as String);
          final s = (r['monthly_saving'] as num?) ?? 0;
          byYear[d.year] = (byYear[d.year] ?? 0) + s;
        }

        final years = byYear.keys.toList()..sort();
        for (final y in years) {
          final total = byYear[y] ?? 0;
          if (total != 0) {
            _savingsSeries.add(total);
            _tmpSavingsLabels.add('$y');
          }
        }
      }

      // If your state has _savingsLabels, keep them in sync. If not, this is harmless.
      try { _savingsLabels = _tmpSavingsLabels; } catch (_) {}


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
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 4)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 11)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 18)),
        _Bucket(null, null, DateTime(mStart.year, mStart.month, 26)),
      ];

  List<_Bucket> _buildMonthlyBuckets(int year) =>
      [for (var m=1; m<=12; m++) _Bucket(year, m, DateTime(year, m, 15))];

  List<_Bucket> _buildYearlyBuckets(int y1, int y2) =>
      [for (var y=y1; y<=y2; y++) _Bucket(y, null, DateTime(y, 6, 15))];

  // remove buckets whose three series are all zero
  _Filtered _filterEmpty(List<String> labels, List<num> a, List<num> b, List<num> c) {
    final keep = <int>[];
    for (var i = 0; i < labels.length; i++) {
      final sum = (a[i] as num).toDouble() + (b[i] as num).toDouble() + (c[i] as num).toDouble();
      if (sum != 0) keep.add(i);
    }
    return _Filtered(
      labels: [for (final i in keep) labels[i]],
      expenses: [for (final i in keep) a[i]],
      earnings: [for (final i in keep) b[i]],
      income:   [for (final i in keep) c[i]],
    );
  }

  // NEW: index of the current calendar bucket in RAW arrays
  int _currentRawBucketIndex() {
    if (_allBuckets.isEmpty) return -1;
    final now = DateTime.now();
    if (_periodIndex == 0) {
      // weeks are fixed W1..W4 for current month buckets
      return (now.day <= 7) ? 0 : (now.day <= 14) ? 1 : (now.day <= 21) ? 2 : 3;
    } else if (_periodIndex == 1) {
      return now.month - 1;
    } else {
      // find the year position (range is [now.year-4 .. now.year])
      for (int i = 0; i < _allBuckets.length; i++) {
        if (_allBuckets[i].year == now.year) return i;
      }
      return -1;
    }
  }

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
    // ===== Income Overview should reflect the CURRENT calendar bucket
    final idx = _currentRawBucketIndex();
    num totalExpenses = 0, totalEarnings = 0, totalIncome = 0;
    if (idx >= 0 && idx < _rawExpenses.length) {
      totalExpenses = _rawExpenses[idx];
      totalEarnings = _rawEarnings[idx];
      totalIncome   = _rawIncome[idx];
    }

    // Base for gauge = earnings + income
    final denom = (totalIncome + totalEarnings);
    final left  = math.max(0, denom - totalExpenses);
    final percentLeft = denom <= 0 ? 0.0 : (left / denom).clamp(0, 1).toDouble();

    // Legends for Income Overview — show exactly the current bucket values
    final incomeLegends = [
      _LegendItem('Expenses', '${totalExpenses.toStringAsFixed(0)} SAR', _violet),
      _LegendItem('Earnings', '${totalEarnings.toStringAsFixed(0)} SAR', _cyan),
      _LegendItem('Income',   '${totalIncome.toStringAsFixed(0)} SAR', _muted),
    ];

    // Legends for the bar chart — keep existing filtered series, but legends below chart
    // can still display current bucket values to stay consistent with the top panel.
    // Legends for the bar chart: sum across the visible bars (all shown buckets)
    final trendsTotalExpenses = _seriesExpenses.fold<num>(0, (a, b) => a + b);
    final trendsTotalEarnings = _seriesEarnings.fold<num>(0, (a, b) => a + b);
    final trendsTotalIncome   = _seriesIncome.fold<num>(0, (a, b) => a + b);

    final monthlyLegends = [
      _LegendItem('Expenses', '${trendsTotalExpenses.toStringAsFixed(0)} SAR', _violet),
      _LegendItem('Earnings', '${trendsTotalEarnings.toStringAsFixed(0)} SAR', _cyan),
      _LegendItem('Income',   '${trendsTotalIncome.toStringAsFixed(0)} SAR', _muted),
    ];


    final catItems = [
      for (final s in _categorySlices.take(_showAllCategories ? _categorySlices.length : 5))
        _LegendItem(s.name, '${s.value.toStringAsFixed(0)} SAR', s.color),
    ];

    // Force gauge rebuild when period changes or the selected bucket changes
    final gaugeKey = ValueKey<String>(
      'gauge_${_periodIndex}_${idx}_${totalExpenses}_${totalEarnings}_${totalIncome}',
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, kBottomNavigationBarHeight + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and balance
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

          // Period control
          _HeaderPanel(
            periodIndex: _periodIndex,
            onPeriodChanged: (i) => setState(() { _periodIndex = i; _loadAll(); }),
          ),
          const SizedBox(height: 18),

          // Income Overview
          const _BlockTitle('Income Overview'),
          const SizedBox(height: _betweenTitleAndCard),
          _SectionCard(
            onInfo: () => _showInfo(context, 'Shows this ${_periodIndex==0?'week':_periodIndex==1?'month':'year'}: spending vs what you have (earnings + income).'),
            child: Column(
              children: [
                const SizedBox(height: 8),
                IncomeSemicircleGauge(
                  key: gaugeKey,
                  percent: percentLeft,
                  label: '${(percentLeft*100).round()}% of\nincome left',
                  expenses: totalExpenses.toDouble(),
                  earnings: totalEarnings.toDouble(),
                  income:   totalIncome.toDouble(),
                ),
                const SizedBox(height: 12),
                _LegendRow(items: incomeLegends),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Trends
          const _BlockTitle('Financial Trends'),
          const SizedBox(height: _betweenTitleAndCard),
          _SectionCard(
            onInfo: () => _showInfo(context, 'Bars compare expenses against earnings and income. Only available periods are shown.'),
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
            onInfo: () => _showInfo(context, 'Y axis is monthly savings. X axis reflects the selected period. Points are drawn clearly.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 10),
              child: SavingsSparkline(
                values: _savingsSeries.map((e) => e.toDouble()).toList(),
                labels: _savingsLabels,      // same length as values, from DB rows you kept
                yAxisTitle: 'Monthly savings',
                showPoints: true,
              ),
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
                    items: [
                      for (final s in _categorySlices.take(_showAllCategories ? _categorySlices.length : 5))
                        _LegendItem(s.name, '${s.value.toStringAsFixed(0)} SAR', s.color),
                    ],
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

  int _monthsActiveInYear(DateTime? st, DateTime? en, int year) {
    // Clamp the active interval to the given year's bounds, then count months inclusive.
    final yearStart = DateTime(year, 1, 1);
    final yearEnd   = DateTime(year, 12, 31);

    // Normalize to month starts
    DateTime start = st == null ? yearStart : DateTime(st.year, st.month, 1);
    DateTime end   = en == null ? yearEnd   : DateTime(en.year, en.month, 1);

    if (start.isBefore(yearStart)) start = yearStart;
    if (end.isAfter(yearEnd)) end = DateTime(year, 12, 1);

    if (end.isBefore(start)) return 0;

    final startKey = start.year * 12 + start.month;
    final endKey   = end.year * 12 + end.month;
    return endKey - startKey + 1; // inclusive month count
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

/* container for filtered series */
class _Filtered {
  final List<String> labels;
  final List<num> expenses;
  final List<num> earnings;
  final List<num> income;
  _Filtered({required this.labels, required this.expenses, required this.earnings, required this.income});
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
