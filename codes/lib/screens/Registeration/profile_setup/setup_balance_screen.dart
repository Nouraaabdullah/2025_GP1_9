import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupBalanceScreen extends StatefulWidget {
  const SetupBalanceScreen({super.key});

  @override
  State<SetupBalanceScreen> createState() => _SetupBalanceScreenState();
}

class _SetupBalanceScreenState extends State<SetupBalanceScreen> {
  final supabase = Supabase.instance.client;
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

  // ✅ Function to apply today’s fixed incomes & expenses after setting balance
  Future<void> _applyTodayFixedTransactions(String profileId) async {
    final today = DateTime.now().day;
    double balance = double.tryParse(balanceController.text.trim()) ?? 0.0;

    // Fetch active incomes and expenses
    final incomes = await supabase
        .from('Fixed_Income')
        .select('income_id, monthly_income, payday, is_transacted, end_time')
        .eq('profile_id', profileId)
        .filter('end_time', 'is', null);

    final expenses = await supabase
        .from('Fixed_Expense')
        .select('expense_id, amount, due_date, is_transacted, end_time')
        .eq('profile_id', profileId)
        .filter('end_time', 'is', null);

    // Apply incomes
    for (final inc in incomes) {
      final int? payday = inc['payday'] as int?;
      final bool transacted = (inc['is_transacted'] ?? false) as bool;
      final double amount = (inc['monthly_income'] ?? 0.0).toDouble();

      if (payday == today && !transacted && amount != 0) {
        balance += amount;
        await supabase
            .from('Fixed_Income')
            .update({'is_transacted': true})
            .eq('income_id', inc['income_id']);
      }
    }

    // Apply expenses
    for (final exp in expenses) {
      final int? due = exp['due_date'] as int?;
      final bool transacted = (exp['is_transacted'] ?? false) as bool;
      final double amount = (exp['amount'] ?? 0.0).toDouble();

      if (due == today && !transacted && amount != 0) {
        balance -= amount;
        await supabase
            .from('Fixed_Expense')
            .update({'is_transacted': true})
            .eq('expense_id', exp['expense_id']);
      }
    }

    // Update balance in User_Profile
    await supabase
        .from('User_Profile')
        .update({'current_balance': balance})
        .eq('profile_id', profileId);

    ProfileData.currentBalance = balance;
  }

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
                                : () => saveBalance(context, totalIncome,
                                    totalCategoryLimits),
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

  Future<void> saveBalance(
      BuildContext context, double totalIncome, double totalCategoryLimits) async {
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

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("No user found.");

      final profileResponse = await supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileResponse == null) throw Exception("User profile not found.");
      final profileId = profileResponse['profile_id'];

      // ✅ Save base balance first
      await supabase
          .from('User_Profile')
          .update({'current_balance': balanceValue})
          .eq('profile_id', profileId);

      ProfileData.currentBalance = balanceValue;

      // ✅ Apply today’s incomes/expenses after saving
      await _applyTodayFixedTransactions(profileId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Balance saved successfully!')),
      );

      // ⚠ Category limit vs income warning
      if (totalIncome > 0 && totalCategoryLimits > totalIncome) {
        final exceeded = totalCategoryLimits - totalIncome;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2550),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("⚠ Budget Exceeded",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              "Your total category limits (SAR ${totalCategoryLimits.toStringAsFixed(2)}) "
              "exceed your total income (SAR ${totalIncome.toStringAsFixed(2)}).\n\n"
              "You’ve exceeded by SAR ${exceeded.toStringAsFixed(2)}.\n\n"
              "Would you like to adjust your limits or continue?",
              style:
                  const TextStyle(color: Color(0xFFB0AFC5), fontSize: 14),
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
    } catch (e) {
      debugPrint("❌ Error updating balance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating balance: $e')),
      );
    } finally {
      setState(() => loading = false);
    }
  }
}
