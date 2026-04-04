import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

// Reuse child chart widgets
import '../Child_Screens/Child_Dashboard/money_left_chart.dart';
import '../Child_Screens/Child_Dashboard/trends_chart.dart';
import '../Child_Screens/Child_Dashboard/savings_chart.dart';
import '../Child_Screens/Child_Dashboard/category_chart.dart';

class GuardianChildStatisticsPage
    extends
        StatefulWidget {
  final String childProfileId;

  const GuardianChildStatisticsPage({
    super.key,
    required this.childProfileId,
  });

  @override
  State<
    GuardianChildStatisticsPage
  >
  createState() => _GuardianChildStatisticsPageState();
}

class _GuardianChildStatisticsPageState
    extends
        State<
          GuardianChildStatisticsPage
        > {
  final SupabaseClient _sb = Supabase.instance.client;

  int _periodIndex = 1; // 0 weekly, 1 monthly, 2 yearly
  bool _loading = true;
  bool _deletingChild = false;
  String? _error;

  String _childName = 'Child Name';
  String? _childIcon;
  num _balance = 0;

  List<
    String
  >
  _bucketLabels = [];
  List<
    num
  >
  _seriesExpenses = [];
  List<
    num
  >
  _seriesEarnings = [];
  List<
    num
  >
  _seriesIncome = [];

  List<
    CategorySlice
  >
  _categorySlices = [];
  List<
    num
  >
  _savingsSeries = [];
  List<
    String
  >
  _savingsLabels = [];

  List<
    num
  >
  _rawExpenses = [];
  List<
    num
  >
  _rawEarnings = [];
  List<
    num
  >
  _rawIncome = [];
  List<
    String
  >
  _rawLabels = [];

  List<
    _Bucket
  >
  _allBuckets = [];

  List<
    List<
      CategorySlice
    >
  >
  _weeklySlices = [
    [],
    [],
    [],
    [],
  ];
  List<
    num
  >
  _weeklyTotals = [
    0,
    0,
    0,
    0,
  ];
  List<
    bool
  >
  _weekIsFuture = [
    false,
    false,
    false,
    false,
  ];
  List<
    _LegendItem
  >
  _weeklyLegend = [];

  bool _donutExpanded = false;
  bool _showAllCategories = false;
  bool _showAllWeekly = false;

  static const _violet = AppColors.accent;
  static const _cyan = AppColors.pCyan;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String
  _iso(
    DateTime d,
  ) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime?
  _parseOrNull(
    dynamic s,
  ) =>
      (s ==
          null)
      ? null
      : DateTime.tryParse(
          s
              as String,
        );

  Future<
    void
  >
  _loadChildInfo() async {
    final row = await _sb
        .from(
          'User_Profile',
        )
        .select(
          'full_name, current_balance',
        )
        .eq(
          'profile_id',
          widget.childProfileId,
        )
        .maybeSingle();

    final childRelation = await _sb
        .from(
          'Child_Guardian',
        )
        .select(
          'icon',
        )
        .eq(
          'child_id',
          widget.childProfileId,
        )
        .maybeSingle();

    if (row !=
        null) {
      _childName =
          (row['full_name'] ??
                  'Child Name')
              .toString();
      _balance =
          (row['current_balance']
              as num?) ??
          0;
    }

    final icon =
        (childRelation?['icon']
                as String?)
            ?.trim();
    _childIcon =
        (icon !=
                null &&
            icon.isNotEmpty)
        ? icon
        : null;
  }

  Future<
    void
  >
  _confirmDeleteChild() async {
    final shouldDelete =
        await showDialog<
          bool
        >(
          context: context,
          builder:
              (
                context,
              ) {
                return AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text(
                    'Delete child account?',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to delete $_childName\'s account? This action cannot be undone.',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        false,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        true,
                      ),
                      child: const Text(
                        'OK',
                      ),
                    ),
                  ],
                );
              },
        );

    if (shouldDelete ==
        true) {
      await _deleteChildAccount();
    }
  }

  Future<
    void
  >
  _deleteChildAccount() async {
    if (_deletingChild) return;

    setState(
      () {
        _deletingChild = true;
      },
    );

    try {
      final profileId = widget.childProfileId;

      // Get dependent IDs first
      final monthlyRows = await _sb
          .from(
            'Monthly_Financial_Record',
          )
          .select(
            'record_id',
          )
          .eq(
            'profile_id',
            profileId,
          );

      final categoryRows = await _sb
          .from(
            'Category',
          )
          .select(
            'category_id',
          )
          .eq(
            'profile_id',
            profileId,
          );

      final recordIds =
          <
            String
          >[
            for (final r
                in monthlyRows)
              if (r['record_id'] !=
                  null)
                r['record_id']
                    as String,
          ];

      final categoryIds =
          <
            String
          >[
            for (final r
                in categoryRows)
              if (r['category_id'] !=
                  null)
                r['category_id']
                    as String,
          ];

      // Delete rows that depend on monthly records/categories first
      if (recordIds.isNotEmpty) {
        await _sb
            .from(
              'Category_Summary',
            )
            .delete()
            .inFilter(
              'record_id',
              recordIds,
            );
      }

      // Delete child-owned rows
      await _sb
          .from(
            'Transaction',
          )
          .delete()
          .eq(
            'profile_id',
            profileId,
          );
      await _sb
          .from(
            'Fixed_Income',
          )
          .delete()
          .eq(
            'profile_id',
            profileId,
          );
      await _sb
          .from(
            'Fixed_Expense',
          )
          .delete()
          .eq(
            'profile_id',
            profileId,
          );

      // If you have more child-owned tables, delete them here too
      // await _sb.from('Goal_Transfer').delete().eq('profile_id', profileId);
      // await _sb.from('Goal').delete().eq('profile_id', profileId);
      // await _sb.from('Notification').delete().eq('profile_id', profileId);

      // Delete categories and monthly records
      if (categoryIds.isNotEmpty) {
        await _sb
            .from(
              'Category',
            )
            .delete()
            .inFilter(
              'category_id',
              categoryIds,
            );
      }

      if (recordIds.isNotEmpty) {
        await _sb
            .from(
              'Monthly_Financial_Record',
            )
            .delete()
            .inFilter(
              'record_id',
              recordIds,
            );
      }

      // Delete guardian relation
      await _sb
          .from(
            'Child_Guardian',
          )
          .delete()
          .eq(
            'child_id',
            profileId,
          );

      // Delete child profile LAST
      await _sb
          .from(
            'User_Profile',
          )
          .delete()
          .eq(
            'profile_id',
            profileId,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Child account deleted successfully.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (
      e
    ) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete child account: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(
          () {
            _deletingChild = false;
          },
        );
      }
    }
  }

  Color _hexToColor(
    String value,
  ) {
    value = value.replaceAll(
      '#',
      '',
    );

    final isDecimal =
        RegExp(
          r'^[0-9]+$',
        ).hasMatch(
          value,
        ) &&
        value.length >
            8;

    if (isDecimal) {
      return Color(
        int.parse(
          value,
        ),
      );
    }

    if (value.length ==
        6) {
      value = 'FF$value';
    }

    return Color(
      int.parse(
        value,
        radix: 16,
      ),
    );
  }

  List<
    _Bucket
  >
  _buildWeeklyBuckets(
    DateTime mStart,
    DateTime mEnd,
  ) => [
    _Bucket(
      null,
      null,
      DateTime(
        mStart.year,
        mStart.month,
        4,
      ),
    ),
    _Bucket(
      null,
      null,
      DateTime(
        mStart.year,
        mStart.month,
        11,
      ),
    ),
    _Bucket(
      null,
      null,
      DateTime(
        mStart.year,
        mStart.month,
        18,
      ),
    ),
    _Bucket(
      null,
      null,
      DateTime(
        mStart.year,
        mStart.month,
        26,
      ),
    ),
  ];

  List<
    _Bucket
  >
  _buildMonthlyBuckets(
    int year,
  ) => [
    for (
      var m = 1;
      m <=
          12;
      m++
    )
      _Bucket(
        year,
        m,
        DateTime(
          year,
          m,
          15,
        ),
      ),
  ];

  List<
    _Bucket
  >
  _buildYearlyBuckets(
    int y1,
    int y2,
  ) => [
    for (
      var y = y1;
      y <=
          y2;
      y++
    )
      _Bucket(
        y,
        null,
        DateTime(
          y,
          6,
          15,
        ),
      ),
  ];

  _Filtered _filterEmpty(
    List<
      String
    >
    labels,
    List<
      num
    >
    a,
    List<
      num
    >
    b,
    List<
      num
    >
    c,
  ) {
    final keep =
        <
          int
        >[];
    for (
      var i = 0;
      i <
          labels.length;
      i++
    ) {
      final sum =
          a[i].toDouble() +
          b[i].toDouble() +
          c[i].toDouble();
      if (sum !=
          0)
        keep.add(
          i,
        );
    }

    return _Filtered(
      labels: [
        for (final i in keep) labels[i],
      ],
      expenses: [
        for (final i in keep) a[i],
      ],
      earnings: [
        for (final i in keep) b[i],
      ],
      income: [
        for (final i in keep) c[i],
      ],
    );
  }

  int _currentRawBucketIndex() {
    if (_allBuckets.isEmpty) return -1;
    final now = DateTime.now();

    if (_periodIndex ==
        0) {
      return (now.day <=
              7)
          ? 0
          : (now.day <=
                14)
          ? 1
          : (now.day <=
                21)
          ? 2
          : 3;
    } else if (_periodIndex ==
        1) {
      return now.month -
          1;
    } else {
      for (
        int i = 0;
        i <
            _allBuckets.length;
        i++
      ) {
        if (_allBuckets[i].year ==
            now.year)
          return i;
      }
      return -1;
    }
  }

  Future<
    void
  >
  _loadAll() async {
    setState(
      () {
        _loading = true;
        _error = null;
      },
    );

    try {
      await _loadChildInfo();

      final profileId = widget.childProfileId;
      final now = DateTime.now();

      late DateTime rangeStart, rangeEnd;
      if (_periodIndex ==
          0) {
        rangeStart = DateTime(
          now.year,
          now.month,
          1,
        );
        rangeEnd = DateTime(
          now.year,
          now.month +
              1,
          0,
        );
      } else if (_periodIndex ==
          1) {
        rangeStart = DateTime(
          now.year,
          1,
          1,
        );
        rangeEnd = DateTime(
          now.year,
          12,
          31,
        );
      } else {
        rangeStart = DateTime(
          now.year -
              4,
          1,
          1,
        );
        rangeEnd = DateTime(
          now.year,
          12,
          31,
        );
      }

      final trxRows = await _sb
          .from(
            'Transaction',
          )
          .select(
            'type, amount, date, category_id',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .gte(
            'date',
            _iso(
              rangeStart,
            ),
          )
          .lte(
            'date',
            _iso(
              rangeEnd,
            ),
          );

      final fixedIncomeRows = await _sb
          .from(
            'Fixed_Income',
          )
          .select(
            'monthly_income, start_time, end_time, payday',
          )
          .eq(
            'profile_id',
            profileId,
          );

      final fixedExpenseRows = await _sb
          .from(
            'Fixed_Expense',
          )
          .select(
            'amount, category_id, due_date, start_time, end_time',
          )
          .eq(
            'profile_id',
            profileId,
          );

      final catRows = await _sb
          .from(
            'Category',
          )
          .select(
            'category_id, name, icon_color',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .eq(
            'is_archived',
            false,
          );

      final mfrRows = await _sb
          .from(
            'Monthly_Financial_Record',
          )
          .select(
            'period_start, monthly_saving, total_income, total_expense, total_earning, profile_id, record_id',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .gte(
            'period_start',
            _iso(
              DateTime(
                now.year,
                1,
                1,
              ),
            ),
          )
          .lte(
            'period_start',
            _iso(
              DateTime(
                now.year,
                12,
                31,
              ),
            ),
          );

      final activeCategoryIds =
          <
            String
          >{
            for (final r in catRows)
              r['category_id']
                  as String,
          };

      final buckets =
          (_periodIndex ==
              0)
          ? _buildWeeklyBuckets(
              DateTime(
                now.year,
                now.month,
                1,
              ),
              DateTime(
                now.year,
                now.month +
                    1,
                0,
              ),
            )
          : (_periodIndex ==
                1)
          ? _buildMonthlyBuckets(
              rangeStart.year,
            )
          : _buildYearlyBuckets(
              rangeStart.year,
              rangeEnd.year,
            );

      _allBuckets = buckets;

      final catNameById =
          <
            String,
            String
          >{
            for (final r
                in catRows)
              r['category_id']
                      as String:
                  (r['name']
                      as String),
          };

      final catColorById =
          <
            String,
            Color
          >{
            for (final r
                in catRows)
              r['category_id']
                  as String: _hexToColor(
                (r['icon_color'] ??
                        '')
                    .toString(),
              ),
          };

      int bucketIndex(
        DateTime d,
      ) {
        if (_periodIndex ==
            0) {
          final dom = d.day;
          if (dom <=
              7)
            return 0;
          if (dom <=
              14)
            return 1;
          if (dom <=
              22)
            return 2;
          return 3;
        } else if (_periodIndex ==
            1) {
          return d.month -
              1;
        } else {
          return d.year -
              (buckets.first.year ??
                  d.year);
        }
      }

      final n = buckets.length;
      _rawExpenses = List.filled(
        n,
        0,
      );
      _rawEarnings = List.filled(
        n,
        0,
      );
      _rawIncome = List.filled(
        n,
        0,
      );
      _seriesExpenses = List.filled(
        n,
        0,
      );
      _seriesEarnings = List.filled(
        n,
        0,
      );
      _seriesIncome = List.filled(
        n,
        0,
      );

      for (final r in trxRows) {
        final type =
            (r['type']
                as String?) ??
            '';
        final amt =
            (r['amount']
                as num?) ??
            0;
        final date = DateTime.parse(
          r['date']
              as String,
        );

        if (date.isBefore(
              rangeStart,
            ) ||
            date.isAfter(
              rangeEnd,
            ))
          continue;

        final i = bucketIndex(
          date,
        );
        if (i <
                0 ||
            i >=
                n)
          continue;

        if (type ==
            'Expense') {
          _rawExpenses[i] += amt;
          _seriesExpenses[i] += amt;
        } else if (type ==
            'Earning') {
          _rawEarnings[i] += amt;
          _seriesEarnings[i] += amt;
        }
      }

      num totalIncomeFromMonth(
        DateTime d,
      ) {
        num sum = 0;
        for (final r in mfrRows) {
          final pd = DateTime.parse(
            r['period_start']
                as String,
          );
          if (pd.year ==
                  d.year &&
              pd.month ==
                  d.month) {
            sum +=
                (r['total_income']
                    as num?) ??
                0;
          }
        }
        return sum;
      }

      if (_periodIndex ==
          1) {
        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          final y = buckets[i].year!;
          final m = buckets[i].month!;
          final ti = totalIncomeFromMonth(
            DateTime(
              y,
              m,
              1,
            ),
          );
          _rawIncome[i] = ti;
          _seriesIncome[i] = ti;
        }
      } else if (_periodIndex ==
          2) {
        final byYear =
            <
              int,
              num
            >{};
        for (final r in mfrRows) {
          final d = DateTime.parse(
            r['period_start']
                as String,
          );
          byYear[d.year] =
              (byYear[d.year] ??
                  0) +
              ((r['total_income']
                      as num?) ??
                  0);
        }

        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          final y = buckets[i].year!;
          final ti =
              byYear[y] ??
              0;
          _rawIncome[i] = ti;
          _seriesIncome[i] = ti;
        }
      } else {
        final monthTotal = totalIncomeFromMonth(
          DateTime(
            now.year,
            now.month,
            1,
          ),
        );
        final perWeek =
            monthTotal /
            4;
        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          _rawIncome[i] = perWeek;
          _seriesIncome[i] = perWeek;
        }
      }

      if (_periodIndex ==
          1) {
        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          _rawExpenses[i] = 0;
          _rawEarnings[i] = 0;
          _seriesExpenses[i] = 0;
          _seriesEarnings[i] = 0;
        }

        final byMonthExp =
            List<
              num
            >.filled(
              12,
              0,
            );
        final byMonthEarn =
            List<
              num
            >.filled(
              12,
              0,
            );

        for (final r in mfrRows) {
          final d = DateTime.parse(
            r['period_start']
                as String,
          );
          final mIdx =
              d.month -
              1;
          byMonthExp[mIdx] +=
              (r['total_expense']
                  as num?) ??
              0;
          byMonthEarn[mIdx] +=
              (r['total_earning']
                  as num?) ??
              0;
        }

        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          final mIdx =
              buckets[i].month! -
              1;
          final e = byMonthExp[mIdx];
          final er = byMonthEarn[mIdx];
          _rawExpenses[i] = e;
          _seriesExpenses[i] = e;
          _rawEarnings[i] = er;
          _seriesEarnings[i] = er;
        }
      } else if (_periodIndex ==
          2) {
        final mfrAllYears = await _sb
            .from(
              'Monthly_Financial_Record',
            )
            .select(
              'period_start, total_expense, total_earning',
            )
            .eq(
              'profile_id',
              profileId,
            )
            .gte(
              'period_start',
              _iso(
                rangeStart,
              ),
            )
            .lte(
              'period_start',
              _iso(
                rangeEnd,
              ),
            );

        final expByYear =
            <
              int,
              num
            >{};
        final earnByYear =
            <
              int,
              num
            >{};

        for (final r in mfrAllYears) {
          final d = DateTime.parse(
            r['period_start']
                as String,
          );
          expByYear[d.year] =
              (expByYear[d.year] ??
                  0) +
              ((r['total_expense']
                      as num?) ??
                  0);
          earnByYear[d.year] =
              (earnByYear[d.year] ??
                  0) +
              ((r['total_earning']
                      as num?) ??
                  0);
        }

        for (
          var i = 0;
          i <
              n;
          i++
        ) {
          final y = buckets[i].year!;
          final e =
              expByYear[y] ??
              0;
          final er =
              earnByYear[y] ??
              0;
          _rawExpenses[i] = e;
          _seriesExpenses[i] = e;
          _rawEarnings[i] = er;
          _seriesEarnings[i] = er;
        }
      }

      if (_periodIndex ==
          2) {
        _rawLabels = [
          for (final b in buckets) '${b.year}',
        ];
      } else if (_periodIndex ==
          0) {
        _rawLabels = const [
          'W1',
          'W2',
          'W3',
          'W4',
        ];
      } else {
        _rawLabels = const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
      }

      if (_periodIndex ==
          1) {
        final currentMonthIdx =
            DateTime.now().month -
            1;
        for (
          int i =
              currentMonthIdx +
              1;
          i <
              _seriesExpenses.length;
          i++
        ) {
          _seriesExpenses[i] = 0;
          _seriesEarnings[i] = 0;
          _seriesIncome[i] = 0;
        }
      }

      final filtered = _filterEmpty(
        _rawLabels,
        _seriesExpenses,
        _seriesEarnings,
        _seriesIncome,
      );

      _bucketLabels = filtered.labels;
      _seriesExpenses = filtered.expenses;
      _seriesEarnings = filtered.earnings;
      _seriesIncome = filtered.income;

      final catTotals =
          <
            String,
            num
          >{};

      Future<
        void
      >
      loadCategorySlicesMonthly() async {
        final nowM = DateTime.now();
        final y = nowM.year, m = nowM.month;
        final mStart = DateTime(
          y,
          m,
          1,
        );
        final mEnd = DateTime(
          y,
          m +
              1,
          0,
        );

        final mfrForMonth = await _sb
            .from(
              'Monthly_Financial_Record',
            )
            .select(
              'record_id, period_start, period_end',
            )
            .eq(
              'profile_id',
              profileId,
            )
            .gte(
              'period_start',
              _iso(
                mStart,
              ),
            )
            .lte(
              'period_start',
              _iso(
                mEnd,
              ),
            );

        final recordIds =
            <
              String
            >[
              for (final r
                  in mfrForMonth)
                if (r['record_id'] !=
                    null)
                  r['record_id']
                      as String,
            ];
        if (recordIds.isEmpty) return;

        final catSumRows = await _sb
            .from(
              'Category_Summary',
            )
            .select(
              'category_id, total_expense, record_id',
            )
            .inFilter(
              'record_id',
              recordIds,
            );

        for (final r in catSumRows) {
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;
          final amt =
              (r['total_expense']
                  as num?) ??
              0;
          if (amt <=
              0)
            continue;
          catTotals[cid] =
              (catTotals[cid] ??
                  0) +
              amt;
        }
      }

      Future<
        void
      >
      loadCategorySlicesYearly() async {
        final nowY = DateTime.now();
        final y = nowY.year;
        final yStart = DateTime(
          y,
          1,
          1,
        );
        final yEnd = DateTime(
          y,
          12,
          31,
        );

        final mfrForYear = await _sb
            .from(
              'Monthly_Financial_Record',
            )
            .select(
              'record_id, period_start, period_end',
            )
            .eq(
              'profile_id',
              profileId,
            )
            .gte(
              'period_start',
              _iso(
                yStart,
              ),
            )
            .lte(
              'period_start',
              _iso(
                yEnd,
              ),
            );

        final recordIds =
            <
              String
            >[
              for (final r
                  in mfrForYear)
                if (r['record_id'] !=
                    null)
                  r['record_id']
                      as String,
            ];
        if (recordIds.isEmpty) return;

        final catSumRows = await _sb
            .from(
              'Category_Summary',
            )
            .select(
              'category_id, total_expense, record_id',
            )
            .inFilter(
              'record_id',
              recordIds,
            );

        for (final r in catSumRows) {
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;
          final amt =
              (r['total_expense']
                  as num?) ??
              0;
          if (amt <=
              0)
            continue;
          catTotals[cid] =
              (catTotals[cid] ??
                  0) +
              amt;
        }
      }

      void loadCategorySlicesWeekly() {
        final nowW = DateTime.now();
        final y = nowW.year, m = nowW.month;
        final lastDay = DateTime(
          y,
          m +
              1,
          0,
        ).day;

        late int wStartDay, wEndDay;
        final d = nowW.day;
        if (d <=
            7) {
          wStartDay = 1;
          wEndDay = 7;
        } else if (d <=
            14) {
          wStartDay = 8;
          wEndDay = 14;
        } else if (d <=
            22) {
          wStartDay = 15;
          wEndDay = 22;
        } else {
          wStartDay = 23;
          wEndDay = lastDay;
        }

        final weekStart = DateTime(
          y,
          m,
          wStartDay,
        );
        final weekEnd = DateTime(
          y,
          m,
          wEndDay,
        );

        for (final r in trxRows) {
          if ((r['type']
                  as String?) !=
              'Expense')
            continue;
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;
          final amt =
              (r['amount']
                  as num?) ??
              0;
          if (amt <=
              0)
            continue;
          final dt = DateTime.parse(
            r['date']
                as String,
          );
          if (dt.isBefore(
                weekStart,
              ) ||
              dt.isAfter(
                weekEnd,
              ))
            continue;
          catTotals[cid] =
              (catTotals[cid] ??
                  0) +
              amt;
        }

        for (final r in fixedExpenseRows) {
          final monthly =
              (r['amount']
                  as num?) ??
              0;
          if (monthly <=
              0)
            continue;
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;

          final dueDay =
              (r['due_date']
                  as int?) ??
              1;
          final dd = dueDay.clamp(
            1,
            lastDay,
          );
          final dueDate = DateTime(
            y,
            m,
            dd,
          );

          final st = _parseOrNull(
            r['start_time'],
          );
          final en = _parseOrNull(
            r['end_time'],
          );
          final active =
              (st ==
                      null ||
                  !dueDate.isBefore(
                    st,
                  )) &&
              (en ==
                      null ||
                  !dueDate.isAfter(
                    en,
                  ));
          if (!active) continue;

          if (!dueDate.isBefore(
                weekStart,
              ) &&
              !dueDate.isAfter(
                weekEnd,
              )) {
            catTotals[cid] =
                (catTotals[cid] ??
                    0) +
                monthly;
          }
        }
      }

      if (_periodIndex ==
          0) {
        loadCategorySlicesWeekly();
      } else if (_periodIndex ==
          1) {
        await loadCategorySlicesMonthly();
      } else {
        await loadCategorySlicesYearly();
      }

      _categorySlices =
          [
            for (final e in catTotals.entries)
              if (e.value >
                      0 &&
                  activeCategoryIds.contains(
                    e.key,
                  ))
                CategorySlice(
                  id: e.key,
                  name:
                      catNameById[e.key] ??
                      'Unknown',
                  value: e.value,
                  color:
                      catColorById[e.key] ??
                      colorFromIconOrSeed(
                        categoryId: e.key,
                      ),
                ),
          ]..sort(
            (
              a,
              b,
            ) => b.value.compareTo(
              a.value,
            ),
          );

      if (_periodIndex ==
          0) {
        final y = now.year, m = now.month;
        final lastDay = DateTime(
          y,
          m +
              1,
          0,
        ).day;
        final weekRanges =
            <
              List<
                DateTime
              >
            >[
              [
                DateTime(
                  y,
                  m,
                  1,
                ),
                DateTime(
                  y,
                  m,
                  7,
                ),
              ],
              [
                DateTime(
                  y,
                  m,
                  8,
                ),
                DateTime(
                  y,
                  m,
                  14,
                ),
              ],
              [
                DateTime(
                  y,
                  m,
                  15,
                ),
                DateTime(
                  y,
                  m,
                  22,
                ),
              ],
              [
                DateTime(
                  y,
                  m,
                  23,
                ),
                DateTime(
                  y,
                  m,
                  lastDay,
                ),
              ],
            ];

        _weeklySlices = [
          [],
          [],
          [],
          [],
        ];
        _weeklyTotals = [
          0,
          0,
          0,
          0,
        ];
        _weekIsFuture = [
          false,
          false,
          false,
          false,
        ];

        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );
        for (
          int i = 0;
          i <
              4;
          i++
        ) {
          final start = weekRanges[i][0];
          _weekIsFuture[i] = start.isAfter(
            today,
          );
        }

        final perWeekTotals =
            <
              int,
              Map<
                String,
                num
              >
            >{
              0: {},
              1: {},
              2: {},
              3: {},
            };

        for (final r in trxRows) {
          if ((r['type']
                  as String?) !=
              'Expense')
            continue;
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;
          final amt =
              (r['amount']
                  as num?) ??
              0;
          if (amt <=
              0)
            continue;
          final dt = DateTime.parse(
            r['date']
                as String,
          );
          if (dt.year !=
                  y ||
              dt.month !=
                  m)
            continue;
          final i =
              (dt.day <=
                  7)
              ? 0
              : (dt.day <=
                    14)
              ? 1
              : (dt.day <=
                    22)
              ? 2
              : 3;
          perWeekTotals[i]![cid] =
              (perWeekTotals[i]![cid] ??
                  0) +
              amt;
        }

        for (final r in fixedExpenseRows) {
          final monthly =
              (r['amount']
                  as num?) ??
              0;
          if (monthly <=
              0)
            continue;
          final cid =
              r['category_id']
                  as String?;
          if (cid ==
                  null ||
              !activeCategoryIds.contains(
                cid,
              ))
            continue;

          final dd =
              (r['due_date']
                          as int? ??
                      1)
                  .clamp(
                    1,
                    lastDay,
                  );
          final dueDate = DateTime(
            y,
            m,
            dd,
          );

          final st = _parseOrNull(
            r['start_time'],
          );
          final en = _parseOrNull(
            r['end_time'],
          );
          final active =
              (st ==
                      null ||
                  !dueDate.isBefore(
                    st,
                  )) &&
              (en ==
                      null ||
                  !dueDate.isAfter(
                    en,
                  ));
          if (!active) continue;

          final i =
              (dd <=
                  7)
              ? 0
              : (dd <=
                    14)
              ? 1
              : (dd <=
                    22)
              ? 2
              : 3;
          if (_weekIsFuture[i]) continue;

          perWeekTotals[i]![cid] =
              (perWeekTotals[i]![cid] ??
                  0) +
              monthly;
        }

        final combinedTotals =
            <
              String,
              num
            >{};
        for (
          int i = 0;
          i <
              4;
          i++
        ) {
          final totals = perWeekTotals[i]!;
          final slices =
              <
                CategorySlice
              >[];
          num weekSum = 0;

          if (!_weekIsFuture[i] &&
              totals.isNotEmpty) {
            for (final e in totals.entries) {
              weekSum += e.value;
              combinedTotals[e.key] =
                  (combinedTotals[e.key] ??
                      0) +
                  e.value;
              slices.add(
                CategorySlice(
                  id: e.key,
                  name:
                      catNameById[e.key] ??
                      'Unknown',
                  value: e.value,
                  color:
                      catColorById[e.key] ??
                      colorFromIconOrSeed(
                        categoryId: e.key,
                      ),
                ),
              );
            }
            slices.sort(
              (
                a,
                b,
              ) => b.value.compareTo(
                a.value,
              ),
            );
          }

          _weeklySlices[i] = slices;
          _weeklyTotals[i] = weekSum;
        }

        _weeklyLegend = [
          for (final e
              in (combinedTotals.entries.toList()..sort(
                (
                  a,
                  b,
                ) => (b.value).compareTo(
                  a.value,
                ),
              )))
            _LegendItem(
              catNameById[e.key] ??
                  'Unknown',
              '${e.value.toStringAsFixed(0)} SAR',
              catColorById[e.key] ??
                  colorFromIconOrSeed(
                    categoryId: e.key,
                  ),
            ),
        ];
      } else {
        _weeklySlices = [
          [],
          [],
          [],
          [],
        ];
        _weeklyTotals = [
          0,
          0,
          0,
          0,
        ];
        _weekIsFuture = [
          false,
          false,
          false,
          false,
        ];
        _weeklyLegend = [];
      }

      _savingsSeries = [];
      _savingsLabels = [];

      if (_periodIndex ==
          0) {
        final weeklyVals =
            List<
              num
            >.filled(
              4,
              0,
            );

        for (final r in fixedIncomeRows) {
          final monthly =
              (r['monthly_income']
                  as num?) ??
              0;
          final st = _parseOrNull(
            r['start_time'],
          );
          final en = _parseOrNull(
            r['end_time'],
          );
          final payday =
              (r['payday']
                  as int?) ??
              1;

          final lastDay = DateTime(
            now.year,
            now.month +
                1,
            0,
          ).day;
          final payDate = DateTime(
            now.year,
            now.month,
            payday.clamp(
              1,
              lastDay,
            ),
          );
          final active =
              (st ==
                      null ||
                  !payDate.isBefore(
                    st,
                  )) &&
              (en ==
                      null ||
                  !payDate.isAfter(
                    en,
                  ));
          if (!active) continue;

          final perWeek =
              monthly /
              4;
          for (
            int i = 0;
            i <
                4;
            i++
          ) {
            weeklyVals[i] += perWeek;
          }
        }

        for (final r in trxRows) {
          final d = DateTime.parse(
            r['date']
                as String,
          );
          if (d.year !=
                  now.year ||
              d.month !=
                  now.month)
            continue;

          final idx =
              (d.day <=
                  7)
              ? 0
              : (d.day <=
                    14)
              ? 1
              : (d.day <=
                    22)
              ? 2
              : 3;

          final amt =
              (r['amount']
                  as num?) ??
              0;
          final type =
              (r['type']
                  as String?) ??
              '';

          if (type ==
              'Earning') {
            weeklyVals[idx] += amt;
          } else if (type ==
              'Expense') {
            weeklyVals[idx] -= amt;
          }
        }

        for (final r in fixedExpenseRows) {
          final monthly =
              (r['amount']
                  as num?) ??
              0;
          final dueDay =
              (r['due_date']
                  as int?) ??
              1;
          final st = _parseOrNull(
            r['start_time'],
          );
          final en = _parseOrNull(
            r['end_time'],
          );

          final lastDay = DateTime(
            now.year,
            now.month +
                1,
            0,
          ).day;
          final dd = dueDay.clamp(
            1,
            lastDay,
          );
          final dueDate = DateTime(
            now.year,
            now.month,
            dd,
          );
          final active =
              (st ==
                      null ||
                  !dueDate.isBefore(
                    st,
                  )) &&
              (en ==
                      null ||
                  !dueDate.isAfter(
                    en,
                  ));
          if (!active) continue;

          final idx =
              (dd <=
                  7)
              ? 0
              : (dd <=
                    14)
              ? 1
              : (dd <=
                    22)
              ? 2
              : 3;
          weeklyVals[idx] -= monthly;
        }

        for (
          int i = 0;
          i <
              4;
          i++
        ) {
          if (weeklyVals[i] <
              0) {
            final deficit = -weeklyVals[i];
            weeklyVals[i] = 0;
            if (i +
                    1 <
                4)
              weeklyVals[i +
                      1] -=
                  deficit;
          }
        }

        final currentWeekIdx =
            (now.day <=
                7)
            ? 0
            : (now.day <=
                  14)
            ? 1
            : (now.day <=
                  22)
            ? 2
            : 3;

        const wLabels = [
          'W1',
          'W2',
          'W3',
          'W4',
        ];
        for (
          int i = 0;
          i <=
                  currentWeekIdx &&
              i <
                  4;
          i++
        ) {
          if (weeklyVals[i] !=
              0) {
            _savingsSeries.add(
              weeklyVals[i],
            );
            _savingsLabels.add(
              wLabels[i],
            );
          }
        }
      } else if (_periodIndex ==
          1) {
        final byMonth =
            List<
              num
            >.filled(
              12,
              0,
            );
        for (final r in mfrRows) {
          final d = DateTime.parse(
            r['period_start']
                as String,
          );
          byMonth[d.month -
                  1] +=
              (r['monthly_saving']
                  as num?) ??
              0;
        }

        const monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

        for (
          var i = 0;
          i <
              12;
          i++
        ) {
          if (byMonth[i] !=
              0) {
            _savingsSeries.add(
              byMonth[i] <
                      0
                  ? 0
                  : byMonth[i],
            );
            _savingsLabels.add(
              monthNames[i],
            );
          }
        }
      } else {
        final byYear =
            <
              int,
              num
            >{};
        for (final r in mfrRows) {
          final d = DateTime.parse(
            r['period_start']
                as String,
          );
          byYear[d.year] =
              (byYear[d.year] ??
                  0) +
              ((r['monthly_saving']
                      as num?) ??
                  0);
        }

        final years = byYear.keys.toList()..sort();
        for (final y in years) {
          final total =
              byYear[y] ??
              0;
          if (total !=
              0) {
            _savingsSeries.add(
              total <
                      0
                  ? 0
                  : total,
            );
            _savingsLabels.add(
              '$y',
            );
          }
        }
      }

      if (!mounted) return;
      setState(
        () {
          _loading = false;
        },
      );
    } catch (
      e
    ) {
      if (!mounted) return;
      setState(
        () {
          _error = e.toString();
          _loading = false;
        },
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Child Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete child',
            onPressed: _deletingChild
                ? null
                : _confirmDeleteChild,
            icon: _deletingChild
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
          ),
          const SizedBox(
            width: 6,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            )
          : _error !=
                null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final idx = _currentRawBucketIndex();

    num totalExpenses = 0, totalEarnings = 0;
    if (idx >=
            0 &&
        idx <
            _rawExpenses.length) {
      totalExpenses = _rawExpenses[idx];
      totalEarnings = _rawEarnings[idx];
    }

    final denom = totalEarnings;
    final left = math.max(
      0,
      denom -
          totalExpenses,
    );
    final percentLeft =
        denom <=
            0
        ? 0.0
        : (left /
                  denom)
              .clamp(
                0,
                1,
              )
              .toDouble();

    final overviewLegends = [
      _LegendItem(
        'Expenses',
        '${totalExpenses.toStringAsFixed(0)} SAR',
        _violet,
      ),
      _LegendItem(
        'Earnings',
        '${totalEarnings.toStringAsFixed(0)} SAR',
        _cyan,
      ),
    ];

    final trendsLegends = [
      _LegendItem(
        'Expenses',
        '${_seriesExpenses.fold<num>(0, (a, b) => a + b).toStringAsFixed(0)} SAR',
        _violet,
      ),
      _LegendItem(
        'Earnings',
        '${_seriesEarnings.fold<num>(0, (a, b) => a + b).toStringAsFixed(0)} SAR',
        _cyan,
      ),
    ];

    final String savingsYAxisTitle =
        _periodIndex ==
            0
        ? 'Weekly savings'
        : _periodIndex ==
              1
        ? 'Monthly savings'
        : 'Yearly savings';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChildHeaderCard(
            childName: _childName,
            childIcon: _childIcon,
          ),
          const SizedBox(
            height: 18,
          ),
          _AdultHeaderPanel(
            periodIndex: _periodIndex,
            onPeriodChanged:
                (
                  i,
                ) {
                  setState(
                    () {
                      _periodIndex = i;
                      _donutExpanded = false;
                      _showAllWeekly = false;
                      _showAllCategories = false;
                    },
                  );
                  _loadAll();
                },
          ),
          const SizedBox(
            height: 18,
          ),
          const _SectionTitle(
            'Money Overview',
          ),
          const SizedBox(
            height: 10,
          ),
          _AdultSectionCard(
            child: Column(
              children: [
                const SizedBox(
                  height: 8,
                ),
                MoneyLeftSemicircleGauge(
                  percent: percentLeft,
                  label: '${(percentLeft * 100).round()}% of\nmoney left',
                  expenses: totalExpenses.toDouble(),
                  earnings: totalEarnings.toDouble(),
                ),
                const SizedBox(
                  height: 8,
                ),
                _LegendRow(
                  items: overviewLegends,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const _SectionTitle(
            'Financial Trends',
          ),
          const SizedBox(
            height: 10,
          ),
          _AdultSectionCard(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(
                      MediaQuery.of(
                        context,
                      ).size.width,
                      _bucketLabels.length *
                          60,
                    ),
                    child: TrendsGroupedBars(
                      labels: _bucketLabels,
                      seriesA: _seriesExpenses
                          .map(
                            (
                              e,
                            ) => e.toDouble(),
                          )
                          .toList(),
                      seriesB: _seriesEarnings
                          .map(
                            (
                              e,
                            ) => e.toDouble(),
                          )
                          .toList(),
                      colorA: _violet,
                      colorB: _cyan,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                _LegendRow(
                  items: trendsLegends,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const _SectionTitle(
            'Savings Over Time',
          ),
          const SizedBox(
            height: 10,
          ),
          _AdultSectionCard(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 20,
                bottom: 8,
              ),
              child: SavingsSparkline(
                values: _savingsSeries
                    .map(
                      (
                        e,
                      ) => e.toDouble(),
                    )
                    .toList(),
                labels: _savingsLabels,
                yAxisTitle: savingsYAxisTitle,
                showPoints: true,
                emptyTextColor: Colors.white70,
                axisTextColor: Colors.white70,
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          const _SectionTitle(
            'Category Breakdown',
          ),
          const SizedBox(
            height: 10,
          ),
          _AdultSectionCard(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 8,
                  ),
                  if (_periodIndex ==
                      0)
                    Column(
                      children: [
                        _WeeklyMiniCategoryGrid(
                          weeklySlices: _weeklySlices,
                          weeklyTotals: _weeklyTotals,
                          weekIsFuture: _weekIsFuture,
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        if (_weeklyLegend.isEmpty)
                          const Center(
                            child: Text(
                              'No money spent yet',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else ...[
                          _CategoryGrid(
                            items: _weeklyLegend,
                            showAll: _showAllWeekly,
                            initialCount: 3,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          if (_weeklyLegend.length >
                              3)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () {
                                  setState(
                                    () {
                                      _showAllWeekly = !_showAllWeekly;
                                    },
                                  );
                                },
                                child: Text(
                                  _showAllWeekly
                                      ? 'Show less'
                                      : 'Show more',
                                ),
                              ),
                            ),
                        ],
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (_categorySlices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(
                              20,
                            ),
                            child: Center(
                              child: Text(
                                'No money spent',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          CategoryDonut(
                            slices: _categorySlices,
                            centerLabel: 'Total Expenses\nSAR ${_categorySlices.fold<num>(0, (a, b) => a + b.value).toStringAsFixed(0)}',
                            centerTextColor: Colors.white,
                            onCenterTap: () {
                              setState(
                                () {
                                  _donutExpanded = !_donutExpanded;
                                },
                              );
                            },
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          if (_donutExpanded)
                            _PeriodCategoryDetailsList(
                              slices: _categorySlices,
                            ),
                          const SizedBox(
                            height: 12,
                          ),
                          _CategoryGrid(
                            items: [
                              for (final s in _categorySlices)
                                _LegendItem(
                                  s.name,
                                  '${s.value.toStringAsFixed(0)} SAR',
                                  s.color,
                                ),
                            ],
                            showAll: _showAllCategories,
                            initialCount: 3,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          if (_categorySlices.length >
                              3)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () {
                                  setState(
                                    () {
                                      _showAllCategories = !_showAllCategories;
                                    },
                                  );
                                },
                                child: Text(
                                  _showAllCategories
                                      ? 'Show less'
                                      : 'Show more',
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildHeaderCard
    extends
        StatelessWidget {
  final String childName;
  final String? childIcon;

  const _ChildHeaderCard({
    required this.childName,
    required this.childIcon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        28,
        20,
        28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.g1,
            AppColors.g2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          28,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white24,
            child:
                (childIcon !=
                        null &&
                    childIcon!.trim().isNotEmpty)
                ? Text(
                    childIcon!,
                    style: const TextStyle(
                      fontSize: 42,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 42,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            childName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdultHeaderPanel
    extends
        StatelessWidget {
  final int periodIndex;
  final ValueChanged<
    int
  >
  onPeriodChanged;

  const _AdultHeaderPanel({
    required this.periodIndex,
    required this.onPeriodChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    Widget chip(
      String label,
      int i,
    ) {
      final selected =
          periodIndex ==
          i;

      return InkWell(
        borderRadius: BorderRadius.circular(
          18,
        ),
        onTap: () => onPeriodChanged(
          i,
        ),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : AppColors.card,
            borderRadius: BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : Colors.white10,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : AppColors.textGrey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(
          'Weekly',
          0,
        ),
        const SizedBox(
          width: 8,
        ),
        chip(
          'Monthly',
          1,
        ),
        const SizedBox(
          width: 8,
        ),
        chip(
          'Yearly',
          2,
        ),
      ],
    );
  }
}

class _AdultSectionCard
    extends
        StatelessWidget {
  final Widget child;

  const _AdultSectionCard({
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(
          22,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.20,
            ),
            blurRadius: 16,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle
    extends
        StatelessWidget {
  final String text;
  const _SectionTitle(
    this.text,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Bucket {
  final int? year;
  final int? month;
  final DateTime? middleDate;

  _Bucket(
    this.year,
    this.month,
    this.middleDate,
  );
}

class _Filtered {
  final List<
    String
  >
  labels;
  final List<
    num
  >
  expenses;
  final List<
    num
  >
  earnings;
  final List<
    num
  >
  income;

  _Filtered({
    required this.labels,
    required this.expenses,
    required this.earnings,
    required this.income,
  });
}

class _LegendItem {
  final String title;
  final String value;
  final Color color;

  const _LegendItem(
    this.title,
    this.value,
    this.color,
  );
}

class _LegendRow
    extends
        StatelessWidget {
  final List<
    _LegendItem
  >
  items;

  const _LegendRow({
    required this.items,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (
              e,
            ) => _LegendCard(
              item: e,
            ),
          )
          .toList(),
    );
  }
}

class _LegendCard
    extends
        StatelessWidget {
  final _LegendItem item;

  const _LegendCard({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 98,
      height: 86,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color,
            ),
          ),
          Column(
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid
    extends
        StatelessWidget {
  final List<
    _LegendItem
  >
  items;
  final bool showAll;
  final int initialCount;

  const _CategoryGrid({
    required this.items,
    required this.showAll,
    this.initialCount = 3,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final visible = showAll
        ? items
        : items
              .take(
                initialCount,
              )
              .toList();

    if (visible.isEmpty) {
      return const Center(
        child: Text(
          'No money spent',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio:
            98 /
            86,
      ),
      itemBuilder:
          (
            _,
            i,
          ) => _LegendCard(
            item: visible[i],
          ),
    );
  }
}

class _WeeklyMiniCategoryGrid
    extends
        StatefulWidget {
  final List<
    List<
      CategorySlice
    >
  >
  weeklySlices;
  final List<
    num
  >
  weeklyTotals;
  final List<
    bool
  >
  weekIsFuture;

  const _WeeklyMiniCategoryGrid({
    required this.weeklySlices,
    required this.weeklyTotals,
    required this.weekIsFuture,
  });

  @override
  State<
    _WeeklyMiniCategoryGrid
  >
  createState() => _WeeklyMiniCategoryGridState();
}

class _WeeklyMiniCategoryGridState
    extends
        State<
          _WeeklyMiniCategoryGrid
        > {
  int? _expandedIndex;

  @override
  Widget build(
    BuildContext context,
  ) {
    final wLabels = const [
      'W1',
      'W2',
      'W3',
      'W4',
    ];
    const baseMinHeight = 180.0;

    return LayoutBuilder(
      builder:
          (
            ctx,
            constraints,
          ) {
            final gap = 12.0;
            final cardWidth =
                (constraints.maxWidth -
                    gap) /
                2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(
                4,
                (
                  i,
                ) {
                  final isFuture = widget.weekIsFuture[i];
                  final total = widget.weeklyTotals[i];
                  final slices = widget.weeklySlices[i];
                  final isExpanded =
                      _expandedIndex ==
                      i;

                  Widget tileCore = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: isFuture
                            ? const Text(
                                'No data yet',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : (slices.isEmpty &&
                                  total ==
                                      0)
                            ? const Text(
                                '0 SAR spent',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : SizedBox.square(
                                dimension: 120,
                                child: Center(
                                  child: CategoryDonut(
                                    slices: slices,
                                    centerLabel: '${total.toStringAsFixed(0)} SAR',
                                    enableTooltip: false,
                                    centerTextColor: Colors.white,
                                    onTapAnywhere: () {
                                      if (isFuture ||
                                          (slices.isEmpty &&
                                              total ==
                                                  0)) {
                                        return;
                                      }
                                      setState(
                                        () {
                                          _expandedIndex = isExpanded
                                              ? null
                                              : i;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Center(
                        child: Text(
                          wLabels[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(
                          milliseconds: 220,
                        ),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child:
                            (!isFuture &&
                                slices.isNotEmpty &&
                                isExpanded)
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                ),
                                child: _WeeklyMiniDetailsList(
                                  slices: slices,
                                  total: total,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );

                  return SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      onTap: () {
                        if (isFuture ||
                            (slices.isEmpty &&
                                total ==
                                    0))
                          return;
                        setState(
                          () {
                            _expandedIndex = isExpanded
                                ? null
                                : i;
                          },
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: baseMinHeight,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(
                            18,
                          ),
                          border: Border.all(
                            color: Colors.white10,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          10,
                          10,
                          10,
                          10,
                        ),
                        child: tileCore,
                      ),
                    ),
                  );
                },
              ),
            );
          },
    );
  }
}

class _WeeklyMiniDetailsList
    extends
        StatelessWidget {
  final List<
    CategorySlice
  >
  slices;
  final num total;

  const _WeeklyMiniDetailsList({
    required this.slices,
    required this.total,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    Widget
    row(
      String l,
      String r,
    ) => Padding(
      padding: const EdgeInsets.only(
        top: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            r,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices)
          row(
            s.name,
            '${s.value.toStringAsFixed(0)} SAR',
          ),
        const SizedBox(
          height: 6,
        ),
        row(
          'Total',
          '${total.toStringAsFixed(0)} SAR',
        ),
      ],
    );
  }
}

class _PeriodCategoryDetailsList
    extends
        StatelessWidget {
  final List<
    CategorySlice
  >
  slices;

  const _PeriodCategoryDetailsList({
    required this.slices,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final total =
        slices.fold<
          num
        >(
          0,
          (
            a,
            b,
          ) =>
              a +
              b.value,
        );

    Widget
    row(
      String l,
      String r,
    ) => Padding(
      padding: const EdgeInsets.only(
        top: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            r,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          for (final s in slices)
            row(
              s.name,
              '${s.value.toStringAsFixed(0)} SAR',
            ),
          const SizedBox(
            height: 8,
          ),
          row(
            'Total',
            '${total.toStringAsFixed(0)} SAR',
          ),
        ],
      ),
    );
  }
}
