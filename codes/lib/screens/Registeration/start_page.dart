import 'package:flutter/material.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          // TOP GRADIENT AREA
          Container(
            width: double.infinity,
            height: 430,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(180),
                bottomRight: Radius.circular(180),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6A47CE), // top purple
                  Color(0xFF3C2C71), // bottom purple
                ],
              ),
            ),
            child: Stack(
              children: [
                // Soft center glow
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.10),
                          radius: 0.65,
                          colors: [
                            Color(0x90B38CFF), // lavender glow
                            Color(0x003C2C71),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // LOGO
                Align(
                  alignment: const Alignment(0, 0.15),
                  child: Image.asset(
                    'assets/images/surra_logo.png',
                    width: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // TITLE
                  const Text(
                    'Welcome to Surra!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Underline glow
                  Container(
                    width: 260,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8B66FF),
                          Color(0xFF633DDB),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x886A47CE),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SUBTITLE
                  const Text(
                    'Track your spending and build better\nhabits with ease.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFBEBED3),
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 55),

                  // SIGN UP BUTTON
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xAA7C5CFF),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Center(
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // LOG IN BUTTON
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121225),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF7C5CFF),
                        width: 2.4,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Center(
                          child: Text(
                            'Log In',
                            style: TextStyle(
                              color: Color(0xFFD1D1D8),
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
