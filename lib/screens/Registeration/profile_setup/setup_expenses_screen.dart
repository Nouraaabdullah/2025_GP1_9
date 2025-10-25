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

  // ✅ Validation: only checks filled rows
  bool _validateFields() {
    bool isValid = true;

    for (var e in expenses) {
      final errors = e['errors'] as Map<String, String?>;
      errors.updateAll((key, value) => null);

      // skip if all fields empty
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

      // ✅ Filter out empty rows
      final filledExpenses = expenses.where((e) =>
          e['name'].text.trim().isNotEmpty ||
          e['amount'].text.trim().isNotEmpty ||
          e['dueDate'] != null ||
          e['category'] != null).toList();

      // ✅ If none filled, skip saving and move on
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
          'start_time': DateTime.now().toIso8601String(),
          'end_time': null,
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

  // ✅ Expense Card Widget
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
            // ==== TITLE ====
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

            // ==== NAME ====
            TextField(
              controller: expense['name'],
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Expense name (e.g., Rent)'),
            ),
            if (errors['name'] != null) _errorText(errors['name']!),
            const SizedBox(height: 12),

            // ==== AMOUNT ====
            TextField(
              controller: expense['amount'],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Amount (SAR)'),
            ),
            if (errors['amount'] != null) _errorText(errors['amount']!),
            const SizedBox(height: 12),

            // ==== CATEGORY ====
            DropdownButtonFormField<String>(
              value: expense['category'],
              dropdownColor: const Color(0xFF2A2550),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: const Color(0xFFB8A8FF),
              decoration: _inputDecoration('Select category'),
              items: [
                ...categoryNames.map(
                  (cat) => DropdownMenuItem(
                    value: cat,
                    child:
                        Text(cat, style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const DropdownMenuItem(
                  value: 'Custom',
                  child:
                      Text('Custom', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) => setState(() => expense['category'] = value),
            ),
            if (errors['category'] != null) _errorText(errors['category']!),

            if (expense['category'] == 'Custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: expense['customCategory'],
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Enter custom category name'),
              ),
              if (errors['customCategory'] != null)
                _errorText(errors['customCategory']!),
            ],
            const SizedBox(height: 12),

            // ==== DUE DATE (Dropdown 1–31) ====
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1B3A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: DropdownButton<int>(
                value: expense['dueDate'],
                dropdownColor: const Color(0xFF1F1B3A),
                isExpanded: true,
                hint: const Text(
                  'Select due day (1–31)',
                  style: TextStyle(color: Colors.white70),
                ),
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFFB8A8FF)),
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem<int>(
                    value: i + 1,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => expense['dueDate'] = val),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (errors['dueDate'] != null) _errorText(errors['dueDate']!),
          ],
        ),
      ),
    );
  }

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child:
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
              // ===== PROGRESS BAR =====
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

              // ===== STEP INDICATOR =====
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor:
                            const Color(0xFF7959F5).withOpacity(0.4),
                      ),
                      onPressed: loading ? null : saveExpensesToSupabase,
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
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
