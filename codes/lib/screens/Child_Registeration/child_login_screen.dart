import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kid_widgets.dart';
import 'child_signup_screen.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  String? _emailErr, _userErr, _pwErr, _alertMsg;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose(); _userCtrl.dispose(); _pwCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  void _submit() {
    setState(() {
      _emailErr = null; _userErr = null; _pwErr = null; _alertMsg = null;
    });

    bool valid = true;
    final email = _emailCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _emailErr = email.isEmpty
          ? 'Guardian email is required'
          : 'Enter a valid email');
      valid = false;
    }
    if (user.isEmpty) {
      setState(() => _userErr = 'Username is required');
      valid = false;
    }
    if (pw.isEmpty) {
      setState(() => _pwErr = 'Password is required');
      valid = false;
    }
    if (!valid) return;

    setState(() => _loading = true);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _alertMsg =
            "The info you entered doesn't look right. Check with your guardian and try again!";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: KidBackButton(onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(height: 16),

              // Header
              Center(
                child: Column(
                  children: [
                    const KidBadge('👋 Welcome Back'),
                    const SizedBox(height: 12),
                    Text(
                      'Log In',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34, color: AppColors.kText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Great to see you again! 🎉',
                      style: TextStyle(
                        fontFamily: AppTextStyles.nunito,
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.kTextSoft,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      if (_alertMsg != null) ...[
                        KidAlert(_alertMsg!),
                        const SizedBox(height: 14),
                      ],

                      KidCard(
                        child: Column(
                          children: [
                            KidInput(
                              label: "Guardian's Email",
                              placeholder: 'parent@email.com',
                              icon: '📧',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailErr,
                              onChanged: (_) => setState(() => _emailErr = null),
                            ),
                            const SizedBox(height: 14),
                            KidInput(
                              label: 'Your Username',
                              placeholder: 'Your username',
                              icon: '🏷️',
                              controller: _userCtrl,
                              errorText: _userErr,
                              onChanged: (_) => setState(() => _userErr = null),
                            ),
                            const SizedBox(height: 14),
                            KidInput(
                              label: 'Your Password',
                              placeholder: 'Your secret password',
                              icon: '🔒',
                              controller: _pwCtrl,
                              isPassword: true,
                              errorText: _pwErr,
                              onChanged: (_) => setState(() => _pwErr = null),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      KidPrimaryButton(
                        label: "Let's Go! 🌟",
                        loading: _loading,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              fontFamily: AppTextStyles.nunito,
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: AppColors.kTextSoft,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ChildSignupScreen()),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: AppColors.kPurple,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.kPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
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
