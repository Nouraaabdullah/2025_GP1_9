import 'dart:async';
import 'dart:math' as math;
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
  final _sb = Supabase.instance.client;
  late Future<_SpendingData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSpendingData();
  }

  // ======= GET PROFILE ID =======
  Future<String> _getProfileId() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    final row = await _sb
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', uid)
        .single();
    return row['profile_id'] as String;
  }

  // ======= FETCH DATA =======
  Future<_SpendingData> _fetchSpendingData() async {
    try {
      final profileId = await _getProfileId();

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load spending insights\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _future = _fetchSpendingData();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
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
                          '${_fmt(data.currentBalance)} SAR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ===== Category Spending Progress Chart =====
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category Spending Progress',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                    '${_fmt(data.leftToSpend)} SAR',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_fmt(data.totalMonthlyBudget)} SAR',
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
                              _buildInteractiveProgressBar(
                                data.categories,
                                data.totalMonthlyBudget,
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

  Widget _buildInteractiveProgressBar(
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

    return Column(
      children: [
        // Progress bar with hover detection
        SizedBox(
          height: 20,
          child: _ProgressBarWithHover(
            categories: validCategories,
            totalBudget: totalBudget,
          ),
        ),
        const SizedBox(height: 8),
        // Legend for categories
        _buildProgressBarLegend(validCategories),
      ],
    );
  }

  Widget _buildProgressBarLegend(List<_CategorySpending> categories) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: categories.map((category) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _hexToColor(category.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              category.name,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        );
      }).toList(),
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
                    if (limit > 0)
                      Text(
                        'Limit: ${_fmt(limit)} SAR',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      )
                    else
                      Text(
                        'No limit set',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'Spent ${_fmt(spent)} SAR',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (limit > 0)
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
                  'Left ${_fmt(leftToSpend > 0 ? leftToSpend : 0)} SAR',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Spent ${_fmt(spent)} SAR in this category',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// ======= HOVER-BASED PROGRESS BAR =======
class _ProgressBarWithHover extends StatefulWidget {
  final List<_CategorySpending> categories;
  final double totalBudget;

  const _ProgressBarWithHover({
    required this.categories,
    required this.totalBudget,
  });

  @override
  State<_ProgressBarWithHover> createState() => _ProgressBarWithHoverState();
}

class _ProgressBarWithHoverState extends State<_ProgressBarWithHover> {
  Offset? _tipPos;
  String _tipText = '';
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  // Add _hexToColor method here to fix the red error
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _showTip(Offset local, String text) {
    _hideTimer?.cancel();
    setState(() {
      _tipPos = local;
      _tipText = text;
    });
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _tipPos = null);
    });
  }

  void _handleHover(Offset localPos, Size size) {
    final categories = widget.categories;
    final totalBudget = widget.totalBudget;

    // Calculate which segment is being hovered
    final segmentWidth = size.width / (totalBudget > 0 ? totalBudget : 1);
    double currentPosition = 0.0;

    for (final category in categories) {
      final segmentEnd = currentPosition + category.spent;

      if (localPos.dx >= currentPosition * segmentWidth &&
          localPos.dx <= segmentEnd * segmentWidth) {
        final tipX =
            (currentPosition * segmentWidth +
                    (category.spent * segmentWidth) / 2)
                .clamp(60.0, size.width - 60.0);

        _showTip(
          Offset(tipX - 60, -50), // Position above the segment
          '${category.name}\nSpent: ${category.spent.toStringAsFixed(0)}/${category.limit!.toStringAsFixed(0)} SAR',
        );
        return;
      }
      currentPosition = segmentEnd;
    }

    // If no segment found, hide tooltip
    _hideTimer?.cancel();
    setState(() => _tipPos = null);
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final totalBudget = widget.totalBudget;

    return Stack(
      children: [
        // Progress bar segments
        Container(
          height: 20,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: MouseRegion(
            onHover: (event) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final local = box.globalToLocal(event.position);
                _handleHover(local, box.size);
              }
            },
            onExit: (event) {
              _hideTimer?.cancel();
              setState(() => _tipPos = null);
            },
            child: Row(
              children: [
                for (final category in categories)
                  if (category.spent > 0)
                    Expanded(
                      flex: (category.spent / totalBudget * 1000).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _hexToColor(category.color),
                          borderRadius: _getSegmentBorderRadius(
                            category,
                            categories,
                            totalBudget,
                          ),
                        ),
                      ),
                    ),
                // Remaining space (left to spend)
                Expanded(
                  flex:
                      ((totalBudget -
                                  categories.fold(
                                    0.0,
                                    (sum, c) => sum + c.spent,
                                  )) /
                              totalBudget *
                              1000)
                          .round(),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.pNeutral,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tooltip
        if (_tipPos != null)
          Positioned(
            left: _tipPos!.dx,
            top: _tipPos!.dy,
            child: _Bubble(text: _tipText),
          ),
      ],
    );
  }

  BorderRadius _getSegmentBorderRadius(
    _CategorySpending category,
    List<_CategorySpending> categories,
    double totalBudget,
  ) {
    final index = categories.indexOf(category);
    final isFirst = index == 0;
    final isLast =
        index == categories.length - 1 &&
        (totalBudget - categories.fold(0.0, (sum, c) => sum + c.spent)) <= 0;

    return BorderRadius.only(
      topLeft: isFirst ? const Radius.circular(8) : Radius.zero,
      bottomLeft: isFirst ? const Radius.circular(8) : Radius.zero,
      topRight: isLast ? const Radius.circular(8) : Radius.zero,
      bottomRight: isLast ? const Radius.circular(8) : Radius.zero,
    );
  }
}

// Tooltip bubble (same as your dashboard)
class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
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
