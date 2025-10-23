import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool loading = false;

  Future<void> signUpUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // 1️⃣ Create user in Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception("User creation failed.");
      }

      debugPrint("✅ User created in Auth: ${user.id}");

      // 2️⃣ Insert user profile in User_Profile table
      // Since RLS is disabled, no need for policies.
      final insertResponse = await supabase.from('User_Profile').insert({
        'user_id': user.id,
        'email': email,
        'full_name': null, // user will fill this in setup flow
        'current_balance': 0,
        'hashed_password': null,
      });

      debugPrint("✅ Profile inserted: $insertResponse");

      // 3️⃣ Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created for ${user.email}")),
      );

      // 4️⃣ Navigate to next setup page
      Navigator.pushReplacementNamed(context, '/setupName');
    } catch (e) {
      debugPrint("❌ Signup Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error signing up: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Stack(
          children: [
            // === Background Layers ===
            Positioned(
              left: -5,
              top: 0,
              child: Container(
                width: 440,
                height: 403,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F1B52),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -279,
              top: -255,
              child: Container(
                width: 627,
                height: 627,
                decoration: const BoxDecoration(
                  color: Color(0xFF322B78),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -162,
              top: -138,
              child: Container(
                width: 393,
                height: 393,
                decoration: const BoxDecoration(
                  color: Color(0xFF4E479B),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // === Main Content ===
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              children: [
                const SizedBox(height: 140),
                const Text(
                  'Create your\nAccount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFCFFFF),
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 12,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign up to manage your finances smarter 💜',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6B8B8),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 50),

                // === Email Field ===
                const Text('Email',
                    style: TextStyle(color: Color(0xFFFCFFFF), fontSize: 15)),
                const SizedBox(height: 8),
                FocusedTextField(
                    controller: emailController, hint: 'example@email.com'),
                const SizedBox(height: 24),

                // === Password Field ===
                const Text('Password',
                    style: TextStyle(color: Color(0xFFFCFFFF), fontSize: 15)),
                const SizedBox(height: 8),
                FocusedTextField(
                    controller: passwordController,
                    hint: '••••••••',
                    obscure: true),
                const SizedBox(height: 40),

                // === Sign Up Button ===
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : signUpUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7959F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // // === Google Sign-In Placeholder ===
                // SizedBox(
                //   width: double.infinity,
                //   height: 50,
                //   child: OutlinedButton.icon(
                //     onPressed: () {},
                //     icon: const FaIcon(FontAwesomeIcons.google,
                //         color: Colors.white, size: 18),
                //     label: const Text(
                //       'Continue with Google',
                //       style: TextStyle(color: Colors.white, fontSize: 16),
                //     ),
                //     style: OutlinedButton.styleFrom(
                //       side: const BorderSide(color: Colors.white54),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(33),
                //       ),
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 24),

                // === Redirect to Login ===
                GestureDetector(
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: Color(0xFF7959F5),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === Reusable Focused TextField Widget ===
class FocusedTextField extends StatefulWidget {
  final String hint;
  final bool obscure;
  final TextEditingController controller;

  const FocusedTextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    super.key,
  });

  @override
  State<FocusedTextField> createState() => _FocusedTextFieldState();
}

class _FocusedTextFieldState extends State<FocusedTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2C4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? const Color(0xFF7959F5) : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Color(0xFFB6B8B8)),
          border: InputBorder.none,
        ),
        cursorColor: const Color(0xFF7959F5),
      ),
    );
  }
}
