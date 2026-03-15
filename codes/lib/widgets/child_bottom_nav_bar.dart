// lib/widgets/child_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/Child_Screens/Child_Saving/child_saving.dart' as child;
import '../screens/profile/profile_main.dart';
import '../screens/log/log_transaction_manually.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../utils/auth_helpers.dart';

// ── Kid theme colours ─────────────────────────────────────────────────────────
const _kPurple    = Color(0xFF8B5CF6);
const _kTextSoft  = Color(0xFF7C6FA0);
const _kText      = Color(0xFF2D1B69);
const _kCardBg    = Color(0xFFF5F0FF); // very light lavender — same feel as kidBg

class ChildBottomBar extends StatelessWidget {
  final VoidCallback  onTapDashboard;
  final VoidCallback  onTapSavings;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapAssistant;
  final VoidCallback? onTapAdd;
  final int           selectedIndex; // 0=Profile 1=Savings 2=Dashboard 3=Assistant

  const ChildBottomBar({
    super.key,
    required this.onTapDashboard,
    required this.onTapSavings,
    this.selectedIndex = -1,
    this.onTapProfile,
    this.onTapAssistant,
    this.onTapAdd,
  });

  static const _heroTag = 'child-add-fab';

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment:    Alignment.topCenter,
      children: [
        SizedBox(
          height: 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: [

              // ── Curved bar — light lavender ───────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 100),
                  painter: _KidBarPainter(),
                ),
              ),

              // ── Icon row ──────────────────────────────────────────────
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 35),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [

                        // Profile
                        Expanded(child: _NavItem(
                          icon:        Icons.person_outline,
                          label:       'Profile',
                          isSelected:  selectedIndex == 0,
                          activeColor: _kPurple,
                          onTap: onTapProfile ?? () =>
                              Navigator.pushReplacement(context,
                                  MaterialPageRoute(
                                      builder: (_) => const ProfileMainPage())),
                        )),

                        // Savings
                        Expanded(child: _NavItem(
                          icon:        Icons.track_changes_outlined,
                          label:       'Savings',
                          isSelected:  selectedIndex == 1,
                          activeColor: const Color(0xFF60A5FA),
                          onTap:       onTapSavings,
                        )),

                        // Empty centre slot for FAB
                        const Expanded(child: SizedBox()),

                        // Dashboard
                        Expanded(child: _NavItem(
                          icon:        Icons.pie_chart_outline,
                          label:       'Dashboard',
                          isSelected:  selectedIndex == 2,
                          activeColor: const Color(0xFF34D399),
                          onTap:       onTapDashboard,
                        )),

                        // Assistant
                        Expanded(child: _NavItem(
                          icon:        Icons.smart_toy_outlined,
                          label:       'AI assistant',
                          isSelected:  selectedIndex == 3,
                          activeColor: const Color(0xFFF472B6),
                          onTap: onTapAssistant ?? () async {
                            final profileId = await getProfileId(context);
                            final userId    = Supabase.instance.client
                                .auth.currentUser?.id;
                            if (profileId == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Unable to load profile.')));
                              }
                              return;
                            }
                            if (context.mounted) {
                              Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => ChatBotScreen(
                                            profileId: profileId,
                                            userId:    userId,
                                          )));
                            }
                          },
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Centre FAB ────────────────────────────────────────────────────
        Positioned(
          top: -18,
          child: _FabButton(
            onTap: onTapAdd ?? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder:         (_) => const LogTransactionManuallyPage(),
                fullscreenDialog: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Nav item — icon + label, bubble when selected ─────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         isSelected;
  final Color        activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Column(
          mainAxisSize:      MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutCubic,
              padding:  isSelected
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                  : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:        isSelected
                    ? activeColor.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon,
                  size:  20,
                  color: isSelected ? activeColor : _kTextSoft),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color:      isSelected ? activeColor : _kTextSoft,
                    fontSize:   9,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500),
                maxLines:  1,
                overflow:  TextOverflow.clip,
                textAlign: TextAlign.center),

          ],
        ),
      ),
    );
  }
}

// ── FAB button ────────────────────────────────────────────────────────────────
class _FabButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FabButton({required this.onTap});
  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _scale = 1.15),
      onTapCancel: ()  => setState(() => _scale = 1.0),
      onTapUp: (_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale:    _scale,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeInOut,
        child: Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [Color(0xFF9B6FFF), Color(0xFF6C8FFF)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      Color(0x558B5CF6),
                blurRadius: 20,
                offset:     Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── Curved bar painter — light lavender bar, same path as adult ───────────────
class _KidBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft shadow
    final shadowPaint = Paint()
      ..color      = const Color(0x208B5CF6)
      ..style      = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Bar fill — light lavender matching the page
    final fillPaint = Paint()
      ..color = const Color(0xFFF0EBFF)
      ..style = PaintingStyle.fill;

    final path = _buildPath(size);
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, fillPaint);
  }

  Path _buildPath(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, 40);
    path.quadraticBezierTo(0, 25, 15, 20);
    path.lineTo(size.width * 0.35, 20);
    path.quadraticBezierTo(
        size.width * 0.38, 20, size.width * 0.40, 25);
    path.quadraticBezierTo(
        size.width * 0.43, 35, size.width * 0.45, 50);
    path.arcToPoint(
      Offset(size.width * 0.55, 50),
      radius:    const Radius.circular(30),
      clockwise: false,
    );
    path.quadraticBezierTo(
        size.width * 0.57, 35, size.width * 0.60, 25);
    path.quadraticBezierTo(
        size.width * 0.62, 20, size.width * 0.65, 20);
    path.lineTo(size.width - 15, 20);
    path.quadraticBezierTo(size.width, 25, size.width, 40);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}