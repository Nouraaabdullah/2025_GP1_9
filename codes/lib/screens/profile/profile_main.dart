import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/screens/profile/spending_insight.dart';
import 'package:surra_application/screens/profile/edit_profile/edit_profile.dart';
import 'package:surra_application/utils/auth_helpers.dart';

class ProfileMainPage
    extends
        StatefulWidget {
  const ProfileMainPage({
    super.key,
  });

  @override
  State<
    ProfileMainPage
  >
  createState() => _ProfileMainPageState();
}

class _ProfileMainPageState
    extends
        State<
          ProfileMainPage
        > {
  final _sb = Supabase.instance.client;
  late Future<
    _DashboardData
  >
  _future;
  bool _isRefreshing = false;

  bool _isIncomeExpanded = false;
  bool _isExpenseExpanded = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshData();
  }

  Future<
    String
  >
  _getProfileId() async {
    final profileId = await getProfileId(
      context,
    );
    if (profileId ==
        null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (
            _,
          ) => false,
        );
      }
      throw Exception(
        'User not authenticated',
      );
    }
    return profileId;
  }

  Future<
    void
  >
  _refreshData() async {
    if (_isRefreshing) return;

    setState(
      () => _isRefreshing = true,
    );
    try {
      final newData = await _fetchDashboard();
      setState(
        () => _future = Future.value(
          newData,
        ),
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error refreshing data: $e',
      );
    } finally {
      if (mounted)
        setState(
          () => _isRefreshing = false,
        );
    }
  }

  Future<
    void
  >
  _logout() async {
    try {
      final shouldLogout =
          await showDialog<
            bool
          >(
            context: context,
            builder:
                (
                  context,
                ) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  content: const Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(
                            context,
                          ).pop(
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
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () =>
                          Navigator.of(
                            context,
                          ).pop(
                            true,
                          ),
                      child: const Text(
                        'Logout',
                      ),
                    ),
                  ],
                ),
          );

      if (shouldLogout ==
          true) {
        await _sb.auth.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/welcome',
            (
              route,
            ) => false,
          );
        }
      }
    } catch (
      e
    ) {
      debugPrint(
        'Logout error: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'Logout failed: $e',
            ),
          ),
        );
      }
    }
  }

  double _toDouble(
    dynamic v,
  ) {
    if (v ==
        null)
      return 0.0;
    if (v
        is num)
      return v.toDouble();
    if (v
        is String) {
      if (v.isEmpty) return 0.0;
      return double.tryParse(
            v,
          ) ??
          0.0;
    }
    return 0.0;
  }

  String
  _isoDate(
    DateTime d,
  ) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<
    void
  >
  _resetIsTransactedIfFirstOfMonth(
    String profileId,
  ) async {
    final now = DateTime.now();
    if (now.day !=
        1)
      return;

    try {
      await _sb
          .from(
            'Fixed_Income',
          )
          .update(
            {
              'is_transacted': false,
            },
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          )
          .eq(
            'is_transacted',
            true,
          );

      await _sb
          .from(
            'Fixed_Expense',
          )
          .update(
            {
              'is_transacted': false,
            },
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          )
          .eq(
            'is_transacted',
            true,
          );

      debugPrint(
        '✅ is_transacted reset for active incomes/expenses (day 1).',
      );
    } catch (
      e
    ) {
      debugPrint(
        '❌ reset is_transacted failed: $e',
      );
    }
  }

  Future<
    void
  >
  _applyTodayFixedMovements(
    String profileId,
  ) async {
    final now = DateTime.now();
    final todayDay = now.day;
    final lastDay = DateTime(
      now.year,
      now.month +
          1,
      0,
    ).day;

    try {
      // ----- FIXED INCOMES -----
      final incomes = await _sb
          .from(
            'Fixed_Income',
          )
          .select(
            'income_id, monthly_income, payday',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          )
          .eq(
            'is_transacted',
            false,
          );

      double incomeSum = 0.0;
      final List<
        String
      >
      incomeIdsToMark = [];

      if (incomes
          is List) {
        for (final row in incomes) {
          final payday =
              row['payday']
                  as int?;
          if (payday ==
              null)
            continue;

          // clamp payday to last day of this month (handles 31 in short months)
          final effectiveDay = payday.clamp(
            1,
            lastDay,
          );
          if (effectiveDay !=
              todayDay)
            continue;

          incomeSum += _toDouble(
            row['monthly_income'],
          );
          final id = row['income_id'];
          if (id !=
              null)
            incomeIdsToMark.add(
              id.toString(),
            );
        }
      }

      // ----- FIXED EXPENSES -----
      final expenses = await _sb
          .from(
            'Fixed_Expense',
          )
          .select(
            'expense_id, amount, due_date',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          )
          .eq(
            'is_transacted',
            false,
          );

      double expenseSum = 0.0;
      final List<
        String
      >
      expenseIdsToMark = [];

      if (expenses
          is List) {
        for (final row in expenses) {
          final due =
              row['due_date']
                  as int?;
          if (due ==
              null)
            continue;

          final effectiveDay = due.clamp(
            1,
            lastDay,
          );
          if (effectiveDay !=
              todayDay)
            continue;

          expenseSum += _toDouble(
            row['amount'],
          );
          final id = row['expense_id'];
          if (id !=
              null)
            expenseIdsToMark.add(
              id.toString(),
            );
        }
      }

      if (incomeSum ==
              0.0 &&
          expenseSum ==
              0.0) {
        debugPrint(
          'ℹ️ No fixed movements to apply today.',
        );
        return;
      }

      // ----- UPDATE BALANCE -----
      final prof = await _sb
          .from(
            'User_Profile',
          )
          .select(
            'current_balance',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .maybeSingle();

      if (prof ==
          null) {
        debugPrint(
          '⚠️ User_Profile not found. Skip apply.',
        );
        return;
      }

      final currentBalance = _toDouble(
        prof['current_balance'],
      );
      final delta =
          incomeSum -
          expenseSum;
      final newBalance =
          currentBalance +
          delta;

      await _sb
          .from(
            'User_Profile',
          )
          .update(
            {
              'current_balance': newBalance,
            },
          )
          .eq(
            'profile_id',
            profileId,
          );

      // mark applied
      for (final id in incomeIdsToMark) {
        await _sb
            .from(
              'Fixed_Income',
            )
            .update(
              {
                'is_transacted': true,
              },
            )
            .eq(
              'income_id',
              id,
            );
      }
      for (final id in expenseIdsToMark) {
        await _sb
            .from(
              'Fixed_Expense',
            )
            .update(
              {
                'is_transacted': true,
              },
            )
            .eq(
              'expense_id',
              id,
            );
      }

      debugPrint(
        '✅ Applied today: +$incomeSum (income), -$expenseSum (expense) → Δ=$delta',
      );
    } catch (
      e
    ) {
      debugPrint(
        '❌ _applyTodayFixedMovements failed: $e',
      );
    }
  }

  Future<
    _DashboardData
  >
  _fetchDashboard() async {
    try {
      final profileId = await _getProfileId();

      final now = DateTime.now();
      final firstOfMonth = DateTime(
        now.year,
        now.month,
        1,
      );
      final todayIso = _isoDate(
        now,
      );
      final firstIso = _isoDate(
        firstOfMonth,
      );

      await _resetIsTransactedIfFirstOfMonth(
        profileId,
      );
      await _applyTodayFixedMovements(
        profileId,
      );

      final prof = await _sb
          .from(
            'User_Profile',
          )
          .select(
            'full_name, current_balance',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .maybeSingle();

      final fullName =
          (prof?['full_name']
              as String?) ??
          'User';
      final currentBalance = _toDouble(
        prof?['current_balance'],
      );

      final monthlyRecord = await _sb
          .from(
            'Monthly_Financial_Record',
          )
          .select(
            'total_income, total_expense, total_earning',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .lte(
            'period_start',
            todayIso,
          )
          .gte(
            'period_end',
            todayIso,
          )
          .maybeSingle();

      double totalIncome = _toDouble(
        monthlyRecord?['total_income'],
      );
      double totalExpense = _toDouble(
        monthlyRecord?['total_expense'],
      );
      double totalEarnings = _toDouble(
        monthlyRecord?['total_earning'],
      );

      final earnings = await _sb
          .from(
            'Transaction',
          )
          .select(
            'amount, date',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .eq(
            'type',
            'Earning',
          )
          .gte(
            'date',
            firstIso,
          )
          .lte(
            'date',
            todayIso,
          );

      double totalEarningsFromTransactions = 0.0;
      if (earnings
          is List) {
        for (final earning in earnings) {
          totalEarningsFromTransactions += _toDouble(
            earning['amount'],
          );
        }
      }

      if (monthlyRecord ==
          null) {
        final expenses = await _sb
            .from(
              'Transaction',
            )
            .select(
              'amount, date, type',
            )
            .eq(
              'profile_id',
              profileId,
            )
            .eq(
              'type',
              'Expense',
            )
            .gte(
              'date',
              firstIso,
            )
            .lte(
              'date',
              todayIso,
            );

        final incomes = await _sb
            .from(
              'Transaction',
            )
            .select(
              'amount, date, type',
            )
            .eq(
              'profile_id',
              profileId,
            )
            .eq(
              'type',
              'Income',
            )
            .gte(
              'date',
              firstIso,
            )
            .lte(
              'date',
              todayIso,
            );

        totalExpense = 0.0;
        if (expenses
            is List) {
          for (final r in expenses) {
            totalExpense += _toDouble(
              r['amount'],
            );
          }
        }

        totalIncome = 0.0;
        if (incomes
            is List) {
          for (final r in incomes) {
            totalIncome += _toDouble(
              r['amount'],
            );
          }
        }
      }

      final fixedIncomeRows = await _sb
          .from(
            'Fixed_Income',
          )
          .select(
            'income_id, name, payday, monthly_income, is_primary',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          );

      final fixedExpenseRows = await _sb
          .from(
            'Fixed_Expense',
          )
          .select(
            'expense_id, name, due_date, amount',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .filter(
            'end_time',
            'is',
            null,
          );

      final incomeItems =
          <
            _TransactionItem
          >[];
      if (fixedIncomeRows
          is List) {
        final sorted = List.from(
          fixedIncomeRows,
        );
        sorted.sort(
          (
            a,
            b,
          ) {
            final aIsPrimary =
                (a['is_primary']
                    as bool?) ??
                false;
            final bIsPrimary =
                (b['is_primary']
                    as bool?) ??
                false;
            if (bIsPrimary &&
                !aIsPrimary)
              return 1;
            if (!bIsPrimary &&
                aIsPrimary)
              return -1;
            return 0;
          },
        );

        for (final row in sorted) {
          final name =
              (row['name']
                  as String?) ??
              'Income';
          final day = row['payday'];
          final amount = _toDouble(
            row['monthly_income'],
          );
          final date =
              (day ==
                  null)
              ? 'No date'
              : 'Day $day of month';
          incomeItems.add(
            _TransactionItem(
              title: name,
              amount: amount,
              date: date,
            ),
          );
        }
      }

      final expenseItems =
          <
            _TransactionItem
          >[];
      if (fixedExpenseRows
          is List) {
        for (final row in fixedExpenseRows) {
          final name =
              (row['name']
                  as String?) ??
              'Expense';
          final day = row['due_date'];
          final amount = _toDouble(
            row['amount'],
          );
          final date =
              (day ==
                  null)
              ? 'No date'
              : 'Day $day of month';
          expenseItems.add(
            _TransactionItem(
              title: name,
              amount: amount,
              date: date,
            ),
          );
        }
      }

      final cats = await _sb
          .from(
            'Category',
          )
          .select(
            'category_id, name, monthly_limit, icon, icon_color',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .eq(
            'is_archived',
            false,
          )
          .order(
            'name',
          );

      final trxThisMonth = await _sb
          .from(
            'Transaction',
          )
          .select(
            'category_id, amount, type, date',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .eq(
            'type',
            'Expense',
          )
          .gte(
            'date',
            firstIso,
          )
          .lte(
            'date',
            todayIso,
          );

      final Map<
        String,
        double
      >
      totalByCat = {};
      if (trxThisMonth
          is List) {
        for (final t in trxThisMonth) {
          final cid =
              t['category_id']
                  as String?;
          if (cid ==
              null)
            continue;
          final amount = _toDouble(
            t['amount'],
          );
          totalByCat[cid] =
              (totalByCat[cid] ??
                  0) +
              amount;
        }
      }

      final items =
          <
            _CategoryDash
          >[];
      if (cats
          is List) {
        for (final c in cats) {
          final id =
              c['category_id']
                  as String;
          final name =
              (c['name']
                  as String?) ??
              'Category';
          final limit = _toDouble(
            c['monthly_limit'],
          );
          final spent =
              totalByCat[id] ??
              0.0;

          final pct =
              (limit >
                  0)
              ? ((spent /
                            limit) *
                        100.0)
                    .clamp(
                      0.0,
                      100.0,
                    )
              : null;

          final icon =
              c['icon']
                  as String? ??
              'category';
          final color =
              c['icon_color']
                  as String? ??
              '#7D5EF6';

          items.add(
            _CategoryDash(
              name: name,
              amount: spent,
              percent: pct,
              icon: icon,
              color: color,
            ),
          );
        }
      }

      return _DashboardData(
        fullName: fullName,
        currentBalance: currentBalance,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        totalEarnings: totalEarningsFromTransactions,
        categories: items,
        incomeItems: incomeItems,
        expenseItems: expenseItems,
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error fetching dashboard data: $e',
      );
      return _DashboardData(
        fullName: 'User',
        currentBalance: 0.0,
        totalIncome: 0.0,
        totalExpense: 0.0,
        totalEarnings: 0.0,
        categories: const [],
        incomeItems: const [],
        expenseItems: const [],
      );
    }
  }

  String
  _fmt2(
    double v,
  ) => v.toStringAsFixed(
    2,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child:
            FutureBuilder<
              _DashboardData
            >(
              future: _future,
              builder:
                  (
                    context,
                    snap,
                  ) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Failed to load profile\n${snap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            ElevatedButton(
                              onPressed: _refreshData,
                              child: const Text(
                                'Retry',
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            ElevatedButton(
                              onPressed: _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Logout & Sign In Again',
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final data = snap.data!;

                    return Stack(
                      children: [
                        const TopGradient(
                          height: 450,
                        ),
                        SafeArea(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ---------- TOP CONTENT WITH PADDING (UNCHANGED) ----------
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Welcome ${data.fullName}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (_isRefreshing)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 8,
                                                  ),
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => const EditProfilePage(),
                                                      ),
                                                    ).then(
                                                      (
                                                        _,
                                                      ) => _refreshData(),
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.logout,
                                                  color: Colors.white,
                                                ),
                                                onPressed: _logout,
                                                tooltip: 'Logout',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(
                                          18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Total Balance',
                                              style: TextStyle(
                                                color: Color(
                                                  0xFFD9D9D9,
                                                ),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              '${_fmt2(data.currentBalance)} SAR',
                                              style: const TextStyle(
                                                color: Color(
                                                  0xFFD9D9D9,
                                                ),
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                                height: 1.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 24,
                                      ),
                                      _buildExpandableSummary(
                                        data,
                                      ),
                                      const SizedBox(
                                        height: 32,
                                      ),
                                    ],
                                  ),
                                ),

                                // ---------- BIG CATEGORIES SECTION (UPDATED) ----------
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    28,
                                    20,
                                    24,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.bg, // solid dark, no transparency
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(
                                        40,
                                      ),
                                      topRight: Radius.circular(
                                        40,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Categories',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              height: 1.1,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () {
                                              Navigator.of(
                                                    context,
                                                  )
                                                  .push(
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            _,
                                                          ) => const SpendingInsightPage(),
                                                    ),
                                                  )
                                                  .then(
                                                    (
                                                      _,
                                                    ) => _refreshData(),
                                                  );
                                            },
                                            child: const Text(
                                              'View Details',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 16,
                                      ),
                                      (data.categories.isEmpty)
                                          ? GridView.count(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.82,
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              children: const [
                                                _EmptyCategoryCard(),
                                                _EmptyCategoryCard(),
                                                _EmptyCategoryCard(),
                                              ],
                                            )
                                          : GridView.builder(
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                mainAxisSpacing: 12,
                                                crossAxisSpacing: 12,
                                                childAspectRatio: 0.82,
                                              ),
                                              itemCount: data.categories.length,
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemBuilder:
                                                  (
                                                    context,
                                                    i,
                                                  ) {
                                                    final c = data.categories[i];
                                                    final pct =
                                                        c.percent ==
                                                            null
                                                        ? '—'
                                                        : '${c.percent!.clamp(0, 100).toStringAsFixed(0)}%';
                                                    return _CategoryCard(
                                                      title: c.name,
                                                      amount: '${_fmt2(c.amount)} SAR',
                                                      percent: pct,
                                                      icon: c.icon,
                                                      color: c.color,
                                                    );
                                                  },
                                            ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
            ),
      ),
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(
          context,
          '/dashboard',
        ),
        onTapSavings: () => Navigator.pushNamed(
          context,
          '/savings',
        ),
        onTapProfile: () {},
      ),
    );
  }

  Widget _buildExpandableSummary(
    _DashboardData data,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildExpandableCard(
                label: 'Expense',
                icon: Icons.arrow_downward,
                iconColor: const Color(
                  0xFFFF6B9D,
                ),
                amount: _fmt2(
                  data.totalExpense,
                ),
                items: data.expenseItems,
                isExpanded: _isExpenseExpanded,
                onToggle: () {
                  setState(
                    () => _isExpenseExpanded = !_isExpenseExpanded,
                  );
                },
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: _buildExpandableCard(
                label: 'Income',
                icon: Icons.arrow_upward,
                iconColor: const Color(
                  0xFF4ECDC4,
                ),
                amount: _fmt2(
                  data.totalIncome,
                ),
                items: data.incomeItems,
                isExpanded: _isIncomeExpanded,
                onToggle: () {
                  setState(
                    () => _isIncomeExpanded = !_isIncomeExpanded,
                  );
                },
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          color: const Color(
                            0xFFFFD93D,
                          ),
                          size: 14,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        const Text(
                          'Earnings',
                          style: TextStyle(
                            color: Color(
                              0xFFD9D9D9,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      '${_fmt2(data.totalEarnings)} SAR',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(
                          0xFFD9D9D9,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    const Text(
                      'This month',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(
                          0xFFB0B0B0,
                        ),
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_isExpenseExpanded)
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
            ),
            child: _buildExpandedList(
              data.expenseItems,
              const Color(
                0xFFFF6B9D,
              ),
            ),
          ),
        if (_isIncomeExpanded)
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
            ),
            child: _buildExpandedList(
              data.incomeItems,
              const Color(
                0xFF4ECDC4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandableCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String amount,
    required List<
      _TransactionItem
    >
    items,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(
              16,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: 14,
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(
                        0xFFD9D9D9,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                '$amount SAR',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(
                    0xFFD9D9D9,
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              const Text(
                'This month',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(
                    0xFFB0B0B0,
                  ),
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.bg.withOpacity(
                    0.6,
                  ),
                  borderRadius: BorderRadius.circular(
                    6,
                  ),
                ),
                child: Icon(
                  isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedList(
    List<
      _TransactionItem
    >
    items,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(
          0.6,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: accentColor.withOpacity(
            0.3,
          ),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(
        12,
      ),
      child: Column(
        children: items.map(
          (
            item,
          ) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card.withOpacity(
                    0.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: accentColor.withOpacity(
                      0.2,
                    ),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_fmt2(item.amount)} SAR',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          item.date,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}

// ===== Data Classes =====

class _TransactionItem {
  final String title;
  final double amount;
  final String date;

  const _TransactionItem({
    required this.title,
    required this.amount,
    required this.date,
  });
}

class _DashboardData {
  final String fullName;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final double totalEarnings;
  final List<
    _CategoryDash
  >
  categories;
  final List<
    _TransactionItem
  >
  incomeItems;
  final List<
    _TransactionItem
  >
  expenseItems;

  _DashboardData({
    required this.fullName,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalEarnings,
    required this.categories,
    required this.incomeItems,
    required this.expenseItems,
  });
}

class _CategoryDash {
  final String name;
  final double amount;
  final double? percent;
  final String icon;
  final String color;

  const _CategoryDash({
    required this.name,
    required this.amount,
    required this.percent,
    required this.icon,
    required this.color,
  });
}

// ===== Category Cards =====

class _CategoryCard
    extends
        StatelessWidget {
  final String title, amount, percent, icon, color;

  const _CategoryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.percent,
    required this.icon,
    required this.color,
  });

  Color _hexToColor(
    String hex,
  ) {
    hex = hex.replaceAll(
      '#',
      '',
    );
    if (hex.length ==
        6)
      hex = 'FF$hex';
    return Color(
      int.parse(
        hex,
        radix: 16,
      ),
    );
  }

  IconData _iconDataFromString(
    String iconString,
  ) {
    try {
      if (iconString.startsWith(
        'IconData(U+',
      )) {
        final hexCode = iconString.substring(
          11,
          iconString.length -
              1,
        );
        final codePoint = int.parse(
          hexCode,
          radix: 16,
        );
        return IconData(
          codePoint,
          fontFamily: 'MaterialIcons',
        );
      }
      return _stringToIconData(
        iconString,
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error converting icon string: $iconString, error: $e',
      );
      return Icons.category;
    }
  }

  IconData _stringToIconData(
    String iconString,
  ) {
    try {
      if (iconString.contains(
        '.',
      )) {
        final iconName = iconString
            .split(
              '.',
            )
            .last;
        return _findIconByName(
          iconName,
        );
      } else {
        return _findIconByName(
          iconString,
        );
      }
    } catch (
      e
    ) {
      debugPrint(
        'Error converting string to IconData: $e',
      );
      return Icons.category;
    }
  }

  IconData _findIconByName(
    String iconName,
  ) {
    final iconMap = {
      'fastfood': Icons.fastfood,
      'shopping_bag': Icons.shopping_bag,
      'home': Icons.home,
      'airplanemode_active': Icons.airplanemode_active,
      'movie': Icons.movie,
      'sports_soccer': Icons.sports_soccer,
      'work': Icons.work,
      'pets': Icons.pets,
      'brush': Icons.brush,
      'local_cafe': Icons.local_cafe,
      'computer': Icons.computer,
      'attach_money': Icons.attach_money,
      'account_balance_wallet': Icons.account_balance_wallet,
      'category': Icons.category,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'sports_esports': Icons.sports_esports,
      'flight': Icons.flight,
      'local_offer': Icons.local_offer,
      'fitness_center': Icons.fitness_center,
      'music_note': Icons.music_note,
      'book': Icons.book,
      'child_care': Icons.child_care,
      'spa': Icons.spa,
      'construction': Icons.construction,
      'description': Icons.description,
    };
    return iconMap[iconName] ??
        Icons.category;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final iconColor = _hexToColor(
      color,
    );
    final iconData = _iconDataFromString(
      icon,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(
                0.12,
              ),
              borderRadius: BorderRadius.circular(
                18,
              ),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            amount,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          const _PercentBadgeSpacer(),
          _PercentBadge(
            text:
                percent ==
                    '—'
                ? 'No limit set'
                : '$percent budget used',
          ),
          const _PercentBadgeSpacer(
            height: 2,
          ),
        ],
      ),
    );
  }
}

class _PercentBadgeSpacer
    extends
        StatelessWidget {
  final double height;

  const _PercentBadgeSpacer({
    this.height = 0,
  });

  @override
  Widget
  build(
    BuildContext context,
  ) => SizedBox(
    height: height,
  );
}

class _PercentBadge
    extends
        StatelessWidget {
  final String text;

  const _PercentBadge({
    super.key,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(
            10,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCategoryCard
    extends
        StatelessWidget {
  const _EmptyCategoryCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(
          0.7,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
    );
  }
}
