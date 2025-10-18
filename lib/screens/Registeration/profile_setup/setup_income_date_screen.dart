import 'package:flutter/material.dart';
import 'shared_widgets.dart';

class SetupIncomeDateScreen extends StatefulWidget {
  const SetupIncomeDateScreen({super.key});

  @override
  State<SetupIncomeDateScreen> createState() => _SetupIncomeDateScreenState();
}

class _SetupIncomeDateScreenState extends State<SetupIncomeDateScreen> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      progress: 0.6,
      child: Column(
        children: [
          Image.asset('assets/robot.png', height: 100),
          const SizedBox(height: 20),
          questionBox("When do you receive your income?"),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF7959F5),
                        surface: Color(0xFF1D1B32),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E2C4A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                selectedDate == null
                    ? "Select date"
                    : "📅 ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
          const Spacer(),
          nextButton(context, '/setupExpenses'),
        ],
      ),
    );
  }
}
