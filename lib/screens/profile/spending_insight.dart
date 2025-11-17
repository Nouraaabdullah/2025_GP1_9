import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/utils/auth_helpers.dart'; // Import the utility

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

  // ======= GET PROFILE ID USING UTILITY FUNCTION =======
  Future<String> _getProfileId() async {
    final profileId = await getProfileId(context);
    if (profileId == null) {
      // The utility function already handles navigation to login
      throw Exception('User not authenticated');
    }
    return profileId;
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

      // 3) Get all categories with their limits AND icons
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
        final icon =
            category['icon'] as String? ??
            'IconData(U+0E1F0)'; // Default to category icon
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
            id: categoryId,
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

  // ======= ICON CONVERSION - FIXED VERSION =======
  IconData _parseIconData(String iconString) {
    try {
      print('Parsing icon string: $iconString'); // Debug log

      // Handle IconData(U+0E59C) format
      if (iconString.startsWith('IconData(U+')) {
        // Extract the hex code from "IconData(U+0E59C)"
        final hexCode = iconString.substring(11, iconString.length - 1);
        print('Extracted hex code: $hexCode'); // Debug log

        final codePoint = int.parse(hexCode, radix: 16);
        print('Parsed code point: $codePoint'); // Debug log

        return IconData(
          codePoint,
          fontFamily: 'MaterialIcons',
          matchTextDirection: false,
        );
      }

      // If it's already a simple string, try to map it
      return _stringToIconData(iconString);
    } catch (e) {
      print('Error parsing icon data: $e for string: $iconString');
      // Return a default icon
      return Icons.category;
    }
  }

  // Fallback for string icons
  IconData _stringToIconData(String iconName) {
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
      'category': Icons.category,
      'fastfood': Icons.fastfood,
      'shopping_bag': Icons.shopping_bag,
      'airplanemode_active': Icons.airplanemode_active,
      'sports_soccer': Icons.sports_soccer,
      'work': Icons.work,
      'brush': Icons.brush,
      'local_cafe': Icons.local_cafe,
      'computer': Icons.computer,
      'account_balance_wallet': Icons.account_balance_wallet,
    };

    // Clean the icon name in case it has prefixes
    var cleanName = iconName;
    if (iconName.contains('.')) {
      cleanName = iconName.split('.').last;
    }

    return iconMap[cleanName] ?? Icons.category;
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

          // Sort categories by spent amount (highest first) or by proximity to limit
          final sortedCategories = List<_CategorySpending>.from(data.categories)
            ..sort((a, b) {
              // First sort by spent amount (highest first)
              final spentComparison = b.spent.compareTo(a.spent);
              if (spentComparison != 0) return spentComparison;

              // If spent is equal, sort by proximity to limit (closest to limit first)
              if (a.limit != null && b.limit != null) {
                final aRatio = a.spent / a.limit!;
                final bRatio = b.spent / b.limit!;
                return bRatio.compareTo(aRatio);
              }

              return 0;
            });

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
                          '${_fmt(data.totalSpent)} SAR', // <-- use totalSpent
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== Category Spending Progress Title =====
                      Center(
                        child: Text(
                          'Category Spending Progress',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ===== Combined Progress Chart =====
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child:
                                      SizedBox(), // Empty space instead of title
                                ),
                                _InfoIconButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => _ChartInfoSheet(
                                        title: 'Category Spending Progress',
                                        text:
                                            'This chart shows your spending distribution across all categories. Each segment represents a different spending category, with the size proportional to the amount spent.',
                                      ),
                                    );
                                  },
                                ),
                              ],
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
                            // Budget warning message for combined chart
                            if (data.leftToSpend < 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'You are over budget by ${_fmt(data.leftToSpend.abs())} SAR',
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ===== Per-category cards with progress =====
                      ...sortedCategories.map(
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
      // FLOATING ACTION BUTTON REMOVED
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
      ],
    );
  }

  Widget _categoryRow(_CategorySpending category) {
    final limit = category.limit ?? 0.0;
    final spent = category.spent;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final leftToSpend = limit - spent;
    final color = colorFromIconOrSeed(
      categoryId: category.id,
      iconHex: category.color,
    );

    // Parse the icon
    final iconData = _parseIconData(category.icon);

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
              // Category icon using the parsed icon data
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  iconData, // Use the parsed IconData
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
            Column(
              children: [
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
                ),
                // Budget warning message for individual category
                if (leftToSpend < 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Over budget by ${_fmt(leftToSpend.abs())} SAR',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
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

// ======= PROGRESS BAR WITH HOVER =======
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

    if (totalBudget <= 0) return;

    // Calculate which segment is being hovered
    final segmentWidth = size.width / totalBudget;
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
          Offset(tipX - 60, -60), // Positioned higher above the chart
          '${category.name}\nSpent: ${category.spent.toStringAsFixed(0)} SAR',
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
      clipBehavior:
          Clip.none, // Important: Allow tooltip to show outside the container
      children: [
        // Progress bar segments
        Container(
          height: 20,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: GestureDetector(
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final local = box.globalToLocal(details.globalPosition);
                _handleHover(local, box.size);
              }
            },
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
        ),

        // Tooltip - positioned above the progress bar
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

// ======= INFO ICON BUTTON =======
class _InfoIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _InfoIconButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        splashColor: Colors.white24,
        child: Container(
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.info_outline,
            size: 20,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ======= CHART INFO SHEET =======
class _ChartInfoSheet extends StatelessWidget {
  final String title;
  final String text;
  const _ChartInfoSheet({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Tooltip bubble
class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

// ======= COLOR UTILITIES (from your dashboard) =======
Color colorFromIconOrSeed({required String categoryId, String? iconHex}) {
  final parsed = _parseHexColorLoose(iconHex);
  return parsed ?? _seededCategoryColor(categoryId);
}

Color? _parseHexColorLoose(String? s) {
  if (s == null) return null;
  var t = s.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.length == 6) t = 'FF$t';
  if (t.length != 8) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(v);
}

Color _seededCategoryColor(String categoryId) {
  final rnd = math.Random(categoryId.hashCode);
  final hue = rnd.nextDouble() * 360.0;
  final sat = 0.65 + rnd.nextDouble() * 0.25;
  final val = 0.75 + rnd.nextDouble() * 0.20;
  return HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
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
  final String id;
  final String name;
  final double? limit;
  final double spent;
  final String icon;
  final String color;

  _CategorySpending({
    required this.id,
    required this.name,
    required this.limit,
    required this.spent,
    required this.icon,
    required this.color,
  });
}
