import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
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

  // ✅ Interactive color wheel popup
  void showColorWheelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = selectedColor;

        return AlertDialog(
          backgroundColor: const Color(0xFF2A2550),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Pick a Color",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanDown: (details) {
                      _updateColor(details.localPosition, setStateDialog,
                          (c) => tempColor = c);
                    },
                    onPanUpdate: (details) {
                      _updateColor(details.localPosition, setStateDialog,
                          (c) => tempColor = c);
                    },
                    child: CustomPaint(
                      size: const Size(150, 150),
                      painter: _ColorWheelPainter(tempColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tempColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Done", style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() => selectedColor = tempColor);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateColor(Offset position,
      void Function(void Function()) setStateDialog, void Function(Color) setColor) {
    const radius = 75.0;
    final center = const Offset(radius, radius);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Limit to color ring edge
    if (distance > radius || distance < radius - 15) return;

    final angle = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
    final color = HSVColor.fromAHSV(1, angle, 1, 1).toColor();

    setStateDialog(() {});
    setColor(color);
  }

  // ✅ Add custom category
  void addCategory() {
    final name = nameController.text.trim();
    final limit = double.tryParse(limitController.text.trim()) ?? 0.0;

    if (name.isEmpty || limit <= 0 || selectedIcon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields.")),
      );
      return;
    }

    // Unique color validation
    if (addedCategories.any((c) => c['color'] == selectedColor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a unique color.")),
      );
      return;
    }

    setState(() {
      addedCategories.add({
        'name': name,
        'limit': limit,
        'color': selectedColor,
        'icon': selectedIcon,
      });
      nameController.clear();
      limitController.clear();
      selectedIcon = null;
      selectedColor = const Color(0xFF7959F5);
    });
  }

  // ✅ Save to Supabase
  Future<void> saveAllToSupabase() async {
    if (addedCategories.isEmpty) {
      Navigator.pushNamed(context, '/setupExpenses'); // allow skipping
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

      final records = addedCategories.map((c) {
        return {
          'profile_id': profileId,
          'name': c['name'],
          'type': 'Custom', // ✅ match enum name
          'monthly_limit': c['limit'],
          'icon': c['icon'].toString().split('.').last,
          'icon_color': c['color'].value.toRadixString(16),
          'is_archived': false,
        };
      }).toList();

      await supabase.from('Category').insert(records);
      ProfileData.categories.addAll(records);

      Navigator.pushNamed(context, '/setupExpenses');
    } catch (e) {
      debugPrint("❌ Error saving categories: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving categories: $e")),
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
              // Progress bar
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, color: Colors.white.withOpacity(0.1)),
                  Container(
                    height: 4,
                    width: MediaQuery.of(context).size.width * 0.65,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF7959F5), Color(0xFFA27CFF)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7959F5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("STEP 4 OF 6",
                    style: TextStyle(color: Color(0xFFB8A8FF), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),

              const Text("Custom Categories",
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Add extra categories for your lifestyle — or skip this step.",
                  style: TextStyle(color: Color(0xFFB3B3C7), fontSize: 16)),
              const SizedBox(height: 20),

              // ✅ Added categories
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: addedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = addedCategories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(cat['icon'], color: cat['color']),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(cat['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                          Text("${cat['limit']} SAR",
                              style: const TextStyle(color: Colors.white70)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => addedCategories.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Inputs (same layout as fixed)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2550),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Limit (SAR)',
                        hintStyle: const TextStyle(color: Color(0xFFB0AFC5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2550),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: showColorWheelDialog,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Wrap(
                spacing: 10,
                runSpacing: 10,
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
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7959F5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Add Category",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : saveAllToSupabase,
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

class _ColorWheelPainter extends CustomPainter {
  final Color selectedColor;
  _ColorWheelPainter(this.selectedColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (double i = 0; i < 360; i++) {
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1, i, 1, 1).toColor()
        ..strokeWidth = 15
        ..style = PaintingStyle.stroke;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          i * math.pi / 180, math.pi / 180, false, paint);
    }

    // highlight
    final highlight = Paint()
      ..color = selectedColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, highlight);
  }

  @override
  bool shouldRepaint(_) => true;
}
