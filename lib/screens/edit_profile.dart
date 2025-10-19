// lib/screens/edit_profile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/bottom_nav_bar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // TEMP: hardcode until auth/signup is ready
  static const String kProfileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
  final _sb = Supabase.instance.client;

  // In-memory state (loaded from DB)
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _fixedExpenses = [];
  List<Map<String, dynamic>> _categories = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _sb
            .from('Fixed_Income')
            .select('income_id,name,monthly_income,payday,start_time,end_time')
            .eq('profile_id', kProfileId)
            .order('name'),
        _sb
            .from('Fixed_Expense')
            .select('expense_id,name,amount,due_date,category_id')
            .eq('profile_id', kProfileId)
            .order('name'),
        _sb
            .from('Category')
            .select(
              'category_id,name,type,monthly_limit,is_archived,icon,icon_color',
            )
            .eq('profile_id', kProfileId)
            .order('name'),
      ]);

      if (!mounted) return;

      setState(() {
        _incomes = (results[0] as List).cast<Map<String, dynamic>>();
        _fixedExpenses = (results[1] as List).cast<Map<String, dynamic>>();
        _categories = ((results[2] as List).cast<Map<String, dynamic>>())
            .where((c) => c['is_archived'] != true)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                : CustomScrollView(
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
                                  _purpleCircleButton(
                                    onTap: () => _openAddIncomeSheet(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._incomes.map(
                                (inc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _incomeItem(
                                    name: inc['name'] ?? '',
                                    amount: _fmtMoney(
                                      inc['monthly_income'] ?? 0.0,
                                    ),
                                    payDay: (inc['payday'] ?? 1) as int,
                                    onEdit: () =>
                                        _openAddIncomeSheet(income: inc),
                                    onDelete: () =>
                                        _confirmDeleteIncome(inc['income_id']),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ===== Fixed expenses =====
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Fixed Expenses',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  _purpleCircleButton(
                                    onTap: () => _openAddFixedExpenseSheet(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._fixedExpenses.map(
                                (exp) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _expenseItem(
                                    name: exp['name'] ?? '',
                                    amount: _fmtMoney(exp['amount'] ?? 0.0),
                                    dueDate: (exp['due_date'] ?? 1) as int,
                                    categoryName: _catName(exp['category_id']),
                                    onEdit: () =>
                                        _openAddFixedExpenseSheet(expense: exp),
                                    onDelete: () => _confirmDeleteExpense(
                                      exp['expense_id'],
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
                                      'Categories',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  _purpleCircleButton(
                                    onTap: () => _openCategorySheet(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._categories.map(
                                (cat) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _categoryItem(
                                    name: cat['name'] ?? '',
                                    limit: _fmtMoney(
                                      cat['monthly_limit'] ?? 0.0,
                                    ),
                                    icon: cat['icon'] ?? 'category',
                                    iconColor: cat['icon_color'] ?? '#7D5EF6',
                                    onEdit: () =>
                                        _openCategorySheet(category: cat),
                                    onDelete: () => _confirmDeleteCategory(
                                      cat['category_id'],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),
                              Center(
                                child: _glowPrimaryButton(
                                  text: 'Refresh',
                                  onPressed: _loadAll,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  )),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(context, '/dashboard'),
        onTapSavings: () {},
        onTapProfile: () => Navigator.pop(context),
      ),
    );
  }

  // ----------------- Item rows -----------------

  Widget _incomeItem({
    required String name,
    required String amount,
    required int payDay,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _roundIcon(const Color(0xFF5E52E6), Icons.attach_money),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name - $amount SAR  •  Pay day: $payDay',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _editBtn(onEdit),
          const SizedBox(width: 8),
          _deleteBtn(onDelete),
        ],
      ),
    );
  }

  Widget _expenseItem({
    required String name,
    required String amount,
    required int dueDate,
    required String categoryName,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _roundIcon(const Color(0xFFB388FF), Icons.receipt_long),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name - $amount SAR  •  Due day: $dueDate  •  $categoryName',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _editBtn(onEdit),
          const SizedBox(width: 8),
          _deleteBtn(onDelete),
        ],
      ),
    );
  }

  Widget _categoryItem({
    required String name,
    required String limit,
    required String icon,
    required String iconColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    Color color = _hexToColor(iconColor);
    IconData iconData = _getIconData(icon);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2840),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _roundIcon(color, iconData),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name  •  Limit: $limit SAR',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _editBtn(onEdit),
          const SizedBox(width: 8),
          _deleteBtn(onDelete),
        ],
      ),
    );
  }

  // ----------------- Small UI helpers -----------------

  Widget _roundIcon(Color c, IconData i) => Container(
    height: 32,
    width: 32,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    child: Icon(i, color: Colors.white, size: 18),
  );

  Widget _editBtn(VoidCallback onTap) => InkWell(
    onTap: onTap,
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
  );

  Widget _deleteBtn(VoidCallback onTap) => IconButton(
    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
  );

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

  // ----------------- Confirm deletes (wires to DB) -----------------

  void _confirmDeleteIncome(String incomeId) {
    _confirmDelete('Income', () async {
      try {
        await _sb
            .from('Fixed_Income')
            .update({'end_time': _iso(DateTime.now())})
            .eq('income_id', incomeId);
        await _loadAll();
      } catch (e) {
        _showError('Error deleting income: $e');
      }
    });
  }

  void _confirmDeleteExpense(String expenseId) {
    _confirmDelete('Expense', () async {
      try {
        await _sb
            .from('Fixed_Expense')
            .update({'end_time': _iso(DateTime.now())})
            .eq('expense_id', expenseId);
        await _loadAll();
      } catch (e) {
        _showError('Error deleting expense: $e');
      }
    });
  }

  void _confirmDeleteCategory(String categoryId) {
    _confirmDelete('Category', () async {
      try {
        await _sb
            .from('Category')
            .update({'is_archived': true})
            .eq('category_id', categoryId);
        await _loadAll();
      } catch (e) {
        _showError('Error deleting category: $e');
      }
    });
  }

  void _confirmDelete(String type, Future<void> Function() action) {
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
          'Are you sure you want to delete this $type?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E52E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await action();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----------------- Bottom sheets -----------------

  void _openAddIncomeSheet({Map<String, dynamic>? income}) {
    final nameCtrl = TextEditingController(text: income?['name'] ?? '');
    final amountCtrl = TextEditingController(
      text: income?['monthly_income']?.toString() ?? '',
    );
    int payDay = (income?['payday'] as int?) ?? 27;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1D33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _IncomeForm(
          income: income,
          nameCtrl: nameCtrl,
          amountCtrl: amountCtrl,
          payDay: payDay,
          onSave: (name, amount, payDay) async {
            final now = DateTime.now();
            final payload = {
              'name': name,
              'monthly_income': amount,
              'payday': payDay,
              'profile_id': kProfileId,
            };

            try {
              if (income == null) {
                payload['start_time'] = _iso(now);
                await _sb.from('Fixed_Income').insert(payload);
              } else {
                await _sb
                    .from('Fixed_Income')
                    .update(payload)
                    .eq('income_id', income['income_id']);
              }

              if (!mounted) return;
              Navigator.pop(context);
              await _loadAll();
            } catch (e) {
              _showError('Error saving income: $e');
            }
          },
        );
      },
    ).then((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _openAddFixedExpenseSheet({Map<String, dynamic>? expense}) {
    final nameCtrl = TextEditingController(text: expense?['name'] ?? '');
    final amountCtrl = TextEditingController(
      text: expense?['amount']?.toString() ?? '',
    );
    int dueDate = (expense?['due_date'] as int?) ?? 27;

    String? selectedCategoryId =
        expense?['category_id'] as String? ??
        (_categories.isNotEmpty
            ? _categories.first['category_id'] as String
            : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1D33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _ExpenseForm(
          expense: expense,
          nameCtrl: nameCtrl,
          amountCtrl: amountCtrl,
          dueDate: dueDate,
          categories: _categories,
          selectedCategoryId: selectedCategoryId,
          onSave: (name, amount, dueDate, categoryId) async {
            final now = DateTime.now();
            final payload = {
              'name': name,
              'amount': amount,
              'due_date': dueDate,
              'profile_id': kProfileId,
              'category_id': categoryId,
            };

            try {
              if (expense == null) {
                payload['start_time'] = _iso(now);
                await _sb.from('Fixed_Expense').insert(payload);
              } else {
                await _sb
                    .from('Fixed_Expense')
                    .update(payload)
                    .eq('expense_id', expense['expense_id']);
              }

              if (!mounted) return;
              Navigator.pop(context);
              await _loadAll();
            } catch (e) {
              _showError('Error saving expense: $e');
            }
          },
        );
      },
    ).then((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _openCategorySheet({Map<String, dynamic>? category}) {
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final limitCtrl = TextEditingController(
      text: category?['monthly_limit']?.toString() ?? '',
    );

    String selectedIcon = category?['icon'] as String? ?? 'category';
    String selectedColor = category?['icon_color'] as String? ?? '#7D5EF6';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1D33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _CategoryForm(
          category: category,
          nameCtrl: nameCtrl,
          limitCtrl: limitCtrl,
          selectedIcon: selectedIcon,
          selectedColor: selectedColor,
          onSave: (name, limit, icon, color) async {
            final payload = {
              'name': name,
              'type': 'Custom',
              'monthly_limit': limit,
              'icon': icon,
              'icon_color': color,
              'is_archived': false,
              'profile_id': kProfileId,
            };

            try {
              if (category == null) {
                await _sb.from('Category').insert(payload);
              } else {
                await _sb
                    .from('Category')
                    .update(payload)
                    .eq('category_id', category['category_id']);
              }
              if (!mounted) return;
              Navigator.pop(context);
              await _loadAll();
            } catch (e) {
              _showError('Error saving category: $e');
            }
          },
        );
      },
    ).then((_) {
      nameCtrl.dispose();
      limitCtrl.dispose();
    });
  }

  // ----------------- Sheet UI bits -----------------

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

  Widget _whiteDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.bg,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          hint: hint == null
              ? null
              : Text(
                  hint,
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          items: items,
          onChanged: onChanged,
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

  // ----------------- Utils -----------------

  String _fmtMoney(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _txt(dynamic v) => (v == null) ? '' : v.toString();

  String _catName(String? id) {
    if (id == null) return 'Uncategorized';
    final m = _categories.firstWhere(
      (c) => c['category_id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return (m.isEmpty) ? 'Uncategorized' : (m['name'] as String? ?? '—');
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'attach_money':
        return Icons.attach_money;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.category;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}

// Separate widget classes to avoid StatefulBuilder issues

class _IncomeForm extends StatefulWidget {
  final Map<String, dynamic>? income;
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final int payDay;
  final Function(String, double, int) onSave;

  const _IncomeForm({
    required this.income,
    required this.nameCtrl,
    required this.amountCtrl,
    required this.payDay,
    required this.onSave,
  });

  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  late int _payDay;

  @override
  void initState() {
    super.initState();
    _payDay = widget.payDay;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.income == null
                ? 'Add Monthly Income'
                : 'Edit Monthly Income',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSheetLabel('Income Name'),
          const SizedBox(height: 8),
          _buildSheetWhiteField(controller: widget.nameCtrl),
          const SizedBox(height: 16),

          _buildSheetLabel('Monthly Amount'),
          const SizedBox(height: 8),
          _buildSheetWhiteField(
            controller: widget.amountCtrl,
            suffix: 'SAR',
            keyboard: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          _buildSheetLabel('Pay Day (1-31)'),
          const SizedBox(height: 8),
          _buildWhiteDropdown<int>(
            value: _payDay,
            items: List.generate(
              31,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _payDay = v;
                });
              }
            },
          ),
          const SizedBox(height: 18),

          Center(
            child: _buildSheetGlowButton(
              text: widget.income == null ? 'Add' : 'Save',
              onPressed: () {
                final name = widget.nameCtrl.text.trim();
                final amt = double.tryParse(widget.amountCtrl.text.trim());
                if (name.isEmpty || amt == null) {
                  _showError('Please fill all required fields');
                  return;
                }
                widget.onSave(name, amt, _payDay);
              },
            ),
          ),
        ],
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

  Widget _buildWhiteDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.bg,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          hint: hint == null
              ? null
              : Text(
                  hint,
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSheetGlowButton({
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final int dueDate;
  final List<Map<String, dynamic>> categories;
  final String? selectedCategoryId;
  final Function(String, double, int, String) onSave;

  const _ExpenseForm({
    required this.expense,
    required this.nameCtrl,
    required this.amountCtrl,
    required this.dueDate,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSave,
  });

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late int _dueDate;
  late String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.dueDate;
    _selectedCategoryId = widget.selectedCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.expense == null ? 'Add Fixed Expense' : 'Edit Fixed Expense',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSheetLabel('Expense Name   ·   Category'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildSheetWhiteField(controller: widget.nameCtrl),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 170,
                child: _buildWhiteDropdown<String>(
                  value: _selectedCategoryId,
                  items: widget.categories
                      .map<DropdownMenuItem<String>>(
                        (c) => DropdownMenuItem(
                          value: c['category_id'] as String,
                          child: Text(
                            c['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  hint: 'Category',
                  onChanged: (v) {
                    setState(() {
                      _selectedCategoryId = v;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildSheetLabel('Due Day (1-31)'),
          const SizedBox(height: 8),
          _buildWhiteDropdown<int>(
            value: _dueDate,
            items: List.generate(
              31,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _dueDate = v;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          _buildSheetLabel('Amount'),
          const SizedBox(height: 8),
          _buildSheetWhiteField(
            controller: widget.amountCtrl,
            keyboard: TextInputType.numberWithOptions(decimal: true),
            suffix: 'SAR',
          ),
          const SizedBox(height: 18),

          Center(
            child: _buildSheetGlowButton(
              text: widget.expense == null ? 'Add' : 'Save',
              onPressed: () {
                final name = widget.nameCtrl.text.trim();
                final amt = double.tryParse(widget.amountCtrl.text.trim());
                if (name.isEmpty ||
                    amt == null ||
                    _selectedCategoryId == null) {
                  _showError('Please fill all required fields');
                  return;
                }
                widget.onSave(name, amt, _dueDate, _selectedCategoryId!);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ... (copy the same helper methods from _IncomeForm)
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

  Widget _buildWhiteDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.bg,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          hint: hint == null
              ? null
              : Text(
                  hint,
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSheetGlowButton({
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final Map<String, dynamic>? category;
  final TextEditingController nameCtrl;
  final TextEditingController limitCtrl;
  final String selectedIcon;
  final String selectedColor;
  final Function(String, double?, String, String) onSave;

  const _CategoryForm({
    required this.category,
    required this.nameCtrl,
    required this.limitCtrl,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onSave,
  });

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late String _selectedIcon;
  late String _selectedColor;

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
  ];

  final List<String> _availableColors = [
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#96CEB4',
    '#FFEAA7',
    '#DDA0DD',
    '#98D8C8',
    '#F7DC6F',
    '#BB8FCE',
    '#85C1E9',
    '#7D5EF6',
    '#5E52E6',
    '#B388FF',
    '#82E0AA',
    '#F8C471',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
    _selectedColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category == null ? 'Add Category' : 'Edit Category',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSheetLabel('Category Name'),
          const SizedBox(height: 8),
          _buildSheetWhiteField(controller: widget.nameCtrl),
          const SizedBox(height: 16),

          _buildSheetLabel('Monthly Limit (optional)'),
          const SizedBox(height: 8),
          _buildSheetWhiteField(
            controller: widget.limitCtrl,
            keyboard: TextInputType.numberWithOptions(decimal: true),
            suffix: 'SAR',
          ),
          const SizedBox(height: 16),

          _buildSheetLabel('Icon'),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
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
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildSheetLabel('Color'),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _hexToColor(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          Center(
            child: _buildSheetGlowButton(
              text: widget.category == null ? 'Add' : 'Save',
              onPressed: () {
                final name = widget.nameCtrl.text.trim();
                if (name.isEmpty) {
                  _showError('Category name is required');
                  return;
                }

                final lim = widget.limitCtrl.text.trim().isEmpty
                    ? null
                    : double.tryParse(widget.limitCtrl.text.trim());

                widget.onSave(name, lim, _selectedIcon, _selectedColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ... (copy the same helper methods from _IncomeForm)
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

  Widget _buildSheetGlowButton({
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
