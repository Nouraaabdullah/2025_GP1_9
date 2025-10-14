// lib/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SurraBottomBar extends StatelessWidget {
  final VoidCallback onTapDashboard;
  final VoidCallback onTapSavings;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapAssistant;
  final VoidCallback? onTapAdd; // Add button callback

  const SurraBottomBar({
    super.key,
    required this.onTapDashboard,
    required this.onTapSavings,
    this.onTapProfile,
    this.onTapAssistant,
    this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Bottom bar
        SizedBox(
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom curved bottom bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 100),
                  painter: _CurvedBottomBarPainter(
                    color: AppColors.card,
                  ),
                ),
              ),
              // Navigation items
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30, bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _item('AI assistant', Icons.android, onTapAssistant ?? () {}),
                        _item('Dashboard', Icons.pie_chart, onTapDashboard),
                        const SizedBox(width: 80), // space for center FAB
                        _item('Savings', Icons.savings, onTapSavings),
                        _item('Profile', Icons.person, onTapProfile ?? () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Center FAB - Always visible
        Positioned(
          top: -10,
          child: GestureDetector(
            onTap: onTapAdd ?? () {},
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withOpacity(0.85),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(String label, IconData icon, VoidCallback onTap) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.textGrey),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvedBottomBarPainter extends CustomPainter {
  final Color color;

  _CurvedBottomBarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from bottom left
    path.moveTo(0, size.height);
    
    // Left side curve up
    path.lineTo(0, 40);
    path.quadraticBezierTo(0, 25, 15, 20);
    
    // Top left horizontal
    path.lineTo(size.width * 0.35, 20);
    
    // Curve down into center notch
    path.quadraticBezierTo(
      size.width * 0.38, 20,
      size.width * 0.40, 25,
    );
    
    // Left side of center circle
    path.quadraticBezierTo(
      size.width * 0.43, 35,
      size.width * 0.45, 50,
    );
    
    // Bottom of center notch
    path.arcToPoint(
      Offset(size.width * 0.55, 50),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    
    // Right side of center circle
    path.quadraticBezierTo(
      size.width * 0.57, 35,
      size.width * 0.60, 25,
    );
    
    // Curve up from center notch
    path.quadraticBezierTo(
      size.width * 0.62, 20,
      size.width * 0.65, 20,
    );
    
    // Top right horizontal
    path.lineTo(size.width - 15, 20);
    
    // Right side curve down
    path.quadraticBezierTo(size.width, 25, size.width, 40);
    path.lineTo(size.width, size.height);
    
    // Bottom
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}