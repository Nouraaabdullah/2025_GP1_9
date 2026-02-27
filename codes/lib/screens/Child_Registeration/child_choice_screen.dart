import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kid_widgets.dart';
import 'child_signup_screen.dart';
import 'child_login_screen.dart';

class ChildChoiceScreen extends StatefulWidget {
  const ChildChoiceScreen({super.key});

  @override
  State<ChildChoiceScreen> createState() => _ChildChoiceScreenState();
}

class _ChildChoiceScreenState extends State<ChildChoiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _floatCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),
          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: KidBackButton(onTap: () => Navigator.pop(context)),
                ),
              ),

              const SizedBox(height: 24),

              // Floating star
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: const Text('🌟', style: TextStyle(fontSize: 60)),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Hey there,\nsuperstar!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 34, color: AppColors.kText, height: 1.1,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'What do you want to do today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.kTextSoft,
                ),
              ),

              const SizedBox(height: 40),

              // Choice cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _ChoiceCard(
                      emoji: '🚀',
                      title: 'Create Account',
                      description: "I'm new here — let's start!",
                      borderColor: AppColors.kPurple.withOpacity(0.5),
                      titleColor: AppColors.kText,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChildSignupScreen()),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ChoiceCard(
                      emoji: '🔑',
                      title: 'Log In',
                      description: 'I already have an account',
                      borderColor: AppColors.kBlue.withOpacity(0.5),
                      titleColor: AppColors.kBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChildLoginScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final String emoji, title, description;
  final Color borderColor, titleColor;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.emoji, required this.title, required this.description,
    required this.borderColor, required this.titleColor, required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _pressed ? 0 : -3, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.kCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: widget.borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.kPurple.withOpacity(_pressed ? 0.1 : 0.18),
              blurRadius: 32, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(widget.emoji, style:  TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 22, color: widget.titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style:  TextStyle(
                    fontFamily: AppTextStyles.nunito,
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.kTextSoft,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: AppColors.kTextSoft, size: 22),
          ],
        ),
      ),
    );
  }
}
