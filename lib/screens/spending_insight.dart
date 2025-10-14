import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/bottom_nav_bar.dart';

class SpendingInsightPage extends StatelessWidget {
  const SpendingInsightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 24;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: CustomScrollView(
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
                  const Center(
                    child: Text(
                      'September 2020',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      '1,812 ر.س',
                      style: TextStyle(
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
                          children: const [
                            Expanded(
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Expanded(
                              child: Text(
                                '738',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '2,550',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 9,
                            child: Row(
                              children: const [
                                // match the mock: red → cyan → purple → neutral remainder
                                Expanded(
                                  flex: 48,
                                  child: ColoredBox(color: AppColors.pRed),
                                ),
                                Expanded(
                                  flex: 55,
                                  child: ColoredBox(color: AppColors.pCyan),
                                ),
                                Expanded(
                                  flex: 120,
                                  child: ColoredBox(color: AppColors.pPurple),
                                ),
                                Expanded(
                                  flex: 90,
                                  child: ColoredBox(color: AppColors.pNeutral),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== Per-category cards with progress =====
                  _categoryRow(
                    color: AppColors.pPurple,
                    iconBg: const Color(0xFF6A43DD),
                    title: ' transportation',
                    value: '700',
                    leftText: 'Left 186',
                    progress: 0.63,
                  ),
                  const SizedBox(height: 14),
                  _categoryRow(
                    color: AppColors.pRed,
                    iconBg: const Color(0xFFF4603F),
                    title: ' Bill & Utilities',
                    value: '250',
                    leftText: 'Left 34',
                    progress: 0.88,
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _categoryRow({
    required Color color,
    required Color iconBg,
    required String title,
    required String value,
    required String leftText,
    required double progress,
  }) {
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
              // faint circular icon pad like the mock
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 15),
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
                leftText,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
