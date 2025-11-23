import 'dart:async';
import 'package:flutter/material.dart';
import 'start_page.dart';


class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  double _radius = 0;
  String displayedText = "";
  final String fullText = "Surra";
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();

    // Circle expansion animation controller
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Every frame update triggers repaint
    _circleController.addListener(() {
      setState(() {
        _radius = Tween<double>(begin: 0, end: 800)
            .transform(_circleController.value);
      });
    });

    _circleController.forward();

    // Reveal “Surra” letter by letter
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_charIndex < fullText.length) {
        setState(() {
          displayedText += fullText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
        // Navigate after animation finishes
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context, '/startpage');
        });
      }
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: CustomPaint(
        painter: CirclePainter(_radius),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/surra_logo.png',
                height: 120,
              ),
              const SizedBox(height: 30),
              Text(
                displayedText,
                style: const TextStyle(
                  fontSize: 42,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🎨 Custom painter for the expanding circle
class CirclePainter extends CustomPainter {
  final double radius;
  CirclePainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF1D1B32), Color(0xFF7C6FD6)],
        radius: 0.8,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) => oldDelegate.radius != radius;
}
