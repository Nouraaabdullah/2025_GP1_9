import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupCustomCategoryScreen extends StatefulWidget {
  const SetupCustomCategoryScreen({super.key});

  @override
  State<SetupCustomCategoryScreen> createState() =>
      _SetupCustomCategoryScreenState();
}

class _SetupCustomCategoryScreenState extends State<SetupCustomCategoryScreen> {
  final supabase = Supabase.instance.client;
  bool loading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController limitController = TextEditingController();

  Color selectedColor = const Color(0xFF7959F5);
  IconData? selectedIcon;

  final List<Map<String, dynamic>> addedCategories = [];

  final List<IconData> availableIcons = [
    Icons.fastfood,
    Icons.shopping_bag,
    Icons.home,
    Icons.airplanemode_active,
    Icons.movie,
    Icons.sports_soccer,
    Icons.work,
    Icons.pets,
    Icons.brush,
    Icons.local_cafe,
    Icons.computer,
    Icons.attach_money,
  ];

  // Color picker dialog
  void pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2550),
        title: const Text("Pick a color",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: (color) => setState(() => selectedColor = color),
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Done", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  void addCategoryLocally() {
    final name = nameController.text.trim();
    final limit = double.tryParse(limitController.text.trim()) ?? 0.0;

    if (name.isEmpty || selectedIcon == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields.")),
      );
      return;
    }

    setState(() {
      addedCategories.add({
        'name': name,
        'monthly_limit': limit,
        'icon_color': selectedColor.value.toRadixString(16),
        'icon': selectedIcon.toString().split('.').last,
        'type': 'Custom',
        'is_archived': false,
      });
      nameController.clear();
      limitController.clear();
      selectedIcon = null;
      selectedColor = const Color(0xFF7959F5);
    });
  }

  Future<void> saveAllToSupabase() async {
    if (addedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one category.")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("No logged-in user found.");

      final profileResponse = await supabase
          .from('User_Profile')
          .select('profile_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileResponse == null) throw Exception("No user profile found.");

      final profileId = profileResponse['profile_id'];

      final records = addedCategories.map((cat) {
        return {
          'profile_id': profileId,
          'name': cat['name'],
          'type': 'Custom',
          'monthly_limit': cat['monthly_limit'],
          'icon': cat['icon'],
          'icon_color': cat['icon_color'],
          'is_archived': false,
        };
      }).toList();

      await supabase.from('Category').insert(records);

      ProfileData.categories.addAll(records);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Categories saved successfully!")),
      );

      Navigator.pushNamed(context, '/setupExpenses');
    } catch (e) {
      debugPrint("❌ Error saving categories: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving custom categories: $e")),
      );
    } finally {
      setState(() => loading = false);
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
              Stack(
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.65,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7959F5), Color(0xFFA27CFF)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              const Text(
                "Custom Categories",
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Add personalized categories that fit your lifestyle.",
                style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Category name",
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

              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Monthly limit (SAR)",
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
                children: [
                  GestureDetector(
                    onTap: () => pickColor(context),
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      children: availableIcons.map((icon) {
                        final isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF7959F5)
                                  : const Color(0xFF2A2550),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7959F5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: addCategoryLocally,
                child: const Text("Add Category"),
              ),
              const SizedBox(height: 16),

              // 🧾 List of added categories
              Expanded(
                child: ListView.builder(
                  itemCount: addedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = addedCategories[index];
                    return ListTile(
                      leading: Icon(Icons.circle, color: Color(int.parse(cat['icon_color'], radix: 16))),
                      title: Text(cat['name'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text("Limit: ${cat['monthly_limit']} SAR", style: const TextStyle(color: Colors.white70)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() => addedCategories.removeAt(index));
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB8A8FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: loading ? null : saveAllToSupabase,
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
        ),
      ),
    );
  }
}
