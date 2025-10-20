import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/bottom_nav_bar.dart';

class SpendingInsightPage extends StatefulWidget {
  const SpendingInsightPage({super.key});

  @override
  State<SpendingInsightPage> createState() => _SpendingInsightPageState();
}

class _SpendingInsightPageState extends State<SpendingInsightPage> {
  static const String kProfileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
  final _sb = Supabase.instance.client;

  late Future<_SpendingData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSpendingData(kProfileId);
  }

  // ======= FETCH DATA =======
  Future<_SpendingData> _fetchSpendingData(String profileId) async {
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

      // 1) Get current balance from User_Profile
      final profile = await _sb
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', profileId)
          .maybeSingle();

      final currentBalance = _toDouble(profile?['current_balance']) ?? 0.0;

      // 2) Get active monthly record
      final monthlyRecord = await _sb
          .from('Monthly_Financial_Record')
          .select('record_id, period_start, period_end')
          .eq('profile_id', profileId)
          .lte('period_start', todayIso)
          .gte('period_end', todayIso)
          .maybeSingle();

      String? recordId = monthlyRecord?['record_id'] as String?;

      // 3) Get all categories with their limits
      final categories = await _sb
          .from('Category')
          .select('category_id, name, monthly_limit, icon, icon_color')
          .eq('profile_id', profileId)
          .eq('is_archived', false)
          .order('name');

      // 4) Get category summaries for the active monthly record
      List<Map<String, dynamic>> categorySummaries = [];
      if (recordId != null) {
        final summaries = await _sb
            .from('Category_Summary')
            .select('category_id, total_expense')
            .eq('record_id', recordId);

        categorySummaries = (summaries as List).cast<Map<String, dynamic>>();
      }

      // 5) Calculate combined data
      double totalMonthlyBudget = 0.0;
      double totalSpent = 0.0;
      final categoryData = <_CategorySpending>[];

      for (final category in categories) {
        final categoryId = category['category_id'] as String;
        final name = category['name'] as String? ?? 'Category';
        final limit = _toDouble(category['monthly_limit']);
        final icon = category['icon'] as String? ?? 'category';
        final color = category['icon_color'] as String? ?? '#7D5EF6';

        // Find spending for this category
        double spent = 0.0;
        final summary = categorySummaries.firstWhere(
          (s) => s['category_id'] == categoryId,
          orElse: () => <String, dynamic>{},
        );
        if (summary.isNotEmpty) {
          spent = _toDouble(summary['total_expense']) ?? 0.0;
        }

        totalMonthlyBudget += limit ?? 0.0;
        totalSpent += spent;

        categoryData.add(
          _CategorySpending(
            name: name,
            limit: limit,
            spent: spent,
            icon: icon,
            color: color,
          ),
        );
      }

      final leftToSpend = totalMonthlyBudget - totalSpent;

      return _SpendingData(
        currentBalance: currentBalance,
        monthYear: '${_getMonthName(now.month)} ${now.year}',
        totalMonthlyBudget: totalMonthlyBudget,
        totalSpent: totalSpent,
        leftToSpend: leftToSpend > 0 ? leftToSpend : 0.0,
        categories: categoryData,
      );
    } catch (e) {
      print('Error fetching spending data: $e');
      return _SpendingData(
        currentBalance: 0.0,
        monthYear: 'Error',
        totalMonthlyBudget: 0.0,
        totalSpent: 0.0,
        leftToSpend: 0.0,
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

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

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

  String _fmt(double v) => v.toStringAsFixed(0);

  // ======= UI =======
  @override
  Widget build(BuildContext context) {
    final double bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: FutureBuilder<_SpendingData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load spending insights\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          final data = snap.data!;

          return CustomScrollView(
            slivers: [
              // Gradient + top bar
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    const TopGradient(height: 220),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            const Text(
                              'Category Spending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dark section content
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          data.monthYear,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '${_fmt(data.currentBalance)} ر.س',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ===== Top full progress card (multicolor) =====
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Left to spend',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Monthly budget',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_fmt(data.leftToSpend)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_fmt(data.totalMonthlyBudget)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (data.totalMonthlyBudget > 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 9,
                                  child: _buildCombinedProgressBar(
                                    data.categories,
                                    data.totalMonthlyBudget,
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 9,
                                decoration: BoxDecoration(
                                  color: AppColors.pNeutral,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== Per-category cards with progress =====
                      ...data.categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _categoryRow(category),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () => Navigator.pushNamed(context, '/savings'),
      ),
    );
  }

  Widget _buildCombinedProgressBar(
    List<_CategorySpending> categories,
    double totalBudget,
  ) {
    final validCategories = categories
        .where((c) => c.limit != null && c.limit! > 0 && c.spent > 0)
        .toList();

    if (validCategories.isEmpty) {
      return Container(
        height: 9,
        decoration: BoxDecoration(
          color: AppColors.pNeutral,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Row(
      children: [
        for (final category in validCategories)
          if (category.spent > 0)
            Expanded(
              flex: (category.spent / totalBudget * 1000).round(),
              child: ColoredBox(color: _hexToColor(category.color)),
            ),
        // Remaining space (left to spend)
        Expanded(
          flex:
              ((totalBudget -
                          validCategories.fold(
                            0.0,
                            (sum, c) => sum + c.spent,
                          )) /
                      totalBudget *
                      1000)
                  .round(),
          child: const ColoredBox(color: AppColors.pNeutral),
        ),
      ],
    );
  }

  Widget _categoryRow(_CategorySpending category) {
    final limit = category.limit ?? 0.0;
    final spent = category.spent;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final leftToSpend = limit - spent;
    final color = _hexToColor(category.color);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Category icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _getIconFromString(category.icon),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Limit: ${_fmt(limit)} ر.س',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_fmt(spent)} ر.س',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: color,
                    backgroundColor: AppColors.pNeutral,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Left ${_fmt(leftToSpend > 0 ? leftToSpend : 0)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======= MODEL CLASSES =======
class _SpendingData {
  final double currentBalance;
  final String monthYear;
  final double totalMonthlyBudget;
  final double totalSpent;
  final double leftToSpend;
  final List<_CategorySpending> categories;

  _SpendingData({
    required this.currentBalance,
    required this.monthYear,
    required this.totalMonthlyBudget,
    required this.totalSpent,
    required this.leftToSpend,
    required this.categories,
  });
}

class _CategorySpending {
  final String name;
  final double? limit;
  final double spent;
  final String icon;
  final String color;

  _CategorySpending({
    required this.name,
    required this.limit,
    required this.spent,
    required this.icon,
    required this.color,
  });
}
