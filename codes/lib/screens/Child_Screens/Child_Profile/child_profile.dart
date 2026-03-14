import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart';
import 'child_category_details.dart';

class KidCategory {
  final String categoryId;
  String name;
  String emoji;
  double spent;
  double limit;
  final Color color;
  final Color softColor;
  final String iconName;
  final String iconColorHex;

  KidCategory({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.spent,
    required this.limit,
    required this.color,
    required this.softColor,
    required this.iconName,
    required this.iconColorHex,
  });

  KidCategory copyWith({
    String? categoryId,
    String? name,
    String? emoji,
    double? spent,
    double? limit,
    Color? color,
    Color? softColor,
    String? iconName,
    String? iconColorHex,
  }) {
    return KidCategory(
      categoryId:
          categoryId ??
          this.categoryId,
      name:
          name ??
          this.name,
      emoji:
          emoji ??
          this.emoji,
      spent:
          spent ??
          this.spent,
      limit:
          limit ??
          this.limit,
      color:
          color ??
          this.color,
      softColor:
          softColor ??
          this.softColor,
      iconName:
          iconName ??
          this.iconName,
      iconColorHex:
          iconColorHex ??
          this.iconColorHex,
    );
  }
}

class ChildProfilePage
    extends
        StatefulWidget {
  const ChildProfilePage({
    super.key,
  });

  @override
  State<
    ChildProfilePage
  >
  createState() => _ChildProfilePageState();
}

class _ChildProfilePageState
    extends
        State<
          ChildProfilePage
        >
    with
        SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  late AnimationController _bounceController;
  late Animation<
    double
  >
  _bounceAnimation;

  static const _kPurple = Color(
    0xFF8B5CF6,
  );
  static const _kPurpleDark = Color(
    0xFF6D28D9,
  );
  static const _kPink = Color(
    0xFFF472B6,
  );
  static const _kGreen = Color(
    0xFF34D399,
  );
  static const _kText = Color(
    0xFF2D1B69,
  );
  static const _kTextSoft = Color(
    0xFF7C6FA0,
  );
  static const _kCard = Color(
    0xD0FFFFFF,
  );

  static const _kidBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [
      0.0,
      0.45,
      1.0,
    ],
    colors: [
      Color(
        0xFFD4B3F5,
      ),
      Color(
        0xFFB8D4F8,
      ),
      Color(
        0xFFF7B8D4,
      ),
    ],
  );

  bool _loading = true;
  bool _isRefreshing = false;

  String _childName = 'Kid';
  double _balance = 0.0;
  double _spent = 0.0;
  double _earned = 0.0;

  List<
    KidCategory
  >
  _categories = [];

  @override
  void initState() {
    super.initState();

    _bounceController =
        AnimationController(
          vsync: this,
          duration: const Duration(
            milliseconds: 1200,
          ),
        )..repeat(
          reverse: true,
        );

    _bounceAnimation =
        Tween<
              double
            >(
              begin: 0,
              end: -6,
            )
            .animate(
              CurvedAnimation(
                parent: _bounceController,
                curve: Curves.easeInOut,
              ),
            );

    _loadChildDashboard();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  String
  _fmt(
    double v,
  ) => v.toStringAsFixed(
    2,
  );

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
      if (v.trim().isEmpty) return 0.0;
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

  String _colorToHex(
    Color color,
  ) {
    final a = color.alpha
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final r = color.red
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final g = color.green
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final b = color.blue
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    return '#$a$r$g$b'.toUpperCase();
  }

  Color _makeSoftColor(
    Color color,
  ) {
    return Color.lerp(
          color,
          Colors.white,
          0.82,
        ) ??
        color.withOpacity(
          0.18,
        );
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
      await _loadChildDashboard(
        showLoader: false,
      );
    } finally {
      if (mounted) {
        setState(
          () => _isRefreshing = false,
        );
      }
    }
  }

  Future<
    void
  >
  _loadChildDashboard({
    bool showLoader = true,
  }) async {
    if (showLoader &&
        mounted) {
      setState(
        () => _loading = true,
      );
    }

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
                  as String?)
              ?.trim();
      final currentBalance = _toDouble(
        prof?['current_balance'],
      );

      final monthlyRecord = await _sb
          .from(
            'Monthly_Financial_Record',
          )
          .select(
            'record_id, total_expense, total_earning',
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

      double totalExpense = _toDouble(
        monthlyRecord?['total_expense'],
      );
      double totalEarning = _toDouble(
        monthlyRecord?['total_earning'],
      );

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

        final earnings = await _sb
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

        totalExpense = 0.0;
        if (expenses
            is List) {
          for (final row in expenses) {
            totalExpense += _toDouble(
              row['amount'],
            );
          }
        }

        totalEarning = 0.0;
        if (earnings
            is List) {
          for (final row in earnings) {
            totalEarning += _toDouble(
              row['amount'],
            );
          }
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

      final Map<
        String,
        double
      >
      totalByCat = {};

      if (monthlyRecord !=
              null &&
          monthlyRecord['record_id'] !=
              null) {
        final recordId =
            monthlyRecord['record_id']
                as String;

        final summaries = await _sb
            .from(
              'Category_Summary',
            )
            .select(
              'category_id, total_expense',
            )
            .eq(
              'record_id',
              recordId,
            );

        if (summaries
            is List) {
          for (final row in summaries) {
            final cid =
                row['category_id']
                    as String?;
            if (cid ==
                null)
              continue;
            totalByCat[cid] = _toDouble(
              row['total_expense'],
            );
          }
        }
      } else {
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

        if (trxThisMonth
            is List) {
          for (final row in trxThisMonth) {
            final cid =
                row['category_id']
                    as String?;
            if (cid ==
                null)
              continue;
            totalByCat[cid] =
                (totalByCat[cid] ??
                    0.0) +
                _toDouble(
                  row['amount'],
                );
          }
        }
      }

      final List<
        KidCategory
      >
      items = [];
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
          final iconValue =
              (c['icon']
                  as String?) ??
              '✨';
          final iconColorHex =
              (c['icon_color']
                  as String?) ??
              '#FF7D5EF6';
          final color = _hexToColor(
            iconColorHex,
          );

          items.add(
            KidCategory(
              categoryId: id,
              name: name,
              emoji: iconValue,
              spent: spent,
              limit: limit,
              color: color,
              softColor: _makeSoftColor(
                color,
              ),
              iconName: iconValue,
              iconColorHex: iconColorHex,
            ),
          );
        }
      }

      items.sort(
        (
          a,
          b,
        ) => b.spent.compareTo(
          a.spent,
        ),
      );

      if (!mounted) return;

      setState(
        () {
          _childName =
              (fullName !=
                      null &&
                  fullName.isNotEmpty)
              ? fullName
              : 'Kid';
          _balance = currentBalance;
          _spent = totalExpense;
          _earned = totalEarning;
          _categories = items;
          _loading = false;
        },
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error loading child dashboard: $e',
      );
      if (!mounted) return;
      setState(
        () {
          _childName = 'Kid';
          _balance = 0.0;
          _spent = 0.0;
          _earned = 0.0;
          _categories = [];
          _loading = false;
        },
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (
            ctx,
          ) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                28,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(
                24,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  28,
                ),
                gradient: const LinearGradient(
                  colors: [
                    Color(
                      0xFFF0E6FF,
                    ),
                    Color(
                      0xFFE6F0FF,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '👋',
                    style: TextStyle(
                      fontSize: 48,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    'See you later!',
                    style: TextStyle(
                      fontFamily: 'Fredoka One',
                      fontSize: 22,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Are you sure you want to log out?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: _kTextSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                            backgroundColor: const Color(
                              0xFFEDE9FE,
                            ),
                          ),
                          onPressed: () => Navigator.pop(
                            ctx,
                          ),
                          child: Text(
                            'Stay!',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              color: _kPurple,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            backgroundColor: _kPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(
                              ctx,
                            );
                            await _sb.auth.signOut();
                            if (mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/startpage',
                                (
                                  _,
                                ) => false,
                              );
                            }
                          },
                          child: const Text(
                            'Bye! 👋',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openCategoryDetail(
    KidCategory cat,
  ) async {
    final updated =
        await Navigator.push<
          KidCategory
        >(
          context,
          PageRouteBuilder(
            pageBuilder:
                (
                  _,
                  anim,
                  __,
                ) => ChildCategoryDetailPage(
                  category: cat,
                ),
            transitionsBuilder:
                (
                  _,
                  anim,
                  __,
                  child,
                ) => SlideTransition(
                  position:
                      Tween<
                            Offset
                          >(
                            begin: const Offset(
                              0,
                              1,
                            ),
                            end: Offset.zero,
                          )
                          .animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                  child: child,
                ),
            transitionDuration: const Duration(
              milliseconds: 380,
            ),
          ),
        );

    if (updated !=
        null) {
      setState(
        () {
          final idx = _categories.indexWhere(
            (
              c,
            ) =>
                c.categoryId ==
                updated.categoryId,
          );
          if (idx !=
              -1) {
            _categories[idx] = updated;
          }
        },
      );
      await _refreshData();
    }
  }

  Future<
    void
  >
  _openAddCategoryPage() async {
    final profileId = await _getProfileId();

    if (!mounted) return;

    final added =
        await Navigator.push<
          bool
        >(
          context,
          MaterialPageRoute(
            builder:
                (
                  _,
                ) => ChildAddCategoryPage(
                  profileId: profileId,
                ),
          ),
        );

    if (added ==
        true) {
      await _refreshData();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: _kidBg,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: Column(
                    children: [
                      _buildTopSection(),
                      Expanded(
                        child: _buildCategoriesSection(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder:
                    (
                      _,
                      child,
                    ) => Transform.translate(
                      offset: Offset(
                        0,
                        _bounceAnimation.value,
                      ),
                      child: child,
                    ),
                child: const Text(
                  '⭐',
                  style: TextStyle(
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi there,',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTextSoft,
                      ),
                    ),
                    Text(
                      '$_childName!',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Fredoka One',
                        fontSize: 26,
                        color: _kText,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(
                    right: 8,
                  ),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              _KidIconButton(
                onTap: () {},
                emoji: '✏️',
                bgColor: const Color(
                  0xFFEDE9FE,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              _KidIconButton(
                onTap: _showLogoutDialog,
                emoji: '🚪',
                bgColor: const Color(
                  0xFFFCE7F3,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildHeroBalanceCard(),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildMiniStatCard(
                label: 'Spent',
                isUp: false,
                amount: _fmt(
                  _spent,
                ),
                color: _kPink,
                softColor: const Color(
                  0xFFFCE7F3,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              _buildMiniStatCard(
                label: 'Earned',
                isUp: true,
                amount: _fmt(
                  _earned,
                ),
                color: _kGreen,
                softColor: const Color(
                  0xFFD1FAE5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBalanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 22,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(
              0xFF8B5CF6,
            ),
            Color(
              0xFF6D28D9,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(
          24,
        ),
        boxShadow: [
          BoxShadow(
            color: _kPurpleDark.withOpacity(
              0.35,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.2,
              ),
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
            child: const Text(
              '💰 My Balance',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_fmt(_balance)} SAR',
              style: const TextStyle(
                fontFamily: 'Fredoka One',
                fontSize: 28,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required bool isUp,
    required String amount,
    required Color color,
    required Color softColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(
          20,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(
              0.15,
            ),
            blurRadius: 12,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: softColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUp
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kTextSoft,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$amount SAR',
                    style: TextStyle(
                      fontFamily: 'Fredoka One',
                      fontSize: 15,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            36,
          ),
          topRight: Radius.circular(
            36,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              22,
              20,
              0,
            ),
            child: Row(
              children: [
                const Text(
                  '',
                  style: TextStyle(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    'My Categories',
                    style: TextStyle(
                      fontFamily: 'Fredoka One',
                      fontSize: 22,
                      color: _kText,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openAddCategoryPage,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFEDE9FE,
                      ),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add,
                      color: _kPurple,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              'Tap a category to see details ✨',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kTextSoft,
              ),
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Expanded(
            child: _categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories yet ✨',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kTextSoft,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: _categories.length,
                    itemBuilder:
                        (
                          context,
                          i,
                        ) {
                          final cat = _categories[i];
                          return _KidCategoryCard(
                            category: cat,
                            onTap: () => _openCategoryDetail(
                              cat,
                            ),
                          );
                        },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KidCategoryCard
    extends
        StatelessWidget {
  final KidCategory category;
  final VoidCallback onTap;

  static const _kText = Color(
    0xFF2D1B69,
  );
  static const _kTextSoft = Color(
    0xFF7C6FA0,
  );

  const _KidCategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final pct =
        category.limit >
            0
        ? (category.spent /
                  category.limit)
              .clamp(
                0.0,
                1.0,
              )
        : 0.0;
    final pctInt =
        (pct *
                100)
            .toStringAsFixed(
              0,
            );
    final isOverHalf =
        pct >
        0.5;
    final isAlmostFull =
        pct >
        0.85;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            22,
          ),
          border: Border.all(
            color: category.softColor,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: category.color.withOpacity(
                0.10,
              ),
              blurRadius: 14,
              offset: const Offset(
                0,
                4,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: category.softColor,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    category.emoji,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isAlmostFull
                        ? const Color(
                            0xFFFFE4E4,
                          )
                        : isOverHalf
                        ? const Color(
                            0xFFFEF3C7,
                          )
                        : category.softColor,
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Text(
                    '$pctInt%',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: isAlmostFull
                          ? const Color(
                              0xFFE53E3E,
                            )
                          : isOverHalf
                          ? const Color(
                              0xFFB7791F,
                            )
                          : category.color,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            Text(
              '${category.spent.toStringAsFixed(0)} / ${category.limit.toStringAsFixed(0)} SAR',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kTextSoft,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(
                8,
              ),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: category.softColor,
                valueColor:
                    AlwaysStoppedAnimation<
                      Color
                    >(
                      isAlmostFull
                          ? const Color(
                              0xFFFC8181,
                            )
                          : category.color,
                    ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KidIconButton
    extends
        StatelessWidget {
  final VoidCallback onTap;
  final String emoji;
  final Color bgColor;

  const _KidIconButton({
    required this.onTap,
    required this.emoji,
    required this.bgColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(
            14,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.07,
              ),
              blurRadius: 8,
              offset: const Offset(
                0,
                3,
              ),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class ChildAddCategoryPage
    extends
        StatefulWidget {
  final String profileId;

  const ChildAddCategoryPage({
    super.key,
    required this.profileId,
  });

  @override
  State<
    ChildAddCategoryPage
  >
  createState() => _ChildAddCategoryPageState();
}

class _ChildAddCategoryPageState
    extends
        State<
          ChildAddCategoryPage
        > {
  final _sb = Supabase.instance.client;
  final _formKey =
      GlobalKey<
        FormState
      >();

  static const _kPurple = Color(
    0xFF8B5CF6,
  );
  static const _kText = Color(
    0xFF2D1B69,
  );
  static const _kTextSoft = Color(
    0xFF7C6FA0,
  );

  final _nameController = TextEditingController();
  final _limitController = TextEditingController();

  String _selectedIcon = '✨';
  Color _selectedColor = const Color(
    0xFF8B5CF6,
  );
  bool _saving = false;

  final List<
    Map<
      String,
      String
    >
  >
  _iconOptions = const [
    {
      'icon': '🍔',
      'emoji': '🍔',
    },
    {
      'icon': '🛍️',
      'emoji': '🛍️',
    },
    {
      'icon': '🎬',
      'emoji': '🎬',
    },
    {
      'icon': '🎮',
      'emoji': '🎮',
    },
    {
      'icon': '📖',
      'emoji': '📖',
    },
    {
      'icon': '🎨',
      'emoji': '🎨',
    },
    {
      'icon': '🎵',
      'emoji': '🎵',
    },
    {
      'icon': '⚽',
      'emoji': '⚽',
    },
    {
      'icon': '🧸',
      'emoji': '🧸',
    },
    {
      'icon': '🛒',
      'emoji': '🛒',
    },
    {
      'icon': '🍽️',
      'emoji': '🍽️',
    },
    {
      'icon': '✨',
      'emoji': '✨',
    },
  ];
  final List<
    Color
  >
  _colorOptions = const [
    Color(
      0xFF8B5CF6,
    ),
    Color(
      0xFFF472B6,
    ),
    Color(
      0xFF34D399,
    ),
    Color(
      0xFF60A5FA,
    ),
    Color(
      0xFFFBBF24,
    ),
    Color(
      0xFFFB923C,
    ),
    Color(
      0xFFFF6B6B,
    ),
    Color(
      0xFFA78BFA,
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  String _colorToHex(
    Color color,
  ) {
    final a = color.alpha
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final r = color.red
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final g = color.green
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    final b = color.blue
        .toRadixString(
          16,
        )
        .padLeft(
          2,
          '0',
        );
    return '#$a$r$g$b'.toUpperCase();
  }

  Future<
    void
  >
  _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(
      () => _saving = true,
    );

    try {
      await _sb
          .from(
            'Category',
          )
          .insert(
            {
              'profile_id': widget.profileId,
              'name': _nameController.text.trim(),
              'type': 'Custom',
              'monthly_limit':
                  double.tryParse(
                    _limitController.text.trim(),
                  ) ??
                  0.0,
              'icon': _selectedIcon,
              'icon_color': _colorToHex(
                _selectedColor,
              ),
              'is_archived': false,
            },
          );
      if (!mounted) return;
      Navigator.pop(
        context,
        true,
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error adding category: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add category: $e',
          ),
        ),
      );
    } finally {
      if (mounted)
        setState(
          () => _saving = false,
        );
    }
  }

  Widget _buildLabel(
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          color: _kText,
          fontSize: 14,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: _kTextSoft,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE9DDFC,
          ),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE9DDFC,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          18,
        ),
        borderSide: const BorderSide(
          color: _kPurple,
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F4FF,
      ),
      appBar: AppBar(
        backgroundColor: const Color(
          0xFFF8F4FF,
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: _kText,
        ),
        title: const Text(
          'Add Category',
          style: TextStyle(
            fontFamily: 'Fredoka One',
            color: _kText,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(
                  'Category Name',
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(
                    'Enter category name',
                  ),
                  validator:
                      (
                        value,
                      ) {
                        if (value ==
                                null ||
                            value.trim().isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                ),
                const SizedBox(
                  height: 18,
                ),
                _buildLabel(
                  'Monthly Limit',
                ),
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    'Enter monthly limit',
                  ),
                  validator:
                      (
                        value,
                      ) {
                        if (value ==
                                null ||
                            value.trim().isEmpty) {
                          return 'Please enter a monthly limit';
                        }
                        if (double.tryParse(
                              value.trim(),
                            ) ==
                            null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                ),
                const SizedBox(
                  height: 18,
                ),
                _buildLabel(
                  'Choose an Icon',
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _iconOptions.map(
                    (
                      item,
                    ) {
                      final isSelected =
                          _selectedIcon ==
                          item['icon'];
                      return GestureDetector(
                        onTap: () {
                          setState(
                            () => _selectedIcon = item['icon']!,
                          );
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                    0xFFEDE9FE,
                                  )
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? _kPurple
                                  : const Color(
                                      0xFFE9DDFC,
                                    ),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item['emoji']!,
                            style: const TextStyle(
                              fontSize: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(
                  height: 18,
                ),
                _buildLabel(
                  'Choose a Color',
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorOptions.map(
                    (
                      color,
                    ) {
                      final isSelected =
                          _selectedColor.value ==
                          color.value;
                      return GestureDetector(
                        onTap: () {
                          setState(
                            () => _selectedColor = color,
                          );
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? _kText
                                  : Colors.white,
                              width: isSelected
                                  ? 3
                                  : 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    },
                  ).toList(),
                ),
                const SizedBox(
                  height: 28,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      disabledBackgroundColor: _kPurple.withOpacity(
                        0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          18,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Category',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
