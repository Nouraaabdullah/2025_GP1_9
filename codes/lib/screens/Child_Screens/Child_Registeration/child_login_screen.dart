import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';
import 'child_signup_screen.dart';
import '../Child_Profile/child_profile.dart';
import 'package:surra_application/utils/auth_helpers.dart';

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

  final _sb = Supabase.instance.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  Future<void> _submit() async {
  setState(() {
    _emailErr = null;
    _userErr = null;
    _pwErr = null;
    _alertMsg = null;
  });

  final email = _emailCtrl.text.trim();
  final username = _userCtrl.text.trim();
  final password = _pwCtrl.text;

  setState(() => _loading = true);

  try {
    /// 🔥 STEP 1: Get ALL users with this email (NOT maybeSingle)
    final guardians = await _sb
        .from('User_Profile')
        .select('user_id, profile_id')
        .eq('email', email);

    print("GUARDIANS FOUND: $guardians");

    if (guardians.isEmpty) {
      throw Exception('Guardian not found');
    }

    /// ✅ take first one (real guardian)
    final guardian = guardians.first;

    final guardianUserId = guardian['user_id'];

    if (guardianUserId == null) {
      throw Exception('Guardian user_id is NULL');
    }

    /// 🔥 STEP 2: Find child
    final childLink = await _sb
        .from('Child_Guardian')
        .select('child_id')
        .eq('guardian_id', guardianUserId)
        .eq('user_name', username)
        .maybeSingle();

    print("CHILD LINK: $childLink");

    if (childLink == null) {
      throw Exception('Child not found');
    }

    final childProfileId = childLink['child_id'];

    /// 🔥 STEP 3: Get child profile
    final childProfile = await _sb
        .from('User_Profile')
        .select('hashed_password')
        .eq('profile_id', childProfileId)
        .maybeSingle();

    print("CHILD PROFILE: $childProfile");

    if (childProfile == null) {
      throw Exception('Child profile missing');
    }

    /// 🔥 STEP 4: Check password
    if (childProfile['hashed_password'] != password) {
      throw Exception('Wrong password');
    }

    print("LOGIN SUCCESS ✅");

currentChildProfileId = childProfileId;

    if (!mounted) return;

  Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => ChildProfilePage(), // or your actual class name
  ),
);

  } catch (e) {
    print("LOGIN ERROR: $e");

    setState(() {
      _alertMsg =
          "The info you entered doesn't look right. Check with your guardian and try again!";
    });
  } finally {
    if (mounted) setState(() => _loading = false);
  }
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

              /// Header
              Center(
                child: Column(
                  children: [
                    const KidBadge('👋 Welcome Back'),
                    const SizedBox(height: 12),
                    Text(
                      'Log In',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34,
                        color: AppColors.kText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Great to see you again! 🎉',
                      style: TextStyle(
                        fontFamily: AppTextStyles.nunito,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
                              onChanged: (_) =>
                                  setState(() => _emailErr = null),
                            ),
                            const SizedBox(height: 14),
                            KidInput(
                              label: 'Your Username',
                              placeholder: 'Your username',
                              icon: '🏷️',
                              controller: _userCtrl,
                              errorText: _userErr,
                              onChanged: (_) =>
                                  setState(() => _userErr = null),
                            ),
                            const SizedBox(height: 14),
                            KidInput(
                              label: 'Your Password',
                              placeholder: 'Your secret password',
                              icon: '🔒',
                              controller: _pwCtrl,
                              isPassword: true,
                              errorText: _pwErr,
                              onChanged: (_) =>
                                  setState(() => _pwErr = null),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.kTextSoft,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ChildSignupScreen()),
                            ),
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.kPurple,
                                decoration: TextDecoration.underline,
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