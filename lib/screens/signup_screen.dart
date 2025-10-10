import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // For Google icon (add to pubspec)

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== Gradient Circles (same as login) =====
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
                const SizedBox(height: 140),
                const Text(
                  'Create your\nAccount',
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
                  'Sign up to manage your finances smarter 💜',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6B8B8),
                    fontSize: 18,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 50),

                // ===== NAME FIELD =====
                const Text(
                  'Full Name',
                  style: TextStyle(
                    color: Color(0xFFFCFFFF),
                    fontSize: 15,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 8),
                _textField('Enter your full name'),
                const SizedBox(height: 24),

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
                _textField('example@email.com'),
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
                _textField('••••••••', obscure: true),
                const SizedBox(height: 40),

                // ===== SIGN UP BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/setupName');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7959F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ===== Google SSO Button =====
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: implement Google Sign-In logic here
                    },
                    icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(33),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== LOG IN LINK =====
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFFFCFFFF),
                            fontSize: 15,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        TextSpan(
                          text: 'Log In',
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
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helper widget for text fields =====
  Widget _textField(String hint, {bool obscure = false}) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2C4A),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB6B8B8)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
