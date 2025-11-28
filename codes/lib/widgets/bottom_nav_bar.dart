import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../screens/log/log_transaction_manually.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/savings/savings_page.dart';
import '../screens/profile/profile_main.dart';
import '../utils/auth_helpers.dart';

class SurraBottomBar
    extends
        StatelessWidget {
  final VoidCallback onTapDashboard;
  final VoidCallback onTapSavings;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapAssistant;
  final VoidCallback? onTapAdd;

  const SurraBottomBar({
    super.key,
    required this.onTapDashboard,
    required this.onTapSavings,
    this.onTapProfile,
    this.onTapAssistant,
    this.onTapAdd,
  });

  static const _heroTag = 'surra-add-fab';

  @override
  Widget build(
    BuildContext context,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        SizedBox(
          height: 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(
                      context,
                    ).size.width,
                    100,
                  ),
                  painter: _CurvedBottomBarPainter(
                    color: AppColors.card,
                  ),
                ),
              ),

              // ==== ICON ROW (EVENLY SPACED) ====
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 35,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Profile
                        Expanded(
                          child: _item(
                            'Profile',
                            Icons.person_outline,
                            onTapProfile ??
                                () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (
                                            _,
                                          ) => const ProfileMainPage(),
                                    ),
                                  );
                                },
                          ),
                        ),

                        // Savings
                        Expanded(
                          child: _item(
                            'Savings',
                            Icons.track_changes_outlined,
                            onTapSavings,
                          ),
                        ),

                        // Empty center slot for FAB
                        const Expanded(
                          child: SizedBox(),
                        ),

                        // Dashboard
                        Expanded(
                          child: _item(
                            'Dashboard',
                            Icons.pie_chart_outline,
                            onTapDashboard,
                          ),
                        ),

                        // AI Assistant
                        Expanded(
                          child: _item(
                            'AI assistant',
                            Icons.smart_toy_outlined,
                            onTapAssistant ??
                                () async {
                                  final profileId = await getProfileId(
                                    context,
                                  );
                                  final userId = Supabase.instance.client.auth.currentUser?.id;

                                  if (profileId ==
                                      null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Unable to load profile.",
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (
                                              _,
                                            ) => ChatBotScreen(
                                              profileId: profileId,
                                              userId: userId,
                                            ),
                                      ),
                                    );
                                  }
                                },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ===== CENTER FAB BUTTON =====
        Positioned(
          top: -10,
          child: StatefulBuilder(
            builder:
                (
                  context,
                  setState,
                ) {
                  double scale = 1.0;

                  return GestureDetector(
                    onTapDown:
                        (
                          _,
                        ) => setState(
                          () => scale = 1.15,
                        ),
                    onTapUp:
                        (
                          _,
                        ) async {
                          await Future.delayed(
                            const Duration(
                              milliseconds: 100,
                            ),
                          );
                          setState(
                            () => scale = 1.0,
                          );

                          if (onTapAdd !=
                              null) {
                            onTapAdd!();
                          } else {
                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder:
                                    (
                                      _,
                                    ) => const LogTransactionManuallyPage(),
                                fullscreenDialog: true,
                              ),
                            );
                          }
                        },
                    onTapCancel: () => setState(
                      () => scale = 1.0,
                    ),
                    child: AnimatedScale(
                      scale: scale,
                      duration: const Duration(
                        milliseconds: 120,
                      ),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accent,
                              AppColors.accent.withOpacity(
                                0.85,
                              ),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(
                                0.6,
                              ),
                              blurRadius: 24,
                              offset: const Offset(
                                0,
                                8,
                              ),
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
                  );
                },
          ),
        ),
      ],
    );
  }

  // ===== BOTTOM BAR ITEM =====
  Widget _item(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.textGrey,
            ),
            const SizedBox(
              height: 2,
            ),
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
    );
  }
}

class _CurvedBottomBarPainter
    extends
        CustomPainter {
  final Color color;
  _CurvedBottomBarPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(
      0,
      size.height,
    );
    path.lineTo(
      0,
      40,
    );
    path.quadraticBezierTo(
      0,
      25,
      15,
      20,
    );
    path.lineTo(
      size.width *
          0.35,
      20,
    );
    path.quadraticBezierTo(
      size.width *
          0.38,
      20,
      size.width *
          0.40,
      25,
    );
    path.quadraticBezierTo(
      size.width *
          0.43,
      35,
      size.width *
          0.45,
      50,
    );

    path.arcToPoint(
      Offset(
        size.width *
            0.55,
        50,
      ),
      radius: const Radius.circular(
        30,
      ),
      clockwise: false,
    );

    path.quadraticBezierTo(
      size.width *
          0.57,
      35,
      size.width *
          0.60,
      25,
    );
    path.quadraticBezierTo(
      size.width *
          0.62,
      20,
      size.width *
          0.65,
      20,
    );
    path.lineTo(
      size.width -
          15,
      20,
    );
    path.quadraticBezierTo(
      size.width,
      25,
      size.width,
      40,
    );

    path.lineTo(
      size.width,
      size.height,
    );
    path.lineTo(
      0,
      size.height,
    );
    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) => false;
}
