import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen
    extends
        StatefulWidget {
  const SignUpScreen({
    super.key,
  });

  @override
  State<
    SignUpScreen
  >
  createState() => _SignUpScreenState();
}

class _SignUpScreenState
    extends
        State<
          SignUpScreen
        > {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool loading = false;
  bool showPassword = false;

  // NEW VALIDATION FIELDS
  String? emailError;
  String? passwordError;

  // Password validation states
  bool hasMinLength = false;
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  // EMAIL FORMAT VALIDATION
  bool isValidEmail(
    String email,
  ) {
    final regex = RegExp(
      r'^[^@]+@[^@]+\.[^@]+$',
    );
    return regex.hasMatch(
      email,
    );
  }

  void validatePassword(
    String password,
  ) {
    setState(
      () {
        hasMinLength =
            password.length >=
            8;
        hasUpper =
            RegExp(
              r'[A-Z]',
            ).hasMatch(
              password,
            );
        hasLower =
            RegExp(
              r'[a-z]',
            ).hasMatch(
              password,
            );
        hasNumber =
            RegExp(
              r'[0-9]',
            ).hasMatch(
              password,
            );
        hasSpecial =
            RegExp(
              r'[^A-Za-z0-9]',
            ).hasMatch(
              password,
            );
        passwordError = null; // clear on change
      },
    );
  }

  // ===== SIGN UP USER =====
  Future<
    void
  >
  signUpUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(
      () {
        emailError = null;
        passwordError = null;
      },
    );

    bool hasError = false;

    // EMAIL CHECKS
    if (email.isEmpty) {
      emailError = "Email is required.";
      hasError = true;
    } else if (!isValidEmail(
      email,
    )) {
      emailError = "Please enter a valid email address.";
      hasError = true;
    }

    // PASSWORD CHECKS
    if (password.isEmpty) {
      passwordError = "Password is required.";
      hasError = true;
    } else if (!(hasMinLength &&
        hasUpper &&
        hasLower &&
        hasNumber &&
        hasSpecial)) {
      passwordError = "Your password does not meet all requirements.";
      hasError = true;
    }

    if (hasError) {
      setState(
        () {},
      );
      return;
    }

    setState(
      () => loading = true,
    );

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user ==
          null)
        throw Exception(
          "User creation failed",
        );

      await supabase
          .from(
            'User_Profile',
          )
          .insert(
            {
              'user_id': user.id,
              'email': email,
              'full_name': null,
              'current_balance': 0,
            },
          );

      Navigator.pushReplacementNamed(
        context,
        '/setupName',
      );
    } on AuthException catch (
      e
    ) {
      setState(
        () {
          if (e.message.toLowerCase().contains(
            'already registered',
          )) {
            emailError = "This email is already registered.";
          } else {
            passwordError = "Signup failed. Please try again.";
          }
        },
      );
    } catch (
      e
    ) {
      setState(
        () {
          passwordError = "Something went wrong. Please try again.";
        },
      );
    } finally {
      setState(
        () => loading = false,
      );
    }
  }

  // ========================= UI =========================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0F0F1A,
      ),
      body: Stack(
        children: [
          // ================= PURPLE ARC =================
          Container(
            height: 260,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                  40,
                ),
                bottomRight: Radius.circular(
                  40,
                ),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(
                    0xFF6A47CE,
                  ),
                  Color(
                    0xFF3C2C71,
                  ),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.7,
                        center: Alignment(
                          0,
                          -0.3,
                        ),
                        colors: [
                          Color(
                            0x90B38CFF,
                          ),
                          Color(
                            0x003C2C71,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 110,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Back arrow
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(
                  context,
                ),
              ),
            ),
          ),

          // ================= CONTENT CARD =================
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  40,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF181826,
                  ),
                  borderRadius: BorderRadius.circular(
                    28,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email
                    const Text(
                      "Email",
                      style: TextStyle(
                        color: Color(
                          0xFFBEBED3,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _inputField(
                      controller: emailController,
                      hint: "you@example.com",
                      isPassword: false,
                      error: emailError,
                      onChanged:
                          (
                            _,
                          ) {
                            setState(
                              () => emailError = null,
                            );
                          },
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    // Password
                    const Text(
                      "Password",
                      style: TextStyle(
                        color: Color(
                          0xFFBEBED3,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _inputField(
                      controller: passwordController,
                      hint: "********",
                      isPassword: true,
                      onChanged: validatePassword,
                      error: passwordError,
                    ),

                    // ==== PASSWORD REQUIREMENTS ====
                    if (passwordController.text.isNotEmpty) ...[
                      const SizedBox(
                        height: 12,
                      ),
                      _req(
                        "At least 8 characters",
                        hasMinLength,
                      ),
                      _req(
                        "Uppercase letter",
                        hasUpper,
                      ),
                      _req(
                        "Lowercase letter",
                        hasLower,
                      ),
                      _req(
                        "A number",
                        hasNumber,
                      ),
                      _req(
                        "Special character",
                        hasSpecial,
                      ),
                    ],

                    const SizedBox(
                      height: 35,
                    ),

                    // SIGN UP BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : signUpUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF7C5CFF,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                          shadowColor: const Color(
                            0xAA7C5CFF,
                          ),
                          elevation: 10,
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= INPUT FIELD =================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    void Function(
      String,
    )?
    onChanged,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          child: Builder(
            builder:
                (
                  context,
                ) {
                  final bool isFocused = Focus.of(
                    context,
                  ).hasFocus;

                  return AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF121225,
                      ),
                      borderRadius: BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color: isFocused
                            ? const Color(
                                0xFF7C5CFF,
                              )
                            : const Color(
                                0xFF2C284A,
                              ),
                        width: isFocused
                            ? 2
                            : 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            obscureText:
                                isPassword &&
                                !showPassword,
                            onChanged: onChanged,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: hint,
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),
                        if (isPassword)
                          IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(
                                () => showPassword = !showPassword,
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
          ),
        ),

        if (error !=
            null)
          Padding(
            padding: const EdgeInsets.only(
              top: 6,
              left: 4,
            ),
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  // ================= REQUIREMENT ROW =================
  Widget _req(
    String text,
    bool ok,
  ) {
    return Row(
      children: [
        Icon(
          ok
              ? Icons.check_circle
              : Icons.circle,
          size: 16,
          color: ok
              ? const Color(
                  0xFF7C5CFF,
                )
              : Colors.white24,
        ),
        const SizedBox(
          width: 8,
        ),
        Text(
          text,
          style: TextStyle(
            color: ok
                ? Colors.white
                : Colors.white38,
            fontSize: 13.5,
            fontWeight: ok
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
