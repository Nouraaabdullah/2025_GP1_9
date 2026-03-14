import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';
import 'child_login_screen.dart';
import 'onboarding_name_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildSignupScreen
    extends
        StatefulWidget {
  const ChildSignupScreen({
    super.key,
  });

  @override
  State<
    ChildSignupScreen
  >
  createState() => _ChildSignupScreenState();
}

class _ChildSignupScreenState
    extends
        State<
          ChildSignupScreen
        > {
  final _emailCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _cpwCtrl = TextEditingController();

  String? _emailErr, _userErr, _pwErr, _cpwErr, _alertMsg;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    _cpwCtrl.dispose();
    super.dispose();
  }

  bool
  _isValidEmail(
    String v,
  ) =>
      RegExp(
        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      ).hasMatch(
        v,
      );

  void _submit() async {
    setState(
      () {
        _emailErr = null;
        _userErr = null;
        _pwErr = null;
        _cpwErr = null;
        _alertMsg = null;
      },
    );

    final email = _emailCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pw = _pwCtrl.text;
    final cpw = _cpwCtrl.text;

    bool valid = true;

    if (email.isEmpty) {
      _emailErr = 'Guardian email required';
      valid = false;
    }

    if (user.isEmpty) {
      _userErr = 'Username required';
      valid = false;
    }

    if (pw.length <
        6) {
      _pwErr = 'Minimum 6 characters';
      valid = false;
    }

    if (pw !=
        cpw) {
      _cpwErr = 'Passwords do not match';
      valid = false;
    }

    if (!valid) {
      setState(
        () {},
      );
      return;
    }

    setState(
      () => _loading = true,
    );

    try {
      final supabase = Supabase.instance.client;

      /// 1️⃣ Find guardian
      final guardian = await supabase
          .from(
            'User_Profile',
          )
          .select(
            'user_id',
          )
          .eq(
            'email',
            email,
          )
          .eq(
            'user_type',
            'guardian',
          )
          .maybeSingle();

      if (guardian ==
          null) {
        setState(
          () {
            _loading = false;
            _alertMsg = "Guardian email not found.";
          },
        );
        return;
      }

      final guardianId = guardian['user_id'];

      /// 2️⃣ Verify child username
      final relation = await supabase
          .from(
            'Child_Guardian',
          )
          .select()
          .eq(
            'guardian_id',
            guardianId,
          )
          .eq(
            'user_name',
            user,
          )
          .maybeSingle();

      if (relation ==
          null) {
        setState(
          () {
            _loading = false;
            _alertMsg = "This username wasn't created by your guardian.";
          },
        );
        return;
      }

      setState(
        () => _loading = false,
      );

      /// 3️⃣ Continue onboarding
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (
                _,
              ) => OnboardingNameScreen(
                guardianEmail: email,
                username: user,
                password: pw,
              ),
        ),
      );
    } catch (
      e
    ) {
      setState(
        () {
          _loading = false;
          _alertMsg = "Error: $e";
        },
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  0,
                ),
                child: KidBackButton(
                  onTap: () => Navigator.pop(
                    context,
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),

              // Title area
              Center(
                child: Column(
                  children: [
                    const KidBadge(
                      '⭐ New Account',
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      'Sign Up',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 34,
                        color: AppColors.kText,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    const Text(
                      'Ask a grown-up to help you\nfill this in! 🙏',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.nunito,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextSoft,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // Scrollable form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      // Alert
                      if (_alertMsg !=
                          null) ...[
                        KidAlert(
                          _alertMsg!,
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                      ],

                      KidCard(
                        child: Column(
                          children: [
                            // Guardian email
                            KidInput(
                              label: "Guardian's Email",
                              placeholder: 'parent@email.com',
                              icon: '📧',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailErr,
                              onChanged:
                                  (
                                    _,
                                  ) => setState(
                                    () => _emailErr = null,
                                  ),
                            ),
                            const SizedBox(
                              height: 14,
                            ),

                            // Username
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                KidInput(
                                  label: 'Your Username',
                                  placeholder: 'e.g. SuperSaver123',
                                  icon: '🏷️',
                                  controller: _userCtrl,
                                  errorText: _userErr,
                                  onChanged:
                                      (
                                        _,
                                      ) => setState(
                                        () => _userErr = null,
                                      ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                const KidInfoBox(
                                  'Your guardian sets your username in their account first — ask them!',
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 14,
                            ),

                            // Password
                            KidInput(
                              label: 'Create Password',
                              placeholder: 'Make it secret!',
                              icon: '🔒',
                              controller: _pwCtrl,
                              isPassword: true,
                              errorText: _pwErr,
                              onChanged:
                                  (
                                    _,
                                  ) => setState(
                                    () => _pwErr = null,
                                  ),
                            ),
                            const SizedBox(
                              height: 14,
                            ),

                            // Confirm
                            KidInput(
                              label: 'Confirm Password',
                              placeholder: 'Type it again!',
                              icon: '🔒',
                              controller: _cpwCtrl,
                              isPassword: true,
                              errorText: _cpwErr,
                              onChanged:
                                  (
                                    _,
                                  ) => setState(
                                    () => _cpwErr = null,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),
                      KidPrimaryButton(
                        label: 'Create My Account 🚀',
                        loading: _loading,
                        onTap: _submit,
                      ),
                      const SizedBox(
                        height: 14,
                      ),

                      // Switch to login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
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
                                builder:
                                    (
                                      _,
                                    ) => const ChildLoginScreen(),
                              ),
                            ),
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.kPurple,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.kPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 24,
                      ),
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
