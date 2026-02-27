import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';
import 'onboarding_balance_screen.dart';

class OnboardingCategoriesScreen extends StatefulWidget {
  final String childName;
  const OnboardingCategoriesScreen({super.key, required this.childName});

  @override
  State<OnboardingCategoriesScreen> createState() =>
      _OnboardingCategoriesScreenState();
}

class _OnboardingCategoriesScreenState extends State<OnboardingCategoriesScreen> {
  final _foodCtrl = TextEditingController();
  final _gamesCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();

  @override
  void dispose() {
    _foodCtrl.dispose(); _gamesCtrl.dispose(); _schoolCtrl.dispose();
    super.dispose();
  }

  void _next() {
    final food = double.tryParse(_foodCtrl.text) ?? 0;
    final games = double.tryParse(_gamesCtrl.text) ?? 0;
    final school = double.tryParse(_schoolCtrl.text) ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingBalanceScreen(
          childName: widget.childName,
          foodLimit: food,
          gamesLimit: games,
          schoolLimit: school,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),
          Column(
            children: [
              const SizedBox(height: 16),

              // Header
              Center(
                child: Column(
                  children: [
                    const KidBadge('Step 2 of 3 💸'),
                    const SizedBox(height: 12),
                    Text(
                      'Where do you\nspend money?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34, color: AppColors.kText, height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Set a monthly limit for each one — or skip it!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTextStyles.nunito,
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.kTextSoft, height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              KidProgressDots(total: 3, current: 2),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      KidCard(
                        child: Column(
                          children: [
                            // Food
                            _CategoryTile(
                              emoji: '🍔',
                              name: 'Food',
                              controller: _foodCtrl,
                              bgColor: AppColors.kYellow.withOpacity(0.15),
                              borderColor: AppColors.kYellow.withOpacity(0.45),
                            ),
                            const SizedBox(height: 12),

                            // Games
                            _CategoryTile(
                              emoji: '🎮',
                              name: 'Games',
                              controller: _gamesCtrl,
                              bgColor: AppColors.kPurple.withOpacity(0.12),
                              borderColor: AppColors.kPurple.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),

                            // School
                            _CategoryTile(
                              emoji: '📚',
                              name: 'School',
                              controller: _schoolCtrl,
                              bgColor: AppColors.kBlue.withOpacity(0.12),
                              borderColor: AppColors.kBlue.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      KidPrimaryButton(label: 'Next! →', onTap: _next),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String emoji, name;
  final TextEditingController controller;
  final Color bgColor, borderColor;

  const _CategoryTile({
    required this.emoji, required this.name,
    required this.controller,
    required this.bgColor, required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Text(emoji, style:  TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(
                name,
                style:  TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18, color: AppColors.kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Limit label
          const Text(
            '🪙  Monthly limit (SAR) — optional',
            style: TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 12, fontWeight: FontWeight.w800,
              color: AppColors.kTextSoft,
            ),
          ),
          const SizedBox(height: 6),

          // Input
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style:  TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.kText,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. 150',
              hintStyle:  TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13, color: Color(0xFFB8AED4),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.78),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.kPurple.withOpacity(0.18), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.kPurple.withOpacity(0.18), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.kPurple, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
