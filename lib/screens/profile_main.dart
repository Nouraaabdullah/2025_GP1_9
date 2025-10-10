// lib/screens/profile_main.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
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
          // We use a regular scroll view to avoid sliver hit-test issues.
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ======= Gradient + Header (same visuals) =======
                Stack(
                  children: [
                    const TopGradient(height: 380),
                    SafeArea(
                      child: Padding(
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
                                const Text(
                                  'Welcome Layan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/editProfile',
                                  ),
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
                                    '7,783.00 ر.س',
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
                                Expanded(
                                  child: _mini('Expense', '2,560.00 ر.س'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _mini('Income', '2,560.00 ر.س'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ======= Dark Section (lifted slightly; rounded) =======
                Transform.translate(
                  offset: const Offset(
                    0,
                    -64,
                  ), // keep the “close” look without sliver issues
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(48),
                        topRight: Radius.circular(48),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // ✅ Button guaranteed to work (direct push)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textGrey,
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
                                'View all',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Grid (2 filled + 2 empty like your mock)
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: const [
                            _CategoryCard(
                              'Transportation',
                              '6012.00 ر.س',
                              '31%',
                            ),
                            _CategoryCard(
                              'Utilities & Bills',
                              '6012.00 ر.س',
                              '31%',
                            ),
                            _EmptyCategoryCard(),
                            _EmptyCategoryCard(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // FAB (decorative)
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapProfile: () {}, // already on profile
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9D9D9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                percent,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
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
