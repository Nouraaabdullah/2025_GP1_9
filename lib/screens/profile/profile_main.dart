import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/curved_dark_section.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/screens/profile/spending_insight.dart';
import 'package:surra_application/screens/profile/edit_profile/edit_profile.dart';
import 'package:surra_application/utils/auth_helpers.dart';

class ProfileMainPage extends StatefulWidget {
  const ProfileMainPage({super.key});

  @override
  State<ProfileMainPage> createState() => _ProfileMainPageState();
}

class _ProfileMainPageState extends State<ProfileMainPage> {
  final _sb = Supabase.instance.client;
  late Future<_DashboardData> _future;
  bool _isRefreshing = false;

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

  Future<String> _getProfileId() async {
    final profileId = await getProfileId(context);
    if (profileId == null) {
      throw Exception('User not authenticated');
    }
    return profileId;
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final newData = await _fetchDashboard();
      setState(() {
        _future = Future.value(newData);
      });
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await _sb.auth.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  Future<_DashboardData> _fetchDashboard() async {
    try {
      final profileId = await _getProfileId();

      String _isoDate(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final todayIso = _isoDate(now);
      final firstIso = _isoDate(firstOfMonth);

      // 1) PROFILE INFO
      final prof = await _sb
          .from('User_Profile')
          .select('full_name,current_balance')
          .eq('profile_id', profileId)
          .maybeSingle();

      final fullName = (prof?['full_name'] as String?) ?? 'User';
      final currentBalance = _toDouble(prof?['current_balance']) ?? 0.0;

      // 2) MONTHLY FINANCIAL RECORD (earnings from total_earning)
      final monthlyRecord = await _sb
          .from('Monthly_Financial_Record')
          .select('total_income, total_expense, total_earning')
          .eq('profile_id', profileId)
          .lte('period_start', todayIso)
          .gte('period_end', todayIso)
          .maybeSingle();

      double totalIncome = _toDouble(monthlyRecord?['total_income']) ?? 0.0;
      double totalExpense = _toDouble(monthlyRecord?['total_expense']) ?? 0.0;
      double totalEarnings = _toDouble(monthlyRecord?['total_earning']) ?? 0.0;

      // Fallback if no active monthly record: compute from transactions
      if (monthlyRecord == null) {
        final expenses = await _sb
            .from('Transaction')
            .select('amount,date,type')
            .eq('profile_id', profileId)
            .eq('type', 'Expense')
            .gte('date', firstIso)
            .lte('date', todayIso);

        final incomes = await _sb
            .from('Transaction')
            .select('amount,date,type')
            .eq('profile_id', profileId)
            .eq('type', 'Earning')
            .gte('date', firstIso)
            .lte('date', todayIso);

        totalExpense = 0.0;
        for (final r in expenses) {
          totalExpense += _toDouble(r['amount']) ?? 0.0;
        }

        totalIncome = 0.0;
        for (final r in incomes) {
          totalIncome += _toDouble(r['amount']) ?? 0.0;
        }
      }

      // 3) CATEGORIES
      final cats = await _sb
          .from('Category')
          .select('category_id,name,monthly_limit,icon,icon_color')
          .eq('profile_id', profileId)
          .eq('is_archived', false)
          .order('name');

      final trxThisMonth = await _sb
          .from('Transaction')
          .select('category_id,amount,type,date')
          .eq('profile_id', profileId)
          .eq('type', 'Expense')
          .gte('date', firstIso)
          .lte('date', todayIso);

      final Map<String, double> totalByCat = {};
      for (final t in trxThisMonth) {
        final cid = t['category_id'] as String?;
        if (cid == null) continue;
        final amount = _toDouble(t['amount']) ?? 0.0;
        totalByCat[cid] = (totalByCat[cid] ?? 0) + amount;
      }

      final items = <_CategoryDash>[];
      for (final c in cats) {
        final id = c['category_id'] as String;
        final name = (c['name'] as String?) ?? 'Category';
        final limit = _toDouble(c['monthly_limit']);
        final spent = totalByCat[id] ?? 0.0;

        final pct = (limit != null && limit > 0)
            ? ((spent / limit) * 100.0).clamp(0.0, 100.0)
            : null;

        final icon = c['icon'] as String? ?? 'category';
        final color = c['icon_color'] as String? ?? '#7D5EF6';

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

      return _DashboardData(
        fullName: fullName,
        currentBalance: currentBalance,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        totalEarnings: totalEarnings,
        categories: items,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      return _DashboardData(
        fullName: 'User',
        currentBalance: 0.0,
        totalIncome: 0.0,
        totalExpense: 0.0,
        totalEarnings: 0.0,
        categories: const [],
      );
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v.isEmpty) return 0.0;
      return double.tryParse(v) ?? 0.0;
    }
    return 0.0;
  }

  // Show two decimals everywhere for currency values
  String _fmt2(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final double bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load profile\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Logout & Sign In Again'),
                    ),
                  ],
                ),
              );
            }
            final data = snap.data!;

            return Stack(
              children: [
                const TopGradient(height: 450),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
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
                                    padding: EdgeInsets.only(right: 8),
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
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const EditProfilePage(),
                                    ),
                                  ).then((_) => _refreshData()),
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
                        const SizedBox(height: 12),

                        // Total Balance
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Color(0xFFD9D9D9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_fmt2(data.currentBalance)} SAR',
                                style: const TextStyle(
                                  color: Color(0xFFD9D9D9),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Expense / Income / Earnings
                        Row(
                          children: [
                            Expanded(
                              child: _mini(
                                'Expense',
                                '${_fmt2(data.totalExpense)} SAR',
                                Icons.arrow_downward,
                                const Color(0xFFFF6B9D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _mini(
                                'Income',
                                '${_fmt2(data.totalIncome)} SAR',
                                Icons.arrow_upward,
                                const Color(0xFF4ECDC4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _mini(
                                'Earnings',
                                '${_fmt2(data.totalEarnings)} SAR',
                                Icons.arrow_upward,
                                const Color(0xFFFFD93D),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Categories section
                CurvedDarkSection(
                  top: 340,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPad),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.1,
                                ),
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
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SpendingInsightPage(),
                                      ),
                                    )
                                    .then((_) => _refreshData());
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
                        const SizedBox(height: 12),

                        Expanded(
                          child: (data.categories.isEmpty)
                              ? GridView.count(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                  children: const [
                                    _EmptyCategoryCard(),
                                    _EmptyCategoryCard(),
                                    _EmptyCategoryCard(),
                                  ],
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                  itemCount: data.categories.length,
                                  itemBuilder: (context, i) {
                                    final c = data.categories[i];
                                    final pct = c.percent == null
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
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () => Navigator.pushNamed(context, '/savings'),
        onTapProfile: () {},
      ),
    );
  }

  Widget _mini(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD9D9D9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  final String fullName;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final double totalEarnings;
  final List<_CategoryDash> categories;
  _DashboardData({
    required this.fullName,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalEarnings,
    required this.categories,
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

class _CategoryCard extends StatelessWidget {
  final String title, amount, percent, icon, color;
  const _CategoryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.percent,
    required this.icon,
    required this.color,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  IconData _iconDataFromString(String iconString) {
    try {
      if (iconString.startsWith('IconData(U+')) {
        final hexCode = iconString.substring(11, iconString.length - 1);
        final codePoint = int.parse(hexCode, radix: 16);
        return IconData(codePoint, fontFamily: 'MaterialIcons');
      }
      return _stringToIconData(iconString);
    } catch (e) {
      debugPrint('Error converting icon string: $iconString, error: $e');
      return Icons.category;
    }
  }

  IconData _stringToIconData(String iconString) {
    try {
      if (iconString.contains('.')) {
        final iconName = iconString.split('.').last;
        return _findIconByName(iconName);
      } else {
        return _findIconByName(iconString);
      }
    } catch (e) {
      debugPrint('Error converting string to IconData: $e');
      return Icons.category;
    }
  }

  IconData _findIconByName(String iconName) {
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
    return iconMap[iconName] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _hexToColor(color);
    final iconData = _iconDataFromString(icon);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),

          const SizedBox(height: 6),

          // Title
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

          const SizedBox(height: 4),

          // Amount (2 decimals)
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

          const SizedBox(height: 6),

          // Percent badge (kept integer to reduce overflow risk)
          const _PercentBadgeSpacer(),
          _PercentBadge(
            text: percent == '—' ? 'No limit set' : '$percent budget used',
          ),
          const _PercentBadgeSpacer(height: 2),
        ],
      ),
    );
  }
}

class _PercentBadgeSpacer extends StatelessWidget {
  final double height;
  const _PercentBadgeSpacer({this.height = 0});
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class _PercentBadge extends StatelessWidget {
  final String text;
  const _PercentBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
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

class _EmptyCategoryCard extends StatelessWidget {
  const _EmptyCategoryCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
