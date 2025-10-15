import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/bottom_nav_bar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ===== Demo data (wire to backend later) =====
  final List<Map<String, dynamic>> _incomes = [
    {
      'name': 'Salary',
      'amount': '55,000.00',
      'payDay': DateTime(DateTime.now().year, DateTime.now().month, 27),
    },
  ];

  final List<Map<String, dynamic>> _fixedExpenses = [];

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'transportation',
      'icon': Icons.directions_car_rounded,
      'color': const Color(0xFF7D5EF6),
      'limit': '500.00',
    },
  ];

  // === Helper: close sheet/dialog, then update on next frame (prevents _dependents.isEmpty) ===
  void _closeThenUpdate(VoidCallback update, {BuildContext? popContext}) {
    final ctx = popContext ?? context;
    if (Navigator.canPop(ctx)) Navigator.pop(ctx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(update);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          // Top header
          SliverToBoxAdapter(
            child: Stack(
              children: [
                const TopGradient(height: 260),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content card
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F1D33),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Incomes =====
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Monthly Income',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _purpleCircleButton(onTap: () => _openAddIncomeSheet()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._incomes.map(
                    (income) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _incomeItem(
                        name: income['name'] ?? '',
                        amount: income['amount'] ?? '0',
                        payDay: income['payDay'] as DateTime,
                        onEdit: () => _openAddIncomeSheet(income: income),
                        onDelete: () => _confirmDelete(
                          context,
                          'Income',
                          income['name'] ?? '',
                          () => _incomes.remove(income),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== Fixed expenses =====
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add New Fixed Expense',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _purpleCircleButton(onTap: _openAddFixedExpenseSheet),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._fixedExpenses.map(
                    (expense) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _expenseItem(
                        name: expense['name'] ?? '',
                        amount: expense['amount'] ?? '0',
                        dueDate: expense['dueDate'] as DateTime,
                        onEdit: () =>
                            _openAddFixedExpenseSheet(expense: expense),
                        onDelete: () => _confirmDelete(
                          context,
                          'Expense',
                          expense['name'] ?? '',
                          () => _fixedExpenses.remove(expense),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== Categories =====
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Create New Category',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _purpleCircleButton(onTap: () => _openCategorySheet()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _categoryItem(
                        name: cat['name'] ?? '',
                        icon: cat['icon'] as IconData,
                        color: cat['color'] as Color,
                        limit: cat['limit'] ?? '0',
                        onEdit: () => _openCategorySheet(category: cat),
                        onDelete: () => _confirmDelete(
                          context,
                          'Category',
                          cat['name'] ?? '',
                          () => _categories.remove(cat),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Center(
                    child: _glowPrimaryButton(
                      text: 'Save',
                      onPressed: () {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved ✓')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () {}, // avoid route error if /savings doesn't exist yet
        onTapProfile: () => Navigator.pop(context),
      ),
    );
  }

  // ===================== Item cards (unified dark style) =====================

  Widget _incomeItem({
    required String name,
    required String amount,
    required DateTime payDay,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF5E52E6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.attach_money,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name - $amount SAR',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _expenseItem({
    required String name,
    required String amount,
    required DateTime dueDate,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFB388FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name - $amount SAR',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _categoryItem({
    required String name,
    required IconData icon,
    required Color color,
    required String limit,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ===================== Buttons & helpers =====================

  Widget _purpleCircleButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 32,
        width: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF5E52E6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _glowPrimaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
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
          width: 160,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E52E6),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(
    BuildContext context,
    String type,
    String name,
    VoidCallback removeCallback,
  ) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete $type',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$name" $type?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          // bright purple like the "+" button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E52E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _closeThenUpdate(removeCallback, popContext: ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===================== Sheets =====================

  void _openAddIncomeSheet({Map<String, dynamic>? income}) {
    final nameCtrl = TextEditingController(text: income?['name'] ?? '');
    final amountCtrl = TextEditingController(text: income?['amount'] ?? '');
    DateTime payDay =
        income?['payDay'] ??
        DateTime(DateTime.now().year, DateTime.now().month, 27);

    _openCardSheet(
      title: income == null ? 'Add Monthly Income' : 'Edit Monthly Income',
      child: StatefulBuilder(
        builder: (context, setM) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel('Income Name'),
              const SizedBox(height: 8),
              _sheetWhiteField(controller: nameCtrl),
              const SizedBox(height: 16),
              _sheetLabel('Income Amount'),
              const SizedBox(height: 8),
              _sheetWhiteField(
                controller: amountCtrl,
                suffix: 'SAR',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _sheetLabel('Pay Day'),
              const SizedBox(height: 8),
              _sheetPickerRow(
                value: _formatPayday(payDay),
                onTap: () async {
                  final picked = await _pickDate(payDay);
                  if (picked != null) setM(() => payDay = picked);
                },
              ),
              const SizedBox(height: 18),
              Center(
                child: _sheetGlowButton(
                  text: income == null ? 'Add' : 'Save',
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        amountCtrl.text.trim().isEmpty)
                      return;
                    _closeThenUpdate(() {
                      if (income == null) {
                        _incomes.add({
                          'name': nameCtrl.text.trim(),
                          'amount': amountCtrl.text.trim(),
                          'payDay': payDay,
                        });
                      } else {
                        income['name'] = nameCtrl.text.trim();
                        income['amount'] = amountCtrl.text.trim();
                        income['payDay'] = payDay;
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _openAddFixedExpenseSheet({Map<String, dynamic>? expense}) {
    final nameCtrl = TextEditingController(text: expense?['name'] ?? '');
    final amountCtrl = TextEditingController(text: expense?['amount'] ?? '');
    DateTime due =
        expense?['dueDate'] ??
        DateTime(DateTime.now().year, DateTime.now().month, 27);

    _openCardSheet(
      title: expense == null ? 'Add Fixed Expense' : 'Edit Fixed Expense',
      child: StatefulBuilder(
        builder: (context, setM) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel('Expense Name'),
              const SizedBox(height: 8),
              _sheetWhiteField(controller: nameCtrl),
              const SizedBox(height: 16),
              _sheetLabel('Due Date'),
              const SizedBox(height: 8),
              _sheetPickerRow(
                value: _formatPayday(due),
                onTap: () async {
                  final picked = await _pickDate(due);
                  if (picked != null) setM(() => due = picked);
                },
              ),
              const SizedBox(height: 16),
              _sheetLabel('Expense Amount'),
              const SizedBox(height: 8),
              _sheetWhiteField(
                controller: amountCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 18),
              Center(
                child: _sheetGlowButton(
                  text: expense == null ? 'Add' : 'Save',
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        amountCtrl.text.trim().isEmpty)
                      return;
                    _closeThenUpdate(() {
                      if (expense == null) {
                        _fixedExpenses.add({
                          'name': nameCtrl.text.trim(),
                          'amount': amountCtrl.text.trim(),
                          'dueDate': due,
                        });
                      } else {
                        expense['name'] = nameCtrl.text.trim();
                        expense['amount'] = amountCtrl.text.trim();
                        expense['dueDate'] = due;
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _openCategorySheet({Map<String, dynamic>? category}) {
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final limitCtrl = TextEditingController(text: category?['limit'] ?? '');
    IconData pickedIcon = category?['icon'] ?? Icons.category_rounded;
    Color pickedColor = category?['color'] ?? const Color(0xFF7D5EF6);

    _openCardSheet(
      title: category == null ? 'Add Category' : 'Edit Category',
      child: StatefulBuilder(
        builder: (context, setS) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel('Category Name'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _sheetWhiteField(controller: nameCtrl)),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () async {
                      final result =
                          await showModalBottomSheet<Map<String, dynamic>>(
                            context: context,
                            backgroundColor: const Color(0xFF1F1D33),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                            ),
                            builder: (_) => _IconColorPicker(
                              color: pickedColor,
                              icon: pickedIcon,
                            ),
                          );
                      if (result != null) {
                        setS(() {
                          pickedColor = result['color'] as Color;
                          pickedIcon = result['icon'] as IconData;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: pickedColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(pickedIcon, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sheetLabel('Category Limit'),
              const SizedBox(height: 8),
              _sheetWhiteField(
                controller: limitCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 18),
              Center(
                child: _sheetGlowButton(
                  text: category == null ? 'Add' : 'Save',
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    _closeThenUpdate(() {
                      if (category == null) {
                        _categories.add({
                          'name': nameCtrl.text.trim(),
                          'icon': pickedIcon,
                          'color': pickedColor,
                          'limit': limitCtrl.text.trim(),
                        });
                      } else {
                        category['name'] = nameCtrl.text.trim();
                        category['icon'] = pickedIcon;
                        category['color'] = pickedColor;
                        category['limit'] = limitCtrl.text.trim();
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameCtrl.dispose();
      limitCtrl.dispose();
    });
  }

  Future<void> _openCardSheet({required String title, required Widget child}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1D33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        );
      },
    );
  }

  // ===================== Sheet UI bits =====================

  Widget _sheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _sheetWhiteField({
    required TextEditingController controller,
    TextInputType? keyboard,
    String? suffix,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard ?? TextInputType.text,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (suffix != null)
            Text(
              suffix,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sheetPickerRow({required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.calendar_month, color: AppColors.bg, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sheetGlowButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          height: 14,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 0.7,
              colors: [Color(0x665E52E6), Colors.transparent],
            ),
          ),
        ),
        SizedBox(
          width: 140,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E52E6),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== Utils =====================

  Future<DateTime?> _pickDate(DateTime initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: const Color(0xFF1F1D33),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB388FF),
            surface: Color(0xFF1F1D33),
          ),
        ),
        child: child!,
      ),
    );
  }

  String _formatPayday(DateTime d) {
    final s = _daySuffix(d.day);
    return '${d.day}$s Of The Month';
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

// ===================== Icon/Color picker =====================

class _IconColorPicker extends StatefulWidget {
  final Color color;
  final IconData icon;
  const _IconColorPicker({required this.color, required this.icon});

  @override
  State<_IconColorPicker> createState() => _IconColorPickerState();
}

class _IconColorPickerState extends State<_IconColorPicker> {
  late Color _c;
  late IconData _i;

  static const _palette = <Color>[
    Color(0xFFFF6B5A),
    Color(0xFF34C759),
    Color(0xFF64D2FF),
    Color(0xFFB388FF),
    Color(0xFFFFCC00),
    Color(0xFFFF3B30),
  ];

  static const _icons = <IconData>[
    Icons.shopping_bag_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.fastfood_rounded,
    Icons.local_hospital_rounded,
    Icons.school_rounded,
    Icons.phone_iphone_rounded,
    Icons.lightbulb_rounded,
    Icons.beach_access_rounded,
    Icons.fitness_center_rounded,
    Icons.pets_rounded,
    Icons.umbrella_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _c = widget.color;
    _i = widget.icon;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Color',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: _palette.map((c) {
              final isSel = c.value == _c.value;
              return GestureDetector(
                onTap: () => setState(() => _c = c),
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Icon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: _icons.map((ic) {
              final sel = ic == _i;
              return InkWell(
                onTap: () => setState(() => _i = ic),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withOpacity(.15)
                        : Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(ic, color: Colors.white, size: 24),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E52E6),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                onPressed: () =>
                    Navigator.pop(context, {'color': _c, 'icon': _i}),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
