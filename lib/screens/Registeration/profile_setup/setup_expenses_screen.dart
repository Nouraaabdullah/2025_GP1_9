import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupExpensesScreen extends StatefulWidget {
  const SetupExpensesScreen({super.key});

  @override
  State<SetupExpensesScreen> createState() => _SetupExpensesScreenState();
}

class _SetupExpensesScreenState extends State<SetupExpensesScreen> {
  final supabase = Supabase.instance.client;
  bool loading = false;
  bool _dueDateConfirmed = false; // ✅ To ensure user confirms once

  final List<Map<String, dynamic>> expenses = [
    {
      'name': TextEditingController(),
      'amount': TextEditingController(),
      'dueDate': null,
      'category': null,
      'customCategory': TextEditingController(),
      'errors': <String, String?>{
        'name': null,
        'amount': null,
        'dueDate': null,
        'category': null,
        'customCategory': null,
      }
    }
  ];

  void addExpenseField() {
    setState(() {
      expenses.add({
        'name': TextEditingController(),
        'amount': TextEditingController(),
        'dueDate': null,
        'category': null,
        'customCategory': TextEditingController(),
        'errors': <String, String?>{
          'name': null,
          'amount': null,
          'dueDate': null,
          'category': null,
          'customCategory': null,
        }
      });
    });
  }

  bool _validateFields() {
    bool isValid = true;

    for (var e in expenses) {
      final errors = e['errors'] as Map<String, String?>;
      errors.updateAll((key, value) => null);

      if (e['name'].text.trim().isEmpty &&
          e['amount'].text.trim().isEmpty &&
          e['dueDate'] == null &&
          e['category'] == null &&
          e['customCategory'].text.trim().isEmpty) {
        continue;
      }

      if (e['name'].text.trim().isEmpty) {
        errors['name'] = "Required";
        isValid = false;
      }

      final amountText = e['amount'].text.trim();
      if (amountText.isNotEmpty && double.tryParse(amountText) == null) {
        errors['amount'] = "Enter numbers only";
        isValid = false;
      }

      if (e['category'] == 'Custom' &&
          e['customCategory'].text.trim().isEmpty) {
        errors['customCategory'] = "Enter name";
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  Future<void> saveExpensesToSupabase() async {
    if (!_validateFields()) return;

    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("No logged-in user found.");

      final profileResponse = await supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileResponse == null) throw Exception("User profile not found.");
      final profileId = profileResponse['profile_id'];

      final filledExpenses = expenses.where((e) =>
          e['name'].text.trim().isNotEmpty ||
          e['amount'].text.trim().isNotEmpty ||
          e['dueDate'] != null ||
          e['category'] != null).toList();

      if (filledExpenses.isEmpty) {
        Navigator.pushNamed(context, '/setupBalance');
        return;
      }

      final categoryResponse =
          await supabase.from('Category').select('category_id, name');
      final categoryMap = {
        for (var cat in categoryResponse)
          cat['name'].toString(): cat['category_id']
      };

      final today = DateTime.now();
      final formattedDate =
          "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final expenseRecords = filledExpenses.map((e) {
        final categoryName = e['category'] == 'Custom'
            ? e['customCategory'].text
            : e['category'];
        final categoryId = categoryMap[categoryName];
        return {
          'profile_id': profileId,
          'name': e['name'].text,
          'amount': double.tryParse(e['amount'].text) ?? 0.0,
          'due_date': e['dueDate'],
          'category_id': categoryId,
          'start_time': today.toIso8601String(),
          'end_time': null,
          'last_update': formattedDate, // ✅ added field
        };
      }).toList();

      if (expenseRecords.isNotEmpty) {
        await supabase.from('Fixed_Expense').insert(expenseRecords);
      }

      for (final e in filledExpenses) {
        final categoryName = e['category'] == 'Custom'
            ? e['customCategory'].text
            : e['category'];
        ProfileData.addFixedExpense(
          name: e['name'].text,
          amount: double.tryParse(e['amount'].text) ?? 0.0,
          dueDate: e['dueDate'],
          category: categoryName,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Expenses saved successfully!")),
      );
      Navigator.pushNamed(context, '/setupBalance');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  // ✅ Confirmation Dialog
  Future<bool> _confirmDueDateLock(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2B2B48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Confirm Due Date',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Once you set the due date for this month, you cannot change it until the next month.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF704EF4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget buildExpenseCard(int index) {
    final expense = expenses[index];
    final errors = expense['errors'] as Map<String, String?>;
    final categoryNames =
        ProfileData.categories.map((c) => c['name'] as String).toList();

    return Card(
      color: const Color(0xFF2A2550),
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF7959F5).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Expense ${index + 1}",
                  style: const TextStyle(
                      color: Color(0xFFB8A8FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (index > 0)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(() => expenses.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: expense['name'],
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Expense name (e.g., Rent)'),
            ),
            if (errors['name'] != null) _errorText(errors['name']!),
            const SizedBox(height: 12),

            TextField(
              controller: expense['amount'],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Amount (SAR)'),
            ),
            if (errors['amount'] != null) _errorText(errors['amount']!),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: expense['category'],
              dropdownColor: const Color(0xFF2A2550),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: const Color(0xFFB8A8FF),
              decoration: _inputDecoration('Select category').copyWith(
                hintStyle:
                    const TextStyle(color: Color(0xFFB0AFC5)), // grey hint
              ),
              items: ProfileData.categories
                  .map<DropdownMenuItem<String>>((c) {
                    final name = c['name'] as String? ?? '';
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name,
                          style: const TextStyle(color: Colors.white)),
                    );
                  })
                  .toList(),
              onChanged: (value) => setState(() => expense['category'] = value),
            ),
            if (errors['category'] != null) _errorText(errors['category']!),

            TextField(
              controller: TextEditingController(
                text: expense['dueDate']?.toString() ?? '',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Enter due day (1–31)'),
              onChanged: (val) {
                final number = int.tryParse(val);
                setState(() {
                  if (number != null && number >= 1 && number <= 31) {
                    expense['dueDate'] = number;
                    (expense['errors'] as Map<String, String?>)['dueDate'] = null;
                  } else {
                    expense['dueDate'] = null;
                    (expense['errors'] as Map<String, String?>)['dueDate'] =
                        "Enter a valid day (1–31)";
                  }
                });
              },
            ),
            if (errors['dueDate'] != null) _errorText(errors['dueDate']!),
          ],
        ),
      ),
    );
  }

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(text,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );

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
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, color: Colors.white12),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.85,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7959F5), Color(0xFFA27CFF)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7959F5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "STEP 5 OF 6",
                  style: TextStyle(
                    color: Color(0xFFB8A8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Fixed Expenses",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add your regular monthly expenses, due dates, and categories (optional).",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 15),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) => buildExpenseCard(index),
                ),
              ),
              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addExpenseField,
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFFB8A8FF)),
                  label: const Text(
                    "Add another expense",
                    style: TextStyle(color: Color(0xFFB8A8FF)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
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
                            borderRadius: BorderRadius.circular(12)),
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
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor:
                            const Color(0xFF7959F5).withOpacity(0.4),
                      ),
                      onPressed: loading
                          ? null
                          : () async {
                              if (!_dueDateConfirmed) {
                                final confirmed =
                                    await _confirmDueDateLock(context);
                                if (!confirmed) return;
                                _dueDateConfirmed = true;
                              }
                              await saveExpensesToSupabase();
                            },
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Continue",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
      filled: true,
      fillColor: const Color(0xFF1F1B3A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF7959F5), width: 2),
      ),
    );
  }
}
