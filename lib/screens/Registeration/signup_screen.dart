import 'package:flutter/material.dart';
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

  // ===== Email/Password Sign-Up =====
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
      // ✅ 1. Create user in Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception("User creation failed.");

      // ✅ 2. Insert user profile
      await supabase.from('User_Profile').insert({
        'user_id': user.id,
        'email': email,
        'full_name': null,
        'current_balance': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created for ${user.email}")),
      );

      // ✅ 3. Navigate to setup flow
      Navigator.pushReplacementNamed(context, '/setupName');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error signing up: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // ===== Google Sign-In =====
  Future<void> signUpWithGoogle() async {
    setState(() => loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      // ✅ Supabase handles redirect back into app automatically
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Redirecting to Google Sign-In...")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181732),
      body: Stack(
        children: [
          // ===== BACKGROUND CIRCLES =====
          Positioned(
            top: -150,
            left: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: const BoxDecoration(
                color: Color(0xFF4E46B4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: const BoxDecoration(
                color: Color(0xFF322B78),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ===== MAIN CONTENT =====
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 230),
                  const Text(
                    "Create your\nAccount",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Sign up to manage your finances smarter 💜",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 60),

                  // ===== EMAIL =====
                  const Text(
                    "Email",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: emailController,
                    hintText: "you@example.com",
                    isPassword: false,
                  ),
                  const SizedBox(height: 25),

                  // ===== PASSWORD =====
                  const Text(
                    "Password",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: passwordController,
                    hintText: "********",
                    isPassword: true,
                  ),

                  const SizedBox(height: 45),

                  // ===== SIGN UP BUTTON =====
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: loading ? null : signUpUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C6FD6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                        shadowColor:
                            const Color(0xFF7C6FD6).withOpacity(0.4),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // // ===== GOOGLE SIGN IN =====
                  // SizedBox(
                  //   width: double.infinity,
                  //   height: 55,
                  //   child: OutlinedButton.icon(
                  //     onPressed: loading ? null : signUpWithGoogle,
                  //     icon: const Icon(
                  //       Icons.g_mobiledata,
                  //       color: Colors.white,
                  //       size: 28,
                  //     ),
                  //     label: const Text(
                  //       "Continue with Google",
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 16,
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: Colors.white54),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(30),
                  //       ),
                  //       backgroundColor: const Color(0xFF2C284A),
                  //     ),
                  //   ),
                  // ),

                  // const SizedBox(height: 25),

                  // ===== LOGIN LINK =====
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              color: Color(0xFFB19DFA),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Custom TextField =====
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isPassword,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2C284A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF9B7EE8),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
