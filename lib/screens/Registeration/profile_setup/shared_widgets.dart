import 'package:flutter/material.dart';

class SetupScaffold extends StatelessWidget {
  final Widget child;
  final double progress;

  const SetupScaffold({
    super.key,
    required this.child,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
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
                value: progress,
                color: const Color(0xFF7959F5),
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 40),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable widgets for questions and buttons
Widget questionBox(String text) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF4E479B),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    text,
    style: const TextStyle(color: Colors.white, fontSize: 16),
    textAlign: TextAlign.center,
  ),
);

InputDecoration inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFFB6B8B8)),
  filled: true,
  fillColor: const Color(0xFF2E2C4A),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(30),
    borderSide: BorderSide.none,
  ),
);

Widget nextButton(BuildContext context, String route) => SizedBox(
  width: double.infinity,
  height: 50,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF7959F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(33)),
    ),
    onPressed: () => Navigator.pushNamed(context, route),
    child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 18)),
  ),
);
