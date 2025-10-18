import 'package:flutter/material.dart';

class SetupExpensesScreen extends StatelessWidget {
  const SetupExpensesScreen({super.key});

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
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              LinearProgressIndicator(
                value: 0.75,
                color: const Color(0xFF7959F5),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 40),

              Center(
                child: Column(
                  children: [
                    Image.asset('assets/robot.png', height: 100),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E479B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "What are your fixed expenses?",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Rent 2000, Gym 200, Bills 500',
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
                    Navigator.pushNamed(context, '/setupBalance');
                  },
                  child: const Text('Next',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
