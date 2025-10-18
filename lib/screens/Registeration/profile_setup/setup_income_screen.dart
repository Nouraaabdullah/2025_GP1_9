import 'package:flutter/material.dart';
import 'shared_profile_data.dart'; // make sure this file exists

class SetupIncomeScreen extends StatefulWidget {
  const SetupIncomeScreen({super.key});

  @override
  State<SetupIncomeScreen> createState() => _SetupIncomeScreenState();
}

class _SetupIncomeScreenState extends State<SetupIncomeScreen> {
  final incomeController = TextEditingController();
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                Container(
                  height: 4,
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.1),
                ),
                Container(
                  height: 4,
                  width: MediaQuery.of(context).size.width * 0.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7959F5), Color(0xFFA27CFF)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 1),

                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7959F5).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "STEP 2 OF 4",
                      style: TextStyle(
                        color: Color(0xFFB8A8FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    "Monthly Income",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter your salary amount and the date you receive it",
                    style: TextStyle(
                      color: Color(0xFFB3B3C7),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),
                  const Text(
                    "Income Amount",
                    style: TextStyle(
                      color: Color(0xFFDADAF0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: incomeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter amount in SAR',
                      hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
                      filled: true,
                      fillColor: const Color(0xFF2A2550),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Color(0xFF7959F5), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "Date of Income",
                    style: TextStyle(
                      color: Color(0xFFDADAF0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2550),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'Select your payday'
                                : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: selectedDate == null
                                  ? Colors.grey[400]
                                  : Colors.white,
                            ),
                          ),
                          const Icon(Icons.calendar_today, color: Color(0xFFB8A8FF)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFFB8A8FF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF2E2C4A).withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Back"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7959F5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 6,
                            shadowColor: const Color(0xFF7959F5).withOpacity(0.4),
                          ),
                          onPressed: () {
                            if (incomeController.text.isNotEmpty && selectedDate != null) {
                              ProfileData.monthlyIncome = double.tryParse(incomeController.text);
                              ProfileData.payday = selectedDate!.day;
                              Navigator.pushNamed(context, '/setupExpenses');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter income and select payday'),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
