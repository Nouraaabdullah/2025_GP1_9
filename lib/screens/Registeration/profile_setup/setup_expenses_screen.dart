import 'package:flutter/material.dart';
import 'shared_profile_data.dart';
class SetupExpensesScreen extends StatefulWidget {
  const SetupExpensesScreen({super.key});


  @override
  State<SetupExpensesScreen> createState() => _SetupExpensesScreenState();
}

class _SetupExpensesScreenState extends State<SetupExpensesScreen> {
  final List<Map<String, dynamic>> expenses = [
    {'name': TextEditingController(), 'amount': TextEditingController(), 'dueDate': null}
  ];

  void addExpenseField() {
    setState(() {
      expenses.add({'name': TextEditingController(), 'amount': TextEditingController(), 'dueDate': null});
    });
  }

  void selectDate(int index) async {
    DateTime? pickedDate = await showDatePicker(
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

    if (pickedDate != null) {
      setState(() {
        expenses[index]['dueDate'] = pickedDate;
      });
    }
  }

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
              // Progress bar
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, color: Colors.white.withOpacity(0.1)),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.75,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF7959F5), Color(0xFFA27CFF)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Step indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7959F5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "STEP 3 OF 4",
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
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add your regular monthly expenses and due dates",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 20),

              // 🧾 Scrollable list of all expense fields
              Expanded(
                child: ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: expense['name'],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Expense name (e.g., Rent)',
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: expense['amount'],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'SAR',
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
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => selectDate(index),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2550),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    expense['dueDate'] != null
                                        ? expense['dueDate'].toString().split(' ')[0]
                                        : 'Select due date',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.calendar_today, color: Color(0xFFB8A8FF), size: 18),
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
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFB8A8FF)),
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
                        backgroundColor: const Color(0xFF2E2C4A).withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                        shadowColor: const Color(0xFF7959F5).withOpacity(0.4),
                      ),
                      onPressed: () {
  // Save entered expenses into ProfileData
  ProfileData.fixedExpenses = expenses.map((e) => {
    'name': e['name'].text,
    'amount': double.tryParse(e['amount'].text) ?? 0.0,
    'dueDate': e['dueDate'] != null
        ? e['dueDate'].toString().split(' ')[0]
        : null,
  }).toList();

  Navigator.pushNamed(context, '/setupCategories');
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
            ],
          ),
        ),
      ),
    );
  }
}
