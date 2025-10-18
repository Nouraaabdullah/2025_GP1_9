import 'package:flutter/material.dart';

class SetupNameScreen extends StatelessWidget {
  const SetupNameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back arrow
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),

              // Progress bar
              LinearProgressIndicator(
                value: 0.25,
                color: const Color(0xFF7959F5),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 40),

              // Robot image
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/robot.png', // 👈 replace with your robot image
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E479B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "What's your name?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Input field
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: Color(0xFFB6B8B8)),
                  filled: true,
                  fillColor: const Color(0xFF2E2C4A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7959F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(33),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/setupIncome');
                  },
                  child: const Text(
                    'Next',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
