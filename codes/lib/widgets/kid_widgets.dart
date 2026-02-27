import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Kid gradient background scaffold ──
class KidScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const KidScaffold({
    super.key,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.kidBg,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 🔙 Automatic Back Button
              if (showBack && Navigator.of(context).canPop())
                Positioned(
                  top: 10,
                  left: 14,
                  child: KidBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                ),

              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating bubble decoration ──
class KidBubbles extends StatelessWidget {
  const KidBubbles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          _Bubble(left: 20, top: 80, size: 110, color: AppColors.kPurpleSoft),
          _Bubble(right: 10, top: 200, size: 80, color: AppColors.kBlueSoft),
          _Bubble(left: 60, bottom: 200, size: 140, color: AppColors.kPinkSoft),
          _Bubble(right: 30, bottom: 100, size: 90, color: AppColors.kYellowSoft),
          _Bubble(left: -20, top: 400, size: 100, color: AppColors.kGreenSoft),
        ],
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  final double? left, right, top, bottom, size;
  final Color color;
  const _Bubble({this.left, this.right, this.top, this.bottom, required this.size, required this.color});

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _anim = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.04)).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left, right: widget.right, top: widget.top, bottom: widget.bottom,
      child: SlideTransition(
        position: _anim,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.22),
          ),
        ),
      ),
    );
  }
}

// ── Badge chip ──
class KidBadge extends StatelessWidget {
  final String text;
  const KidBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.nunito,
          fontSize: 12, fontWeight: FontWeight.w800,
          color: AppColors.kPurple,
        ),
      ),
    );
  }
}

// ── Primary gradient button ──
class KidPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const KidPrimaryButton({
    super.key, required this.label, this.onTap, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: loading ? null : AppGradients.purpleBtn,
          color: loading ? AppColors.kPurple.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading ? [] : [
            BoxShadow(
              color: AppColors.kPurpleDark.withOpacity(0.35),
              blurRadius: 24, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18, color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Ghost / outline button ──
class KidGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const KidGhostButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.kPurple.withOpacity(0.4), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 18, color: AppColors.kPurple,
            ),
          ),
        ),
      ),
    );
  }
}

// ── White card ──
class KidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const KidCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.kBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.kPurple.withOpacity(0.18),
            blurRadius: 32, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Text input ──
class KidInput extends StatefulWidget {
  final String label;
  final String placeholder;
  final String icon;
  final bool isPassword;
  final String? errorText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final void Function(String)? onChanged;

  const KidInput({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  State<KidInput> createState() => _KidInputState();
}

class _KidInputState extends State<KidInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.icon}  ${widget.label}',
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.kText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.kText,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 14, fontWeight: FontWeight.w600,
              color: const Color(0xFFB8AED4),
            ),
            filled: true,
            fillColor: hasError
                ? AppColors.kPink.withOpacity(0.08)
                : AppColors.kInputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.kPink.withOpacity(0.6)
                    : AppColors.kPurple.withOpacity(0.2),
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError
                    ? AppColors.kPink.withOpacity(0.6)
                    : AppColors.kPurple.withOpacity(0.2),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.kPurple, width: 2),
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.kTextSoft,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                widget.errorText!,
                style: const TextStyle(
                  fontFamily: AppTextStyles.nunito,
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: AppColors.kErrorText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Alert banner ──
class KidAlert extends StatelessWidget {
  final String message;
  const KidAlert(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.kErrorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.kErrorBorder, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('😬', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppColors.kErrorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info callout ──
class KidInfoBox extends StatelessWidget {
  final String text;
  const KidInfoBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.kPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.kPurple.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.kPurple, height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress dots ──
class KidProgressDots extends StatelessWidget {
  final int total;
  final int current; // 1-indexed
  const KidProgressDots({super.key, required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isDone = i + 1 < current;
        final isActive = i + 1 == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.kGreen
                : isActive
                    ? AppColors.kPurple
                    : AppColors.kPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

// ── Back button for kid screens ──
class KidBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const KidBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.chevron_left_rounded, color: AppColors.kText, size: 24),
        ),
      ),
    );
  }
}

// ── Switch row ("Already have account? Log In") ──
class KidSwitchRow extends StatelessWidget {
  final String text;
  final String linkText;
  final VoidCallback onTap;
  const KidSwitchRow({super.key, required this.text, required this.linkText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.kTextSoft,
          ),
          children: [
            TextSpan(text: '$text '),
            WidgetSpan(
              child: GestureDetector(
                onTap: onTap,
                child: const Text(
                  '',
                  style: TextStyle(
                    fontFamily: AppTextStyles.nunito,
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.kPurple,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.kPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
