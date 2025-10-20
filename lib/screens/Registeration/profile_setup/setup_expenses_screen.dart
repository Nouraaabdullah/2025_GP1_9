import 'package:flutter/material.dart';
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
      });
    });
  }

  void selectDate(int index) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7959F5),
              onPrimary: Colors.white,
              surface: Color(0xFF1D1B32),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => expenses[index]['dueDate'] = picked);
    }
  }
Future<void> saveExpensesToSupabase() async {
  // ✅ Validate all fields
  bool valid = expenses.every((e) =>
      e['name'].text.isNotEmpty &&
      e['amount'].text.isNotEmpty &&
      e['dueDate'] != null &&
      e['category'] != null &&
      (e['category'] != 'Custom' || e['customCategory'].text.isNotEmpty));

  if (!valid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please complete all fields.")),
    );
    return;
  }

  setState(() => loading = true);

  try {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("No logged-in user found.");

    // ✅ Step 1: Get profile_id
    final profileResponse = await supabase
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (profileResponse == null) throw Exception("User profile not found.");
    final profileId = profileResponse['profile_id'];

    // ✅ Step 2: Fetch all categories from Supabase
    final categoryResponse =
        await supabase.from('Category').select('category_id, name, type');

    final categoryMap = {
      for (var cat in categoryResponse)
        cat['name'].toString(): cat['category_id']
    };

    debugPrint("📋 Category Map: $categoryMap");

    // ✅ Step 3: Prepare expense records
    final expenseRecords = expenses.map((e) {
      final categoryName = e['category'] == 'Custom'
          ? e['customCategory'].text
          : e['category'];

      final categoryId = categoryMap[categoryName];

      return {
        'profile_id': profileId,
        'name': e['name'].text,
        'amount': double.tryParse(e['amount'].text) ?? 0.0,
        'due_date': e['dueDate'].day, // 🔹 matches int4 column
        'category_id': categoryId,
        'start_time': DateTime.now().toIso8601String(), // optional
        'end_time': null, // optional if allowed
      };
    }).toList();

    // ✅ Step 4: Insert into Fixed_Expense table
    await supabase.from('Fixed_Expense').insert(expenseRecords);
    debugPrint("✅ Expenses inserted successfully.");

    // ✅ Step 5: Save locally
    for (final e in expenses) {
      final categoryName = e['category'] == 'Custom'
          ? e['customCategory'].text
          : e['category'];

      ProfileData.addFixedExpense(
        name: e['name'].text,
        amount: double.tryParse(e['amount'].text) ?? 0.0,
        dueDate: e['dueDate'].day,
        category: categoryName,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Expenses saved successfully!")),
    );

    Navigator.pushNamed(context, '/setupBalance');
  } catch (e) {
    debugPrint("❌ Error saving expenses: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error saving expenses: $e")),
    );
  } finally {
    setState(() => loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final categoryNames =
        ProfileData.categories.map((c) => c['name'] as String).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.1),
                  ),
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
              const SizedBox(height: 30),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add your regular monthly expenses with their due dates and categories.",
                style: TextStyle(
                  color: Color(0xFFB3B3C7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: expense['name'],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                      'Expense name (e.g., Rent)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: expense['amount'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('SAR'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: expense['category'],
                            dropdownColor: const Color(0xFF2A2550),
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                _inputDecoration('Select category'),
                            items: [
                              ...categoryNames.map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              ),
                              const DropdownMenuItem(
                                value: 'Custom',
                                child: Text('Custom'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => expense['category'] = value),
                          ),

                          if (expense['category'] == 'Custom') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: expense['customCategory'],
                              style: const TextStyle(color: Colors.white),
                              decoration:
                                  _inputDecoration('Enter custom category name'),
                            ),
                          ],

                          const SizedBox(height: 12),

                          GestureDetector(
                            onTap: () => selectDate(index),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2550),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    expense['dueDate'] != null
                                        ? expense['dueDate']
                                            .toString()
                                            .split(' ')[0]
                                        : 'Select due date',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.calendar_today,
                                      color: Color(0xFFB8A8FF), size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          loading ? null : saveExpensesToSupabase,
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
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
      fillColor: const Color(0xFF2A2550),
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
