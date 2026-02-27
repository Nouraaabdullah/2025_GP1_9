import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';
import 'onboarding_celebration_screen.dart';

class OnboardingBalanceScreen extends StatefulWidget {
  final String childName;
  final double foodLimit, gamesLimit, schoolLimit;

  const OnboardingBalanceScreen({
    super.key,
    required this.childName,
    required this.foodLimit,
    required this.gamesLimit,
    required this.schoolLimit,
  });

  @override
  State<OnboardingBalanceScreen> createState() => _OnboardingBalanceScreenState();
}

class _OnboardingBalanceScreenState extends State<OnboardingBalanceScreen>
    with SingleTickerProviderStateMixin {
  final _balCtrl = TextEditingController();
  String? _balErr;
  double _previewAmount = 0;

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
  void dispose() { _floatCtrl.dispose(); _balCtrl.dispose(); super.dispose(); }

  void _onBalChanged(String val) {
    setState(() {
      _balErr = null;
      _previewAmount = double.tryParse(val) ?? 0;
    });
  }

  void _finish() {
    final val = _balCtrl.text.trim();
    if (val.isEmpty || double.tryParse(val) == null) {
      setState(() => _balErr = 'Please enter your balance!');
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingCelebrationScreen(childName: widget.childName),
      ),
      (route) => false,
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
                    const KidBadge('Step 3 of 3 🐷'),
                    const SizedBox(height: 12),
                    Text(
                      'How much do\nyou have? 💰',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34, color: AppColors.kText, height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Count your wallet & piggy bank money!',
                      textAlign: TextAlign.center,
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
              
              KidProgressDots(total: 3, current: 3),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Balance preview card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: AppGradients.purpleCard,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.kPurpleDark.withOpacity(0.35),
                              blurRadius: 32, offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _floatAnim,
                              builder: (_, __) => Transform.translate(
                                offset: Offset(0, _floatAnim.value),
                                child: const Text('🐷', style: TextStyle(fontSize: 48)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'MY CURRENT BALANCE',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 13, fontWeight: FontWeight.w800,
                                color: Colors.white70, letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                '${_previewAmount.toStringAsFixed(_previewAmount == _previewAmount.truncate() ? 0 : 2)} SAR',
                                key: ValueKey(_previewAmount),
                                style:  TextStyle(
                                  fontFamily: AppTextStyles.fredoka,
                                  fontSize: 36, color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Check your wallet & piggy bank 🪙',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 12, color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      KidCard(
                        child: KidInput(
                          label: 'Balance Amount (SAR)',
                          placeholder: 'e.g. 250',
                          icon: '💰',
                          controller: _balCtrl,
                          keyboardType: TextInputType.number,
                          errorText: _balErr,
                          onChanged: _onBalChanged,
                        ),
                      ),

                      const SizedBox(height: 16),
                      KidPrimaryButton(label: 'Finish Setup! 🎉', onTap: _finish),
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
