import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/curved_dark_section.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/screens/spending_insight.dart';

class ProfileMainPage extends StatefulWidget {
  const ProfileMainPage({super.key});

  @override
  State<ProfileMainPage> createState() => _ProfileMainPageState();
}

class _ProfileMainPageState extends State<ProfileMainPage> {
  static const String kProfileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
  final _sb = Supabase.instance.client;

  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchDashboard(kProfileId);
  }

  // ======= FETCH DATA =======
  Future<_DashboardData> _fetchDashboard(String profileId) async {
    // --- helper for date formatting
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
    final currentBalance = _toDouble(prof?['current_balance']);

    // 2) LIVE INCOME — sum of active Fixed_Income
    final incomes = await _sb
        .from('Fixed_Income')
        .select('monthly_income,start_time,end_time')
        .eq('profile_id', profileId)
        .lte('start_time', todayIso)
        .or('end_time.is.null,end_time.gte.$todayIso');

    double totalIncome = 0.0;
    for (final r in incomes) {
      totalIncome += _toDouble(r['monthly_income']);
    }

    // 3) LIVE EXPENSE — sum of Transaction for current month
    final expenses = await _sb
        .from('Transaction')
        .select('amount,date,type')
        .eq('profile_id', profileId)
        .eq(
          'type',
          'Expense',
        ) // change to 'Expense' if your enum is capitalized
        .gte('date', firstIso)
        .lte('date', todayIso);

    double totalExpense = 0.0;
    for (final r in expenses) {
      totalExpense += _toDouble(r['amount']);
    }

    // 4) CATEGORY CARDS — this month’s spending
    final cats = await _sb
        .from('Category')
        .select('category_id,name,monthly_limit,is_archived')
        .eq('profile_id', profileId)
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
      totalByCat[cid] = (totalByCat[cid] ?? 0) + _toDouble(t['amount']);
    }

    final items = <_CategoryDash>[];
    for (final c in cats) {
      if (c['is_archived'] == true) continue;
      final id = c['category_id'] as String;
      final name = (c['name'] as String?) ?? 'Category';
      final limitRaw = c['monthly_limit'];
      final limit = (limitRaw == null) ? null : _toDouble(limitRaw);
      final spent = totalByCat[id] ?? 0.0;
      final pct = (limit != null && limit > 0) ? (spent / limit) * 100.0 : null;
      items.add(_CategoryDash(name: name, amount: spent, percent: pct));
    }

    return _DashboardData(
      fullName: fullName,
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      categories: items,
    );
  }

  // ======= HELPERS =======
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
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
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load profile\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
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
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/editProfile'),
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

                      // Expense / Income
                      Row(
                        children: [
                          Expanded(
                            child: _mini(
                              'Expense',
                              '${_fmt(data.totalExpense)} SAR',
                              true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _mini(
                              'Income',
                              '${_fmt(data.totalIncome)} SAR',
                              false,
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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SpendingInsightPage(),
                                ),
                              );
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

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () => Navigator.pushNamed(context, '/savings'),
        onTapProfile: () {},
      ),
    );
  }

  Widget _mini(String label, String value, bool isExpense) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                color: isExpense
                    ? const Color(0xFFFF6B9D)
                    : const Color(0xFF4ECDC4),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Color(0xFFD9D9D9), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ======= MODEL CLASSES =======
class _DashboardData {
  final String fullName;
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final List<_CategoryDash> categories;
  _DashboardData({
    required this.fullName,
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.categories,
  });
}

class _CategoryDash {
  final String name;
  final double amount;
  final double? percent;
  _CategoryDash({
    required this.name,
    required this.amount,
    required this.percent,
  });
}

// ======= CATEGORY CARDS =======
class _CategoryCard extends StatelessWidget {
  final String title, amount, percent;
  const _CategoryCard(this.title, this.amount, this.percent);

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
          Icon(
            _getIconForCategory(title),
            color: _getColorForCategory(title),
            size: 32,
          ),
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
              '$percent budget used',
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

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'transportation':
        return Icons.directions_car;
      case 'utilities & bills':
        return Icons.receipt_long;
      default:
        return Icons.category;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'transportation':
        return const Color(0xFF9B7EDE);
      case 'utilities & bills':
        return const Color(0xFFFF8A65);
      default:
        return AppColors.textGrey;
    }
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
