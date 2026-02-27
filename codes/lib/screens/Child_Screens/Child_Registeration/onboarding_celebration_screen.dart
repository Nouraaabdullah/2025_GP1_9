import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';

class OnboardingCelebrationScreen extends StatefulWidget {
  final String childName;
  const OnboardingCelebrationScreen({super.key, required this.childName});

  @override
  State<OnboardingCelebrationScreen> createState() =>
      _OnboardingCelebrationScreenState();
}

class _OnboardingCelebrationScreenState extends State<OnboardingCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _popCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _popAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _popCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
   _popAnim = CurvedAnimation(
  parent: _popCtrl,
  curve: Curves.elasticOut,
);
    _floatCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _popCtrl.forward();
    });
  }

  @override
  void dispose() { _popCtrl.dispose(); _floatCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.childName.split(' ').first;

    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pop-in celebration emoji
                  ScaleTransition(
                    scale: _popAnim,
                    child: AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: const Text('🎊', style: TextStyle(fontSize: 80)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 32, color: AppColors.kText, height: 1.2,
                      ),
                      children: [
                        const TextSpan(text: "You're all set,\n"),
                        TextSpan(
                          text: firstName,
                          style:  TextStyle(color: AppColors.kPurple),
                        ),
                        const TextSpan(text: '!'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Your Surra account is ready.\nTime to start saving! 💰",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTextStyles.nunito,
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.kTextSoft, height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Stats summary
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.kBorder, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.kPurple.withOpacity(0.15),
                          blurRadius: 24, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatPill(emoji: '🍔', label: 'Food'),
                        _divider(),
                        _StatPill(emoji: '🎮', label: 'Games'),
                        _divider(),
                        _StatPill(emoji: '📚', label: 'School'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  KidPrimaryButton(
                    label: 'Go to My Dashboard 🚀',
                    onTap: () {
                      // Navigate to main dashboard
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 32,
    color: AppColors.kPurple.withOpacity(0.15),
  );
}

class _StatPill extends StatelessWidget {
  final String emoji, label;
  const _StatPill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style:  TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          label,
          style:  TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.kTextSoft,
          ),
        ),
      ],
    );
  }
}
