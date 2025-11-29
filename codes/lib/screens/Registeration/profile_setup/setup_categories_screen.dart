import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_edit_category_page.dart';
import 'shared_profile_data.dart';

class SetupCategoriesScreen extends StatefulWidget {
  const SetupCategoriesScreen({super.key});

  @override
  State<SetupCategoriesScreen> createState() => _SetupCategoriesScreenState();
}

class _SetupCategoriesScreenState extends State<SetupCategoriesScreen> {
  final supabase = Supabase.instance.client;
  bool loading = false;

  // ✅ Full list of default fixed categories
  final List<Map<String, dynamic>> fixedCategories = [
    {
      'name': 'Groceries',
      'icon': Icons.shopping_cart,
      'color': const Color(0xFFFFA726),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
    {
      'name': 'Transport',
      'icon': Icons.directions_car,
      'color': const Color(0xFF42A5F5),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
    {
      'name': 'Utilities',
      'icon': Icons.lightbulb,
      'color': const Color(0xFF7E57C2),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
    {
      'name': 'Entertainment',
      'icon': Icons.sports_esports,
      'color': const Color(0xFFEC407A),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
    {
      'name': 'Health',
      'icon': Icons.local_hospital,
      'color': const Color(0xFF66BB6A),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
    {
      'name': 'Other',
      'icon': Icons.category,
      'color': const Color(0xFFBDBDBD),
      'type': 'Fixed',
      'limit': TextEditingController(),
    },
  ];

  final List<Map<String, dynamic>> customCategories = [];

  // ✅ Validation for duplicate name/color
  bool _isCategoryValid(String name, Color color) {
    final lowerName = name.trim().toLowerCase();

    final fixedNameExists = fixedCategories.any(
      (c) => (c['name'] as String).toLowerCase() == lowerName,
    );

    final fixedColorExists = fixedCategories.any(
      (c) => c['color'].value == color.value,
    );

    final customNameExists = customCategories.any(
      (c) => (c['name'] as String).toLowerCase() == lowerName,
    );

    final customColorExists = customCategories.any(
      (c) => c['color'].value == color.value,
    );

    if (fixedNameExists || customNameExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Category name already exists."),
          backgroundColor:  Color.fromARGB(255, 128, 120, 120),
        ),
      );
      return false;
    }

    if (fixedColorExists || customColorExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Category color already in use."),
          backgroundColor: Color.fromARGB(255, 128, 120, 120),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> addCustomCategory() async {
    final usedColors = [
      ...fixedCategories.map((c) => c['color'].toString()),
      ...customCategories.map((c) => c['color'].toString())
    ];

    final newCategory = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryPage(usedColors: usedColors),
      ),
    );

    if (newCategory != null && newCategory is Map<String, dynamic>) {
      final name = newCategory['name'] as String;
      final color = newCategory['color'] as Color;

      if (_isCategoryValid(name, color)) {
        setState(() {
          newCategory['limit'] = TextEditingController();
          customCategories.add(newCategory);
        });
      }
    }
  }

  void deleteCustomCategory(int index) {
    setState(() {
      customCategories.removeAt(index);
    });
  }

  // ✅ Validate numeric input before saving
  bool _validateNumericInputs(List<Map<String, dynamic>> categories) {
    for (final c in categories) {
      final text = c['limit'].text.trim();
      if (text.isNotEmpty && int.tryParse(text) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ '${c['name']}' limit must be a number."),
            backgroundColor: const Color.fromARGB(255, 149, 144, 144),
          ),
        );
        return false;
      }
    }
    return true;
  }

 void saveLocalCategories() async {
  final allCategories = [...fixedCategories, ...customCategories];

  // 1️⃣ Validate number inputs
  if (!_validateNumericInputs(allCategories)) {
    return;
  }

  // 2️⃣ Calculate total limits
  final totalLimits = allCategories.fold<double>(
    0,
    (sum, c) => sum + (int.tryParse(c['limit'].text.trim()) ?? 0),
  );

  // 3️⃣ Get income from ProfileData (since setup is local-only now)
  final totalIncome = ProfileData.incomes.fold<double>(
    0,
    (sum, i) => sum + (i['amount'] ?? 0.0),
  );

  // 4️⃣ Show the warning if limits > income
  if (totalLimits > totalIncome) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1D1B32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "⚠️ Limit Warning",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Your total category limits (SAR $totalLimits) exceed your income (SAR $totalIncome).\n\n"
          "Do you want to continue or adjust limits?",
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Adjust", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continue", style: TextStyle(color: Color(0xFF7959F5))),
          ),
        ],
      ),
    );

    // User chose to adjust → stop here
    if (proceed != true) return;
  }

  // 5️⃣ Save locally into ProfileData
  ProfileData.categories = allCategories.map((c) {
    return {
      'name': c['name'],
      'limit': int.tryParse(c['limit'].text.trim()) ?? 0,
      'color': c['color'].value,
      'icon': c['icon'].toString().split('.').last,
      'type': c['type'] ?? 'Custom',
    };
  }).toList();

  // 6️⃣ Next screen
  Navigator.pushNamed(context, '/setupExpenses');
}

  Widget _buildCompactRow(Map<String, dynamic> category,
      {bool isCustom = false, int? index}) {
    final color = category['color'] as Color;
    final icon = category['icon'] as IconData;
    final isFixed = category['type'] == 'Fixed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2550),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category['name'],
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 85,
            child: TextField(
              controller: category['limit'],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // ✅ Allow only numbers
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Limit",
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Colors.white30, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF7959F5), width: 1),
                ),
              ),
            ),
          ),
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: () => deleteCustomCategory(index!),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, color: Colors.white12),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF7959F5), Color(0xFFA27CFF)]),
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
                child: const Text("STEP 3 OF 6",
                    style: TextStyle(
                        color: Color(0xFFB8A8FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),

              const Text(
                "Set Categories",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Set custom categories and optionally add limits for each category.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 15),
              ),
              const SizedBox(height: 22),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Fixed Categories",
                          style: TextStyle(
                              color: Color(0xFFB8A8FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      ...fixedCategories.map((c) => _buildCompactRow(c)).toList(),
                      const SizedBox(height: 16),
                      const Text("Custom Categories",
                          style: TextStyle(
                              color: Color(0xFFB8A8FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      ...List.generate(
                          customCategories.length,
                          (i) => _buildCompactRow(customCategories[i],
                              isCustom: true, index: i)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: addCustomCategory,
                          icon: const Icon(Icons.add_circle_outline,
                              color: Color(0xFFB8A8FF)),
                          label: const Text("Add category",
                              style: TextStyle(
                                  color: Color(0xFFB8A8FF), fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                     onPressed: loading ? null : saveLocalCategories,
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
