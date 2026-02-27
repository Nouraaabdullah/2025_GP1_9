import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../Child_Registeration/child_choice_screen.dart';
import 'signup_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  final List<_StarDot> _stars = const [
    _StarDot(lf: 0.12, tf: 0.06, size: 3),
    _StarDot(lf: 0.82, tf: 0.04, size: 2.5),
    _StarDot(lf: 0.42, tf: 0.13, size: 2),
    _StarDot(lf: 0.68, tf: 0.09, size: 3),
    _StarDot(lf: 0.22, tf: 0.22, size: 2),
    _StarDot(lf: 0.88, tf: 0.19, size: 3),
    _StarDot(lf: 0.06, tf: 0.30, size: 2.5),
    _StarDot(lf: 0.55, tf: 0.07, size: 2),
    _StarDot(lf: 0.75, tf: 0.35, size: 3),
    _StarDot(lf: 0.35, tf: 0.28, size: 2),
    _StarDot(lf: 0.92, tf: 0.42, size: 2.5),
    _StarDot(lf: 0.16, tf: 0.50, size: 2),
    _StarDot(lf: 0.60, tf: 0.46, size: 3),
    _StarDot(lf: 0.04, tf: 0.60, size: 2),
    _StarDot(lf: 0.48, tf: 0.55, size: 2.5),
    _StarDot(lf: 0.80, tf: 0.58, size: 3),
    _StarDot(lf: 0.28, tf: 0.65, size: 2),
    _StarDot(lf: 0.94, tf: 0.70, size: 2.5),
    _StarDot(lf: 0.10, tf: 0.78, size: 3),
    _StarDot(lf: 0.65, tf: 0.72, size: 2),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: size.width * 0.95,
                height: size.width * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4B20CC),
                      const Color(0xFF2D1069).withOpacity(0.85),
                      AppColors.darkBg.withOpacity(0),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          ..._stars.map(
            (s) => Positioned(
              left: size.width * s.lf,
              top: size.height * s.tf,
              child: _TwinkleStar(size: s.size),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: Image.asset(
  'assets/images/surra_logo.png',
  width: 130,
  height: 130,
),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  'Welcome to Surra!',
                  style: TextStyle(
                    fontFamily: AppTextStyles.nunito,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Track your spending and build\nbetter habits with ease.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTextStyles.nunito,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkTextMuted,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _WhoCard(
                          emoji: '🧑',
                          label: 'Adult',
                          description: 'Manage your full finances',
                          borderColor:
                              AppColors.darkPurple.withOpacity(0.55),
                          labelColor: Colors.white,
                          bgColor: AppColors.darkSurface,
                        onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const SignUpScreen(),
  ),
),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _WhoCard(
                          emoji: '⭐',
                          label: 'Child',
                          description: "Join your guardian's account",
                          borderColor:
                              const Color(0xFFFBBF24).withOpacity(0.7),
                          labelColor: const Color(0xFFFBBF24),
                          bgColor: const Color(0xFF1E1A30),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChildChoiceScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDot {
  final double lf, tf, size;
  const _StarDot({
    required this.lf,
    required this.tf,
    required this.size,
  });
}

class _TwinkleStar extends StatefulWidget {
  final double size;
  const _TwinkleStar({required this.size});

  @override
  State<_TwinkleStar> createState() => _TwinkleStarState();
}

class _TwinkleStarState extends State<_TwinkleStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _WhoCard extends StatefulWidget {
  final String emoji, label, description;
  final Color borderColor, labelColor, bgColor;
  final VoidCallback onTap;

  const _WhoCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.borderColor,
    required this.labelColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_WhoCard> createState() => _WhoCardState();
}

class _WhoCardState extends State<_WhoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform:
            Matrix4.translationValues(0, _pressed ? 1 : -2, 0),
        padding:
            const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: widget.borderColor, width: 2),
        ),
        child: Column(
          children: [
            Text(widget.emoji,
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: widget.labelColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}