// lib/screens/profile_main.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/curved_dark_section.dart';
import '../widgets/bottom_nav_bar.dart';
import 'spending_insight.dart';

class ProfileMainPage extends StatelessWidget {
  const ProfileMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          // Gradient background
          const TopGradient(height: 450),

          // Content on top of gradient
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Welcome Layan',
                        style: TextStyle(
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
                    child: const Column(
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: Color(0xFFD9D9D9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '7,783.00 SAR',
                          style: TextStyle(
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
                      Expanded(child: _mini('Expense', '2,560.00 SAR', true)),
                      const SizedBox(width: 16),
                      Expanded(child: _mini('Income', '2,560.00 SAR', false)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Dark section with categories
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

                  // Grid (3 columns, scrollable)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                      children: const [
                        _CategoryCard('Transportation', '6012.00 SAR', '31%'),
                        _CategoryCard(
                          'Utilities & Bills',
                          '6012.00 SAR',
                          '31%',
                        ),
                        _EmptyCategoryCard(),
                        _EmptyCategoryCard(),
                        _EmptyCategoryCard(),
                        _EmptyCategoryCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () => Navigator.pushNamed(context, '/savings'),
        onTapProfile: () {}, // already on profile
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

// ======= Cards =======

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
          // Icon placeholder - you can add your icon here
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
