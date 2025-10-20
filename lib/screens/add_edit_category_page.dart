import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class AddEditCategoryPage extends StatefulWidget {
  final Map<String, dynamic>? category;
  final String profileId;

  const AddEditCategoryPage({
    super.key,
    this.category,
    required this.profileId,
  });

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  String _selectedIcon = 'category';
  String _selectedColor = '#7D5EF6';
  final _sb = Supabase.instance.client;

  bool _loading = false;

  final List<Map<String, dynamic>> _availableIcons = [
    {'icon': 'category', 'name': 'Category', 'data': Icons.category},
    {'icon': 'shopping_cart', 'name': 'Shopping', 'data': Icons.shopping_cart},
    {'icon': 'restaurant', 'name': 'Food', 'data': Icons.restaurant},
    {
      'icon': 'directions_car',
      'name': 'Transport',
      'data': Icons.directions_car,
    },
    {'icon': 'home', 'name': 'Home', 'data': Icons.home},
    {'icon': 'local_hospital', 'name': 'Health', 'data': Icons.local_hospital},
    {'icon': 'school', 'name': 'Education', 'data': Icons.school},
    {
      'icon': 'sports_esports',
      'name': 'Entertainment',
      'data': Icons.sports_esports,
    },
    {'icon': 'attach_money', 'name': 'Income', 'data': Icons.attach_money},
    {'icon': 'savings', 'name': 'Savings', 'data': Icons.savings},
    {'icon': 'flight', 'name': 'Travel', 'data': Icons.flight},
    {'icon': 'local_offer', 'name': 'Offers', 'data': Icons.local_offer},
    {'icon': 'fitness_center', 'name': 'Fitness', 'data': Icons.fitness_center},
    {'icon': 'movie', 'name': 'Movies', 'data': Icons.movie},
    {'icon': 'music_note', 'name': 'Music', 'data': Icons.music_note},
    {'icon': 'book', 'name': 'Books', 'data': Icons.book},
    {'icon': 'pets', 'name': 'Pets', 'data': Icons.pets},
    {'icon': 'child_care', 'name': 'Kids', 'data': Icons.child_care},
    {'icon': 'spa', 'name': 'Beauty', 'data': Icons.spa},
    {'icon': 'construction', 'name': 'Maintenance', 'data': Icons.construction},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing
    if (widget.category != null) {
      _nameController.text = widget.category!['name'] ?? '';
      _limitController.text = (widget.category!['monthly_limit'] ?? 0.0)
          .toString();
      _selectedIcon = widget.category!['icon'] ?? 'category';
      _selectedColor = widget.category!['icon_color'] ?? '#7D5EF6';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final limit = _limitController.text.trim().isEmpty
          ? null
          : double.tryParse(_limitController.text.trim());

      final payload = {
        'name': name,
        'type': 'Custom',
        'monthly_limit': limit,
        'icon': _selectedIcon,
        'icon_color': _selectedColor,
        'is_archived': false,
        'profile_id': widget.profileId,
      };

      if (widget.category == null) {
        // Add new category
        await _sb.from('Category').insert(payload);
      } else {
        // Update existing category
        await _sb
            .from('Category')
            .update(payload)
            .eq('category_id', widget.category!['category_id']);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.red.toRadixString(16).padLeft(2, '0')}'
            '${color.green.toRadixString(16).padLeft(2, '0')}'
            '${color.blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

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
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color Wheel
                  GestureDetector(
                    onPanDown: (details) => _updateColorFromPosition(
                      details.localPosition,
                      setDialogState,
                      (color) => tempColor = color,
                      brightness,
                    ),
                    onPanUpdate: (details) => _updateColorFromPosition(
                      details.localPosition,
                      setDialogState,
                      (color) => tempColor = color,
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
                  const SizedBox(height: 20),
                  // Brightness Slider
                  Row(
                    children: [
                      const Icon(
                        Icons.brightness_6,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF5E52E6),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFF5E52E6),
                            overlayColor: const Color(
                              0xFF5E52E6,
                            ).withOpacity(0.3),
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
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
                    color: Color(0xFF5E52E6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateColorFromPosition(
    Offset position,
    StateSetter setDialogState,
    Function(Color) updateColor,
    double brightness,
  ) {
    const double radius = 125.0;
    final double dx = position.dx - radius;
    final double dy = position.dy - radius;
    final double distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= radius) {
      final double angle = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
      final double saturation = (distance / radius).clamp(0.0, 1.0);

      setDialogState(() {
        updateColor(
          HSVColor.fromAHSV(1.0, angle, saturation, brightness).toColor(),
        );
      });
    }
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
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetLabel('Category Name'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _nameController,
                hintText: 'Enter category name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter category name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Monthly Limit (SAR) - Optional'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _limitController,
                hintText: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final lim = double.tryParse(value);
                    if (lim == null || lim < 0) {
                      return 'Please enter valid limit';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Icon'),
              const SizedBox(height: 8),
              SizedBox(
                height: 120, // Increased height to show more icons
                child: GridView.builder(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Made scrollable
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final iconInfo = _availableIcons[index];
                    final isSelected = _selectedIcon == iconInfo['icon'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconInfo['icon'];
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF5E52E6)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          iconInfo['data'] as IconData,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Color'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showColorPicker(context),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _hexToColor(_selectedColor),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap to choose color',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Center(child: _buildSaveButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildSheetWhiteField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF7A7A7A)),
        ),
        style: const TextStyle(
          color: Color(0xFF1E1E1E),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Column(
      children: [
        Container(
          height: 16,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 0.7,
              colors: [Color(0x665E52E6), Colors.transparent],
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E52E6),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            onPressed: _loading ? null : _saveCategory,
            child: Text(
              widget.category == null ? 'Add Category' : 'Save Changes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painter for Color Wheel
class _ColorWheelPainter extends CustomPainter {
  final Color selectedColor;

  _ColorWheelPainter({required this.selectedColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the color wheel
    for (double i = 0; i < 360; i += 1) {
      final sweepAngle = i * math.pi / 180;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, i, 1.0, 1.0).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngle,
        math.pi / 180,
        false,
        paint,
      );
    }

    // Draw saturation gradient
    final saturationGradient = RadialGradient(
      colors: [Colors.white, Colors.white.withOpacity(0)],
    );

    final saturationPaint = Paint()
      ..shader = saturationGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, saturationPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
