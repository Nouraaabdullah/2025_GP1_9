import 'package:flutter/material.dart';
import 'shared_profile_data.dart';

class SetupBalanceScreen extends StatelessWidget {
  const SetupBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final balanceController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Progress bar
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
                  width: MediaQuery.of(context).size.width,
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
                      "STEP 4 OF 4",
                      style: TextStyle(
                        color: Color(0xFFB8A8FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    "Current Balance",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This helps us calculate your financial overview",
                    style: TextStyle(
                      color: Color(0xFFB3B3C7),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),
                  const Text(
                    "Balance Amount",
                    style: TextStyle(
                      color: Color(0xFFDADAF0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
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
                            backgroundColor:
                                const Color(0xFF2E2C4A).withOpacity(0.5),
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
                            shadowColor:
                                const Color(0xFF7959F5).withOpacity(0.4),
                          ),
                          onPressed: () {
                            final balanceText = balanceController.text.trim();
                            if (balanceText.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Please enter your current balance'),
                                ),
                              );
                              return;
                            }

                            ProfileData.currentBalance =
                                double.tryParse(balanceText) ?? 0.0;

                            final totalExpenses = ProfileData.fixedExpenses.fold<double>(
                              0.0,
                              (sum, e) => sum + (e['amount'] ?? 0.0),
                            );

                            final income = ProfileData.monthlyIncome ?? 0.0;

                            if (income > 0 && totalExpenses > income) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF2A2550),
                                  title: const Text(
                                    "⚠ Budget Exceeded",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    "Your total category limits (SAR ${totalExpenses.toStringAsFixed(2)}) "
                                    "exceed your monthly income (SAR ${income.toStringAsFixed(2)}).\n\n"
                                    "Would you like to continue or go back and adjust your limits?",
                                    style: const TextStyle(
                                      color: Color(0xFFB0AFC5),
                                      fontSize: 14,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pop(context); // go back to expenses
                                      },
                                      child: const Text(
                                        "Adjust Limits",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(
                                            context, '/setupComplete');
                                      },
                                      child: const Text(
                                        "Continue",
                                        style: TextStyle(color: Color(0xFFB8A8FF)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Navigator.pushNamed(context, '/setupComplete');
                            }
                          },
                          child: const Text(
                            "Finish Setup",
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
