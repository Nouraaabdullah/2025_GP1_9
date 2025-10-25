import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupIncomeScreen extends StatefulWidget {
  const SetupIncomeScreen({super.key});

  @override
  State<SetupIncomeScreen> createState() => _SetupIncomeScreenState();
}

class _SetupIncomeScreenState extends State<SetupIncomeScreen> {
  final supabase = Supabase.instance.client;
  bool loading = false;

  final List<Map<String, dynamic>> incomes = [
    {
      'source': TextEditingController(),
      'amount': TextEditingController(),
      'day': null,
      'errors': <String, String?>{
        'source': null,
        'amount': null,
        'day': null,
      },
    }
  ];

  void addIncomeField() {
    setState(() {
      incomes.add({
        'source': TextEditingController(),
        'amount': TextEditingController(),
        'day': null,
        'errors': <String, String?>{
          'source': null,
          'amount': null,
          'day': null,
        },
      });
    });
  }

  void deleteIncomeField(int index) {
    if (index == 0) return;
    setState(() {
      incomes.removeAt(index);
    });
  }

  // ✅ Inline field validator
  bool _validateFields() {
    bool isValid = true;

    for (var i in incomes) {
      final errors = i['errors'] as Map<String, String?>;
      errors.updateAll((key, value) => null);

      if (i['source'].text.trim().isEmpty) {
        errors['source'] = "Required";
        isValid = false;
      }

      final amountText = i['amount'].text.trim();
      if (amountText.isEmpty) {
        errors['amount'] = "Required";
        isValid = false;
      } else if (double.tryParse(amountText) == null) {
        errors['amount'] = "Numbers only";
        isValid = false;
      }

      if (i['day'] == null) {
        errors['day'] = "Select payday";
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  Future<void> saveIncomesToSupabase() async {
    if (!_validateFields()) return;

    setState(() => loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("No logged-in user found");

      final profileResponse = await supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileResponse == null) throw Exception("User profile not found");
      final profileId = profileResponse['profile_id'];

      final incomeRecords = incomes.map((i) {
        return {
          'profile_id': profileId,
          'name': i['source'].text,
          'monthly_income': double.tryParse(i['amount'].text) ?? 0.0,
          'payday': i['day'],
          'is_primary': incomes.indexOf(i) == 0,
          'start_time': DateTime.now().toIso8601String(),
        };
      }).toList();

      await supabase.from('Fixed_Income').insert(incomeRecords);
      ProfileData.incomes = incomeRecords;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Income saved successfully!")),
      );

      Navigator.pushNamed(context, '/setupCategories');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving incomes: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child:
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );

  Widget buildIncomeCard(int index) {
    final income = incomes[index];
    final isPrimary = index == 0;
    final errors = income['errors'] as Map<String, String?>;

    return Card(
      color: const Color(0xFF2A2550),
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isPrimary ? const Color(0xFF7959F5) : Colors.white.withOpacity(0.1),
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== HEADER ====
            Row(
              children: [
                Text(
                  isPrimary
                      ? "Primary Income (Required)"
                      : "Additional Income ${index}",
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

            // ==== SOURCE ====
            TextField(
              controller: income['source'],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Income source (e.g., Salary)',
                hintStyle: TextStyle(color: Color(0xFFB0AFC5)),
                filled: true,
                fillColor: Color(0xFF1F1B3A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            if (errors['source'] != null) _errorText(errors['source']!),
            const SizedBox(height: 10),

            // ==== AMOUNT ====
            TextField(
              controller: income['amount'],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Amount (SAR)',
                hintStyle: TextStyle(color: Color(0xFFB0AFC5)),
                filled: true,
                fillColor: Color(0xFF1F1B3A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            if (errors['amount'] != null) _errorText(errors['amount']!),
            const SizedBox(height: 10),

            // ==== PAYDAY DROPDOWN ====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1B3A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: DropdownButton<int>(
                value: income['day'],
                dropdownColor: const Color(0xFF1F1B3A),
                isExpanded: true,
                hint: const Text('Select payday (1–31)',
                    style: TextStyle(color: Colors.white70)),
                icon:
                    const Icon(Icons.arrow_drop_down, color: Color(0xFFB8A8FF)),
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem<int>(
                    value: i + 1,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                onChanged: (val) => setState(() => income['day'] = val),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (errors['day'] != null) _errorText(errors['day']!),
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
                  Container(height: 4, width: double.infinity, color: Colors.white12),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF7959F5), Color(0xFFA27CFF)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ====== STEP INDICATOR ======
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Start with your primary income, then add any other sources if you have them.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 20),

              // ====== INCOME CARDS ======
              Expanded(
                child: ListView.builder(
                  itemCount: incomes.length,
                  itemBuilder: (context, index) => buildIncomeCard(index),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addIncomeField,
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFFB8A8FF)),
                  label: const Text(
                    "Add another income",
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
                      onPressed: loading ? null : saveIncomesToSupabase,
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
}
