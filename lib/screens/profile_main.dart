import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/curved_dark_section.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/screens/spending_insight.dart';
import 'package:surra_application/screens/edit_profile.dart';

class ProfileMainPage extends StatefulWidget {
  const ProfileMainPage({super.key});

  @override
  State<ProfileMainPage> createState() => _ProfileMainPageState();
}

class _ProfileMainPageState extends State<ProfileMainPage> {
  static const String kProfileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
  final _sb = Supabase.instance.client;

  late Future<_DashboardData> _future;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchDashboard(kProfileId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this page
    _refreshData();
  }

  // ======= REFRESH DATA =======
  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final newData = await _fetchDashboard(kProfileId);
      setState(() {
        _future = Future.value(newData);
      });
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // ======= FETCH DATA =======
  Future<_DashboardData> _fetchDashboard(String profileId) async {
    try {
      // --- helper for date formatting
      String _isoDate(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final todayIso = _isoDate(now);
      final firstIso = _isoDate(firstOfMonth);

      // 1) PROFILE INFO - from User_Profile table
      final prof = await _sb
          .from('User_Profile')
          .select('full_name,current_balance')
          .eq('profile_id', profileId)
          .maybeSingle();

      final fullName = (prof?['full_name'] as String?) ?? 'User';
      final currentBalance = _toDouble(prof?['current_balance']) ?? 0.0;

      // 2) MONTHLY FINANCIAL RECORD - get active month record
      final monthlyRecord = await _sb
          .from('Monthly_Financial_Record')
          .select('total_income, total_expense, monthly_saving')
          .eq('profile_id', profileId)
          .lte('period_start', todayIso)
          .gte('period_end', todayIso)
          .maybeSingle();

      double totalIncome = _toDouble(monthlyRecord?['total_income']) ?? 0.0;
      double totalExpense = _toDouble(monthlyRecord?['total_expense']) ?? 0.0;
      double monthlySaving = _toDouble(monthlyRecord?['monthly_saving']) ?? 0.0;

      // If no active monthly record found, use fallback calculation
      if (monthlyRecord == null) {
        print('No active monthly record found, using transaction fallback');

        // Fallback: Calculate from transactions for current month
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

        monthlySaving = totalIncome - totalExpense;
      }

      // 3) CATEGORY CARDS - get all categories
      final cats = await _sb
          .from('Category')
          .select('category_id,name,monthly_limit,icon,icon_color')
          .eq('profile_id', profileId)
          .eq('is_archived', false)
          .order('name');

      // Get transactions for this month to calculate category spending
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
        final limitRaw = c['monthly_limit'];
        final limit = _toDouble(limitRaw);
        final spent = totalByCat[id] ?? 0.0;
        final pct = (limit != null && limit > 0)
            ? (spent / limit) * 100.0
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
        monthlySaving: monthlySaving,
        categories: items,
      );
    } catch (e) {
      print('Error fetching dashboard data: $e');
      // Return default data in case of error
      return _DashboardData(
        fullName: 'User',
        currentBalance: 0.0,
        totalIncome: 0.0,
        totalExpense: 0.0,
        monthlySaving: 0.0,
        categories: [],
      );
    }
  }

  // ======= HELPERS =======
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v.isEmpty) return null;
      return double.tryParse(v);
    }
    return null;
  }

  String _fmt(double v) => v.toStringAsFixed(0);

  // ======= UI =======
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
                            Text(
                              'Welcome ${data.fullName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
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
                                  onPressed: () =>
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EditProfilePage(),
                                        ),
                                      ).then((_) {
                                        // Refresh data when returning from edit page
                                        _refreshData();
                                      }),
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
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_fmt(data.currentBalance)} SAR',
                                style: const TextStyle(
                                  color: Color(0xFFD9D9D9),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Expense / Income / Savings
                        Row(
                          children: [
                            Expanded(
                              child: _mini(
                                'Expense',
                                '${_fmt(data.totalExpense)} SAR',
                                true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _mini(
                                'Income',
                                '${_fmt(data.totalIncome)} SAR',
                                false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _mini(
                                'Savings',
                                '${_fmt(data.monthlySaving)} SAR',
                                data.monthlySaving >= 0,
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
                                    .then((_) {
                                      // Refresh data when returning from insights page
                                      _refreshData();
                                    });
                              },
                              child: const Text(
                                'View Details',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
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
                                  childAspectRatio: 0.9,
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
                                        childAspectRatio: 0.9,
                                      ),
                                  itemCount: data.categories.length,
                                  itemBuilder: (context, i) {
                                    final c = data.categories[i];
                                    final pct = c.percent == null
                                        ? '—'
                                        : '${c.percent!.clamp(0, 999).toStringAsFixed(0)}%';
                                    return _CategoryCard(
                                      c.name,
                                      '${_fmt(c.amount)} SAR',
                                      pct,
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

  Widget _mini(String label, String value, bool isPositive) {
    Color iconColor;
    if (label == 'Expense') {
      iconColor = const Color(0xFFFF6B9D);
    } else if (label == 'Income') {
      iconColor = const Color(0xFF4ECDC4);
    } else {
      iconColor = isPositive
          ? const Color(0xFF4ECDC4)
          : const Color(0xFFFF6B9D);
    }

    IconData icon;
    if (label == 'Expense') {
      icon = Icons.arrow_downward;
    } else if (label == 'Income') {
      icon = Icons.arrow_upward;
    } else {
      icon = isPositive ? Icons.trending_up : Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD9D9D9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ... (Keep the same model classes and category cards from previous code)
class _DashboardData {
  final String fullName;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final double monthlySaving;
  final List<_CategoryDash> categories;
  _DashboardData({
    required this.fullName,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthlySaving,
    required this.categories,
  });
}

class _CategoryDash {
  final String name;
  final double amount;
  final double? percent;
  final String icon;
  final String color;
  _CategoryDash({
    required this.name,
    required this.amount,
    required this.percent,
    required this.icon,
    required this.color,
  });
}

class _CategoryCard extends StatelessWidget {
  final String title, amount, percent, icon, color;
  const _CategoryCard(
    this.title,
    this.amount,
    this.percent, {
    required this.icon,
    required this.color,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  IconData _getIconFromString(String iconName) {
    final iconMap = {
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'home': Icons.home,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'sports_esports': Icons.sports_esports,
      'attach_money': Icons.attach_money,
      'savings': Icons.savings,
      'flight': Icons.flight,
      'fitness_center': Icons.fitness_center,
      'movie': Icons.movie,
      'music_note': Icons.music_note,
      'book': Icons.book,
      'pets': Icons.pets,
      'receipt': Icons.receipt,
    };
    return iconMap[iconName] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_getIconFromString(icon), color: _hexToColor(color), size: 32),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              percent == '—' ? 'No limit set' : '$percent budget used',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
