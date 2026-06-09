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

  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  String? _userErr, _pwErr, _alertMsg;

  bool _loading = false;
        bool hasMinLength = false;
bool hasUpper = false;
bool hasLower = false;
bool hasNumber = false;
bool hasSpecial = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }
void validatePassword(String password) {
  setState(() {
    hasMinLength = password.length >= 8;
    hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    hasLower = RegExp(r'[a-z]').hasMatch(password);
    hasNumber = RegExp(r'[0-9]').hasMatch(password);
    hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    _pwErr = null;
  });
}

String? _validatePassword(String pw) {
  if (pw.isEmpty) {
    return 'Password is required.';
  }

  if (!(hasMinLength && hasUpper && hasLower && hasNumber && hasSpecial)) {
    return 'Your password does not meet all requirements.';
  }

  return null;
}

  void _submit() async {
  setState(() {
    _userErr = null;
    _pwErr = null;
    _alertMsg = null;
  });

  final user = _userCtrl.text.trim();
  final pw = _pwCtrl.text;

  bool valid = true;

  if (user.isEmpty) {
    _userErr = 'Username required';
    valid = false;
  }

  final pwValidation = _validatePassword(pw);
  if (pwValidation != null) {
    _pwErr = pwValidation;
    valid = false;
  }

  if (!valid) {
    setState(() {});
    return;
  }

  setState(() => _loading = true);

  try {
    final supabase = Supabase.instance.client;

    final relation = await supabase
        .from('Child_Guardian')
        .select('child_id')
        .eq('user_name', user)
        .maybeSingle();

    if (relation == null) {
      setState(() {
        _loading = false;
        _alertMsg = "Username not found. Ask your guardian to create it first.";
      });
      return;
    }

    setState(() => _loading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingNameScreen(
          username: user,
          password: pw,
        ),
      ),
    );
  } catch (e) {
    setState(() {
      _loading = false;
      _alertMsg = "Error: $e";
    });
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
                                onChanged: (_) => setState(() => _userErr = null),
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
                            onChanged: validatePassword,
                            ),
                          if (_pwCtrl.text.isNotEmpty) ...[
  const SizedBox(height: 8),
  Column(
    children: [
      _req('At least 8 characters', hasMinLength),
      _req('An uppercase letter', hasUpper),
      _req('A lowercase letter', hasLower),
      _req('A number', hasNumber),
      _req('A special character', hasSpecial),
    ],
  ),
],



                            const SizedBox(
                              height: 14,
                            ),

                            // Confirm
                           
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
  Widget _req(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.circle,
            size: 16,
            color: ok
                ? AppColors.kPurple
                : AppColors.kTextSoft.withOpacity(0.45),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTextStyles.nunito,
              color: ok
                  ? AppColors.kText
                  : AppColors.kTextSoft.withOpacity(0.65),
              fontSize: 13.5,
              fontWeight: ok ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
        }
  

