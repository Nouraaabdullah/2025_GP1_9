import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupIncomeScreen extends StatefulWidget {
  const SetupIncomeScreen({super.key});

  @override
  State<SetupIncomeScreen> createState() => _SetupIncomeScreenState();
}

class _SetupIncomeScreenState extends State<SetupIncomeScreen> {
  final List<Map<String, dynamic>> incomes = [
    {'source': TextEditingController(), 'amount': TextEditingController(), 'date': null}
  ];

  final supabase = Supabase.instance.client;
  bool loading = false;

  void addIncomeField() {
    setState(() {
      incomes.add({'source': TextEditingController(), 'amount': TextEditingController(), 'date': null});
    });
  }

  void deleteIncomeField(int index) {
    if (index == 0) return; // can't delete primary income
    setState(() {
      incomes.removeAt(index);
    });
  }

  void selectDate(int index) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
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
      setState(() => incomes[index]['date'] = picked);
    }
  }

  Future<void> saveIncomesToSupabase() async {
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("No logged-in user found");

      // ✅ Require primary income
      if (incomes[0]['source'].text.isEmpty ||
          incomes[0]['amount'].text.isEmpty ||
          incomes[0]['date'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in your primary income details.")),
        );
        setState(() => loading = false);
        return;
      }

      // ✅ Get profile ID
      final profileResponse = await supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileResponse == null) throw Exception("User profile not found.");
      final profileId = profileResponse['profile_id'];

      // ✅ Prepare records
      final incomeRecords = incomes
          .where((e) =>
              e['source'].text.isNotEmpty &&
              e['amount'].text.isNotEmpty &&
              e['date'] != null)
          .map((e) {
        return {
          'profile_id': profileId,
          'name': e['source'].text,
          'monthly_income': double.tryParse(e['amount'].text) ?? 0.0,
          'payday': e['date']?.day,
          'start_time': e['date']?.toIso8601String(),
          'is_primary': incomes.indexOf(e) == 0, // ✅ mark first as primary
        };
      }).toList();

      await supabase.from('Fixed_Income').insert(incomeRecords);
      ProfileData.incomes = incomeRecords;

Navigator.pushNamed(context, '/setupCategories');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving incomes: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget buildIncomeCard(int index) {
    final income = incomes[index];
    final isPrimary = index == 0;

    return Card(
      color: const Color(0xFF2A2550),
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPrimary ? const Color(0xFF7959F5) : Colors.white.withOpacity(0.1),
          width: isPrimary ? 2 : 1,
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
                  isPrimary ? "Primary Income (Required)" : "Additional Income ${index}",
                  style: TextStyle(
                    color: isPrimary ? const Color(0xFFB8A8FF) : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!isPrimary)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => deleteIncomeField(index),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: income['source'],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Income source (e.g., Salary)',
                hintStyle: TextStyle(color: Color(0xFFB0AFC5)),
                filled: true,
                fillColor: Color(0xFF1F1B3A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: income['amount'],
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Amount (SAR)',
                hintStyle: TextStyle(color: Color(0xFFB0AFC5)),
                filled: true,
                fillColor: Color(0xFF1F1B3A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => selectDate(index),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1B3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      income['date'] != null
                          ? income['date'].toString().split(' ')[0]
                          : 'Select payday',
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
      ),
    );
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
              // ====== PROGRESS BAR ======
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, color: Colors.white.withOpacity(0.1)),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF7959F5), Color(0xFFA27CFF)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ====== STEP INDICATOR ======
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7959F5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "STEP 2 OF 6",
                  style: TextStyle(
                    color: Color(0xFFB8A8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ====== TITLE ======
              const Text(
                "Monthly Income",
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Start with your primary income, then add any other sources if you have them.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 20),

              // ====== INCOME LIST ======
              Expanded(
                child: ListView.builder(
                  itemCount: incomes.length,
                  itemBuilder: (context, index) => buildIncomeCard(index),
                ),
              ),

              // ====== ADD BUTTON ======
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addIncomeField,
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFB8A8FF)),
                  label: const Text("Add another income",
                      style: TextStyle(color: Color(0xFFB8A8FF))),
                ),
              ),

              const SizedBox(height: 20),

              // ====== BUTTONS ======
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
                      onPressed: loading ? null : saveIncomesToSupabase,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
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
}
