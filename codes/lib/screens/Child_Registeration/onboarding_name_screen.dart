import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kid_widgets.dart';
import 'onboarding_categories_screen.dart';

class OnboardingNameScreen extends StatefulWidget {
  const OnboardingNameScreen({super.key});

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String? _nameErr;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  final _emojis = ['🐣', '🦄', '🐯', '🦊', '🐸', '🐼', '🦁', '🐧', '🦋', '🌸'];
  String _currentEmoji = '🐣';

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose(); _nameCtrl.dispose(); super.dispose();
  }

  void _onNameChanged(String val) {
    setState(() {
      _nameErr = null;
      _currentEmoji = val.isEmpty ? '🐣' : _emojis[val.length % _emojis.length];
    });
  }

  void _next() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'Please tell us your name!');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingCategoriesScreen(childName: name),
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
                    const KidBadge('Step 1 of 3 ✏️'),
                    const SizedBox(height: 12),
                    Text(
                      "What's your\nname? 👋",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34, color: AppColors.kText, height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tell us who you are!',
                      style: TextStyle(
                        fontFamily: AppTextStyles.nunito,
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.kTextSoft,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress dots
              KidProgressDots(total: 3, current: 1),

              const SizedBox(height: 24),

              // Bouncing emoji
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: Text(_currentEmoji, style:  TextStyle(fontSize: 64)),
                ),
              ),

              const SizedBox(height: 24),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      KidCard(
                        child: KidInput(
                          label: 'Your Name',
                          placeholder: 'Enter your full name',
                          icon: '✏️',
                          controller: _nameCtrl,
                          errorText: _nameErr,
                          onChanged: _onNameChanged,
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
