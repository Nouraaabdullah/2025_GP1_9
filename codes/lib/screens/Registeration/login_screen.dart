import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool showPassword = false;
  bool loading = false;

  // ERROR FIELDS
  String? emailError;
  String? passwordError;

  // EMAIL FORMAT VALIDATION
  bool isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      emailError = null;
      passwordError = null;
    });

    bool hasError = false;

    // EMAIL CHECK
    if (email.isEmpty) {
      emailError = "Email is required.";
      hasError = true;
    } else if (!isValidEmail(email)) {
      emailError = "Please enter a valid email address.";
      hasError = true;
    }

    // PASSWORD CHECK
    if (password.isEmpty) {
      passwordError = "Password is required.";
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => loading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        Navigator.pushReplacementNamed(context, '/profile');
      } else {
        throw Exception("wrong_credentials");
      }
    } catch (e) {
      final isWrongCred =
          e.toString().toLowerCase().contains("invalid") ||
          e.toString().toLowerCase().contains("wrong") ||
          e.toString().toLowerCase().contains("credential");

      setState(() {
        passwordError = isWrongCred
            ? "Email or password is incorrect."
            : "Login failed. Please try again.";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // ===================== TOP PURPLE ARC =====================
          Container(
            height: 260,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6A47CE),
                  Color(0xFF3C2C71),
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
                        center: Alignment(0, -0.3),
                        radius: 0.7,
                        colors: [
                          Color(0x90B38CFF),
                          Color(0x003C2C71),
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
                      "Log In",
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

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // ===================== CONTENT CARD =====================
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                decoration: BoxDecoration(
                  color: const Color(0xFF181826),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Email",
                      style: TextStyle(
                        color: Color(0xFFBEBED3),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: emailController,
                      hint: "you@example.com",
                      error: emailError,
                      onChanged: (_) => setState(() => emailError = null),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      "Password",
                      style: TextStyle(
                        color: Color(0xFFBEBED3),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: passwordController,
                      hint: "********",
                      isPassword: true,
                      error: passwordError,
                      onChanged: (_) => setState(() => passwordError = null),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: loading ? null : loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C5CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          shadowColor: const Color(0xAA7C5CFF),
                          elevation: 10,
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Log In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== Input Field =====================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    String? error,
    bool isPassword = false,
    void Function(String)? onChanged,
  }) {
    return Focus(
      child: Builder(builder: (context) {
        final bool isFocused = Focus.of(context).hasFocus;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: const Color(0xFF121225),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isFocused
                      ? const Color(0xFF7C5CFF)
                      : const Color(0xFF2C284A),
                  width: isFocused ? 2 : 1.4,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      obscureText: isPassword && !showPassword,
                      onChanged: onChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(color: Colors.white38),
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
                        setState(() => showPassword = !showPassword);
                      },
                    ),
                ],
              ),
            ),

            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
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
      }),
    );
  }
}
