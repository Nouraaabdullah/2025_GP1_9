import 'package:flutter/material.dart';
import 'dart:math' as math;

class AddEditCategoryPage extends StatefulWidget {
  final Map<String, dynamic>? category;
  final List<String> usedColors; // 🟣 colors already used

  const AddEditCategoryPage({
    super.key,
    this.category,
    this.usedColors = const [],
  });

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _loading = false;
  String _selectedIcon = 'category';
  String _selectedColor = '#7D5EF6';

  final List<String> _iconNames = [
    'fastfood',
    'shopping_bag',
    'home',
    'airplanemode_active',
    'movie',
    'sports_soccer',
    'work',
    'pets',
    'brush',
    'local_cafe',
    'computer',
    'attach_money',
    'category',
    'shopping_cart',
    'restaurant',
    'directions_car',
    'local_hospital',
    'school',
    'sports_esports',
    'savings',
    'flight',
    'local_offer',
    'fitness_center',
    'music_note',
    'book',
    'child_care',
    'spa',
    'construction',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['name'] ?? '';
      _selectedIcon = widget.category!['icon'] ?? 'category';
      _selectedColor = widget.category!['icon_color'] ?? '#7D5EF6';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ✅ Save category locally and return to previous screen
  
  Future<void> _saveCategory() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);

  try {
    // Normalize color hex for consistent comparison
    final normalizedSelectedColor = _selectedColor.toUpperCase().replaceAll('#', '');
    final normalizedUsedColors = widget.usedColors
        .map((c) => c.toUpperCase().replaceAll('#', ''))
        .toList();

    // 🔴 Check if color already used (case-insensitive + normalized)
    if (normalizedUsedColors.contains(normalizedSelectedColor)) {
      _showError(
          "This color is already used for another category. Please choose a unique color.");
      setState(() => _loading = false);
      return;
    }

    final newCategory = {
      'name': _nameController.text.trim(),
      'icon': _findIconByName(_selectedIcon),
      'icon_name': _selectedIcon,
      'color': _hexToColor(_selectedColor),
      'icon_color': _selectedColor,
      'type': 'Custom',
    };

    if (mounted) Navigator.pop(context, newCategory);
  } catch (e) {
    _showError('Error saving category: $e');
  } finally {
    setState(() => _loading = false);
  }
}


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // 🎨 Color picker dialog with wheel + brightness
  void _showColorPicker(BuildContext context) {
    Color tempColor = _hexToColor(_selectedColor);
    double brightness = HSVColor.fromColor(tempColor).value;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F1D33),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Pick a Color',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanDown: (details) => _updateColorFromPosition(
                      details.localPosition,
                      setDialogState,
                      (c) => tempColor = c,
                      brightness,
                    ),
                    onPanUpdate: (details) => _updateColorFromPosition(
                      details.localPosition,
                      setDialogState,
                      (c) => tempColor = c,
                      brightness,
                    ),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: CustomPaint(
                        painter: _ColorWheelPainter(selectedColor: tempColor),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: tempColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.brightness_6,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF5E52E6),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFF5E52E6),
                            overlayColor:
                                const Color(0xFF5E52E6).withOpacity(0.25),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: brightness,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) {
                              setDialogState(() {
                                brightness = v;
                                HSVColor hsv = HSVColor.fromColor(tempColor);
                                tempColor = hsv.withValue(v).toColor();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedColor = _colorToHex(tempColor);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                      color: Color(0xFF5E52E6), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateColorFromPosition(
    Offset pos,
    StateSetter setDialogState,
    Function(Color) updateColor,
    double brightness,
  ) {
    const radius = 125.0;
    final dx = pos.dx - radius;
    final dy = pos.dy - radius;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= radius) {
      final angle = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
      final sat = (dist / radius).clamp(0.0, 1.0);
      setDialogState(() {
        updateColor(HSVColor.fromAHSV(1.0, angle, sat, brightness).toColor());
      });
    }
  }

  // color helpers
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  // icon lookup
  IconData _findIconByName(String iconName) {
    final iconMap = {
      'fastfood': Icons.fastfood,
      'shopping_bag': Icons.shopping_bag,
      'home': Icons.home,
      'airplanemode_active': Icons.airplanemode_active,
      'movie': Icons.movie,
      'sports_soccer': Icons.sports_soccer,
      'work': Icons.work,
      'pets': Icons.pets,
      'brush': Icons.brush,
      'local_cafe': Icons.local_cafe,
      'computer': Icons.computer,
      'attach_money': Icons.attach_money,
      'category': Icons.category,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'sports_esports': Icons.sports_esports,
      'savings': Icons.savings,
      'flight': Icons.flight,
      'local_offer': Icons.local_offer,
      'fitness_center': Icons.fitness_center,
      'music_note': Icons.music_note,
      'book': Icons.book,
      'child_care': Icons.child_care,
      'spa': Icons.spa,
      'construction': Icons.construction,
    };
    return iconMap[iconName] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1D33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D33),
        title: Text(
          widget.category == null ? 'Add Category' : 'Edit Category',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Name',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter category name',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter category name'
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // ===== COLOR PICKER =====
              const Text('Color',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: _hexToColor(_selectedColor),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap to choose color',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ===== ICONS =====
              const Text('Icon',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.start,
                    children: _iconNames.map((iconName) {
                      final isSelected = _selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF5E52E6)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _findIconByName(iconName),
                            color: isSelected ? Colors.white : Colors.white70,
                            size: 28,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E52E6),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 40),
                  ),
                  onPressed: _loading ? null : _saveCategory,
                  child: Text(
                    widget.category == null ? 'Add Category' : 'Save Changes',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16),
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

// 🎨 Custom color wheel painter
class _ColorWheelPainter extends CustomPainter {
  final Color selectedColor;
  _ColorWheelPainter({required this.selectedColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (double i = 0; i < 360; i++) {
      final sweep = i * math.pi / 180;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, i, 1.0, 1.0).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), sweep,
          math.pi / 180, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
