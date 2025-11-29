import 'package:flutter/material.dart';
import 'shared_profile_data.dart';

class SetupBalanceScreen extends StatefulWidget {
  const SetupBalanceScreen({super.key});

  @override
  State<SetupBalanceScreen> createState() => _SetupBalanceScreenState();
}

class _SetupBalanceScreenState extends State<SetupBalanceScreen> {
  final balanceController = TextEditingController();
  bool loading = false;
  String? errorText;

  Widget _errorTextWidget(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    double totalIncome = ProfileData.incomes.fold(
      0.0,
      (sum, income) => sum + (income['amount'] ?? 0.0),
    );

    double totalCategoryLimits = ProfileData.categories.fold(
      0.0,
      (sum, c) => sum + (c['limit'] ?? 0.0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Column(
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
                    width: MediaQuery.of(context).size.width * 0.95,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7959F5).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "STEP 6 OF 6",
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
                      "This helps us calculate your financial overview.",
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
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Enter amount in SAR',
                        hintStyle:
                            const TextStyle(color: Color(0xFFB0AFC5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2550),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                          borderSide:
                              BorderSide(color: Color(0xFF7959F5), width: 2),
                        ),
                      ),
                    ),
                    if (errorText != null) _errorTextWidget(errorText!),
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
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.3)),
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  const Color(0xFF2E2C4A).withOpacity(0.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0xFF7959F5)
                                  .withOpacity(0.4),
                            ),
                            onPressed: loading
                                ? null
                                : () => _saveBalance(
                                    context,
                                    totalIncome,
                                    totalCategoryLimits,
                                  ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
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
      ),
    );
  }

  // ---------------- SAVE BALANCE LOCALLY ---------------- //

  Future<void> _saveBalance(BuildContext context, double totalIncome,
      double totalCategoryLimits) async {
    final balanceText = balanceController.text.trim();

    if (balanceText.isEmpty) {
      setState(() => errorText = "Required");
      return;
    } else if (double.tryParse(balanceText) == null) {
      setState(() => errorText = "Enter numbers only");
      return;
    } else {
      setState(() => errorText = null);
    }

    setState(() => loading = true);
    final balanceValue = double.tryParse(balanceText) ?? 0.0;

    // Save locally ONLY
    ProfileData.currentBalance = balanceValue;

    // ----- Show warning if limits exceed income -----
    if (totalIncome > 0 && totalCategoryLimits > totalIncome) {
      final exceeded = totalCategoryLimits - totalIncome;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2550),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("⚠ Budget Exceeded",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            "Your total category limits (SAR ${totalCategoryLimits.toStringAsFixed(2)}) "
            "exceed your total income (SAR ${totalIncome.toStringAsFixed(2)}).\n\n"
            "You’ve exceeded by SAR ${exceeded.toStringAsFixed(2)}.\n\n"
            "Would you like to adjust your limits or continue?",
            style: const TextStyle(color: Color(0xFFB0AFC5), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/setupFixedCategory');
              },
              child: const Text("Adjust Limits",
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/setupComplete');
              },
              child: const Text("Continue",
                  style: TextStyle(color: Color(0xFFB8A8FF))),
            ),
          ],
        ),
      );
    } else {
      Navigator.pushNamed(context, '/setupComplete');
    }

    setState(() => loading = false);
  }
}
