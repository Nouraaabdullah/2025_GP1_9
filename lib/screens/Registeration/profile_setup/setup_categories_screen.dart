import 'package:flutter/material.dart';
import 'shared_profile_data.dart';
class SetupCategoriesScreen extends StatefulWidget {
  const SetupCategoriesScreen({super.key});

  @override
  State<SetupCategoriesScreen> createState() => _SetupCategoriesScreenState();
}

class _SetupCategoriesScreenState extends State<SetupCategoriesScreen> {
  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Groceries',
      'limit': TextEditingController(),
      'color': Colors.orange,
      'icon': Icons.shopping_cart
    },
    {
      'name': 'Transport',
      'limit': TextEditingController(),
      'color': Colors.blue,
      'icon': Icons.directions_car
    },
    {
      'name': 'Education',
      'limit': TextEditingController(),
      'color': Colors.green,
      'icon': Icons.school
    },
  ];

  final TextEditingController customNameController = TextEditingController();
  Color selectedColor = Colors.purple;
  IconData selectedIcon = Icons.category;

  final List<Map<String, dynamic>> colorOptions = [
    {'name': 'Purple', 'color': Colors.purple},
    {'name': 'Pink', 'color': Colors.pink},
    {'name': 'Teal', 'color': Colors.teal},
    {'name': 'Orange', 'color': Colors.orange},
    {'name': 'Blue', 'color': Colors.blue},
    {'name': 'Green', 'color': Colors.green},
  ];

  final List<Map<String, dynamic>> iconOptions = [
    {'name': 'Groceries', 'icon': Icons.shopping_cart},
    {'name': 'Transport', 'icon': Icons.directions_car},
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Health', 'icon': Icons.favorite},
    {'name': 'Bills', 'icon': Icons.lightbulb},
    {'name': 'Entertainment', 'icon': Icons.videogame_asset},
    {'name': 'Other', 'icon': Icons.category},
  ];

  double monthlyIncome = 10000; // Later fetched from Supabase

  double get totalLimit {
    double total = 0;
    for (var c in categories) {
      total += double.tryParse(c['limit'].text) ?? 0;
    }
    return total;
  }

  void addCustomCategory() {
    if (customNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() {
      categories.add({
        'name': customNameController.text,
        'limit': TextEditingController(),
        'color': selectedColor,
        'icon': selectedIcon,
      });
      customNameController.clear();
      selectedColor = Colors.purple;
      selectedIcon = Icons.category;
    });
  }

  void validateAndContinue() {
    bool hasEmptyLimit = categories.any((c) => c['limit'].text.isEmpty);

    if (hasEmptyLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set limits for all categories')),
      );
      return;
    }

    if (totalLimit > monthlyIncome) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2550),
          title: const Text('⚠️ Limit Warning', style: TextStyle(color: Colors.white)),
          content: Text(
            'Your total category limits exceed your monthly income.\n'
            'Do you still want to continue?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Adjust', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                // Save categories to ProfileData
ProfileData.categories = categories.map((c) => {
  'name': c['name'],
  'limit': double.tryParse(c['limit'].text) ?? 0.0,
  'color': c['color'].value.toRadixString(16), // hex color
  'icon': c['icon'].toString().split('.').last, // text icon name
}).toList();

                Navigator.pop(context);
                Navigator.pushNamed(context, '/setupBalance');
              },
              child: const Text('Continue', style: TextStyle(color: Color(0xFFB8A8FF))),
            ),
          ],
        ),
      );
      return;
    }

    // TODO: Save categories to Supabase
    Navigator.pushNamed(context, '/setupBalance');
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
                    width: MediaQuery.of(context).size.width * 0.85,
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
                  "STEP 4 OF 5",
                  style: TextStyle(
                    color: Color(0xFFB8A8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Set Category Limits",
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Assign a monthly limit for each category or create your own.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Scrollable list
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(cat['icon'], color: cat['color']),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat['name'],
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: cat['limit'],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Limit',
                                hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
                                filled: true,
                                fillColor: const Color(0xFF2A2550),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('SAR', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // Add new category section
              TextField(
                controller: customNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'New category name',
                  hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
                  filled: true,
                  fillColor: const Color(0xFF2A2550),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Color dropdown
                  Row(
                    children: [
                      const Text('Color:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      DropdownButton<Color>(
                        dropdownColor: const Color(0xFF2A2550),
                        value: selectedColor,
                        items: colorOptions.map((c) {
                          return DropdownMenuItem<Color>(
                            value: c['color'],
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(color: c['color'], shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(c['name'], style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedColor = value!);
                        },
                      ),
                    ],
                  ),

                  // Icon dropdown
                  Row(
                    children: [
                      const Text('Icon:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      DropdownButton<IconData>(
                        dropdownColor: const Color(0xFF2A2550),
                        value: selectedIcon,
                        items: iconOptions.map((i) {
                          return DropdownMenuItem<IconData>(
                            value: i['icon'],
                            child: Row(
                              children: [
                                Icon(i['icon'], color: Colors.white),
                                const SizedBox(width: 8),
                                Text(i['name'], style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedIcon = value!);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7959F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: addCustomCategory,
                child: const Text('Add Category'),
              ),

              const SizedBox(height: 24),
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
                      ),
                      onPressed: validateAndContinue,
                      child: const Text(
                        "Continue",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
