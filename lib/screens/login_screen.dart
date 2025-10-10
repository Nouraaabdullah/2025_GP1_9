import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BACKGROUND SHAPES =====
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

            // ===== MAIN CONTENT =====
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              children: [
                const SizedBox(height: 160),
                const Text(
                  'Log in to your\nAccount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFCFFFF),
                    fontSize: 32,
                    fontFamily: 'Roboto',
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
                  'Please enter your credentials to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6B8B8),
                    fontSize: 18,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 60),

                // ===== EMAIL FIELD =====
                const Text(
                  'Email',
                  style: TextStyle(
                    color: Color(0xFFFCFFFF),
                    fontSize: 15,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2C4A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'abhixyzxyz@gmail.com',
                    style: TextStyle(
                      color: Color(0xFFB6B8B8),
                      fontSize: 15,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== PASSWORD FIELD =====
                const Text(
                  'Password',
                  style: TextStyle(
                    color: Color(0xFFFCFFFF),
                    fontSize: 15,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2C4A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    '********',
                    style: TextStyle(
                      color: Color(0xFFB6B8B8),
                      fontSize: 20,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // ===== LOGIN BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 👇 Navigate to profile page after login
                      Navigator.pushReplacementNamed(context, '/profile');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7959F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ===== SIGN-UP TEXT =====
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/welcome');
                  },
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Don’t have an account? ',
                          style: TextStyle(
                            color: Color(0xFFFCFFFF),
                            fontSize: 15,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                            color: Color(0xFF7959F5),
                            fontSize: 15,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
