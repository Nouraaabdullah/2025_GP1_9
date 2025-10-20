import 'package:flutter/material.dart';
import 'shared_profile_data.dart';

class SetupCategoriesScreen extends StatefulWidget {
  const SetupCategoriesScreen({super.key});

  @override
  State<SetupCategoriesScreen> createState() => _SetupCategoriesScreenState();
}

class _SetupCategoriesScreenState extends State<SetupCategoriesScreen> {
  // --- FIXED DEFAULT CATEGORIES ---
  final List<Map<String, dynamic>> fixedCategories = [
    {
      'name': 'Groceries',
      'limit': TextEditingController(),
      'color': const Color(0xFFFFA726),
      'icon': Icons.shopping_cart,
    },
    {
      'name': 'Transport',
      'limit': TextEditingController(),
      'color': const Color(0xFF42A5F5),
      'icon': Icons.directions_car,
    },
    {
      'name': 'Utilities',
      'limit': TextEditingController(),
      'color': const Color(0xFF7E57C2),
      'icon': Icons.lightbulb,
    },
    {
      'name': 'Entertainment',
      'limit': TextEditingController(),
      'color': const Color(0xFFEC407A),
      'icon': Icons.videogame_asset,
    },
    {
      'name': 'Health',
      'limit': TextEditingController(),
      'color': const Color(0xFF66BB6A),
      'icon': Icons.favorite,
    },
    {
      'name': 'Education',
      'limit': TextEditingController(),
      'color': const Color(0xFFAB47BC),
      'icon': Icons.school,
    },
  ];

  // --- CUSTOM CATEGORY SECTION ---
  final List<Map<String, dynamic>> customCategories = [];
  final TextEditingController customNameController = TextEditingController();

  // --- DROPDOWN DATA ---
  final List<Color> availableColors = [
    Colors.purple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.amber,
  ];

  final List<IconData> availableIcons = [
    Icons.shopping_cart,
    Icons.directions_car,
    Icons.favorite,
    Icons.lightbulb,
    Icons.videogame_asset,
    Icons.school,
    Icons.home,
    Icons.fastfood,
    Icons.work,
    Icons.savings,
    Icons.flight,
    Icons.pets,
  ];

String selectedColor = Colors.purple.value.toString();
String selectedIcon = '${Icons.category.codePoint}_MaterialIcons';


  double monthlyIncome = 10000; // will be replaced later

  // --- Add custom category safely ---
  void addCustomCategory() {
    if (customNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    // prevent duplicate color
    final usedColors = [
      ...fixedCategories.map((c) => c['color'].value.toString()),
      ...customCategories.map((c) => c['color'].value.toString())
    ];
    if (usedColors.contains(selectedColor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a unique color')),
      );
      return;
    }

    setState(() {
      customCategories.add({
        'name': customNameController.text,
        'limit': TextEditingController(),
        'color': Color(int.parse(selectedColor)),
        'icon': availableIcons
            .firstWhere((i) => i.codePoint.toString() == selectedIcon),
      });
      customNameController.clear();
      selectedColor = Colors.purple.value.toString();
      selectedIcon = Icons.category.codePoint.toString();
    });
  }

  // --- Calculate total limit ---
  double get totalLimit {
    double total = 0;
    for (var c in [...fixedCategories, ...customCategories]) {
      total += double.tryParse(c['limit'].text) ?? 0;
    }
    return total;
  }

  // --- Validate and go to next screen ---
  void validateAndContinue() {
    bool hasEmptyLimit = [
      ...fixedCategories,
      ...customCategories
    ].any((c) => c['limit'].text.isEmpty);

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
          title: const Text(
            '⚠️ Limit Warning',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Your total category limits exceed your monthly income.\nDo you still want to continue?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Adjust', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                saveToProfileData();
                Navigator.pop(context);
                Navigator.pushNamed(context, '/setupExpenses');
              },
              child: const Text('Continue', style: TextStyle(color: Color(0xFFB8A8FF))),
            ),
          ],
        ),
      );
    } else {
      saveToProfileData();
      Navigator.pushNamed(context, '/setupExpenses');
    }
  }

  void saveToProfileData() {
    ProfileData.categories = [
      ...fixedCategories,
      ...customCategories
    ].map((c) => {
          'name': c['name'],
          'limit': double.tryParse(c['limit'].text) ?? 0.0,
          'color': c['color'].value.toRadixString(16),
          'icon': selectedIcon,

        }).toList();
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
                    width: MediaQuery.of(context).size.width * 0.4,
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
                  "STEP 2 OF 5",
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

              // FIXED + CUSTOM CATEGORY LIST
              Expanded(
                child: ListView(
                  children: [
                    const Text("Default Categories",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...fixedCategories.map((cat) => buildCategoryRow(cat)),
                    const Divider(color: Colors.white30),
                    const Text("Custom Categories",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...customCategories.map((cat) => buildCategoryRow(cat)),
                  ],
                ),
              ),

              // Add new category section
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

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
                Wrap(
  spacing: 8,
  children: availableColors.map((color) {
    return GestureDetector(
      onTap: () => setState(() => selectedColor = color.value.toString()),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedColor == color.value.toString()
                ? Colors.white
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }).toList(),
),

                  // Icon dropdown
                  Wrap(
  spacing: 8,
  children: availableIcons.map((icon) {
    return GestureDetector(
      onTap: () => setState(() =>
          selectedIcon = '${icon.codePoint}_${icon.fontFamily ?? "MaterialIcons"}'),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selectedIcon ==
                  '${icon.codePoint}_${icon.fontFamily ?? "MaterialIcons"}'
              ? const Color(0xFF7959F5)
              : const Color(0xFF2A2550),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }).toList(),
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

  Widget buildCategoryRow(Map<String, dynamic> cat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(cat['icon'], color: cat['color']),
          const SizedBox(width: 10),
          Expanded(
            child: Text(cat['name'], style: const TextStyle(color: Colors.white, fontSize: 16)),
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
  }
}
