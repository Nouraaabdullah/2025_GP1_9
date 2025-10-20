import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/top_gradient.dart';
import '../widgets/bottom_nav_bar.dart';
import 'add_edit_income_page.dart';
import 'add_edit_expense_page.dart';
import 'add_edit_category_page.dart';
import 'edit_balance_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const String kProfileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
  final _sb = Supabase.instance.client;

  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _fixedExpenses = [];
  List<Map<String, dynamic>> _categories = [];
  double _currentBalance = 0.0;

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
      // Load user profile to get current balance
      final profileData = await _sb
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', kProfileId)
          .single();

      // Load active incomes (where end_time is null)
      final incomesData = await _sb
          .from('Fixed_Income')
          .select('income_id,name,monthly_income,payday,start_time,end_time')
          .eq('profile_id', kProfileId)
          .isFilter('end_time', null)
          .order('name');

      // Load active expenses (where end_time is null)
      final expensesData = await _sb
          .from('Fixed_Expense')
          .select(
            'expense_id,name,amount,due_date,category_id,start_time,end_time',
          )
          .eq('profile_id', kProfileId)
          .isFilter('end_time', null)
          .order('name');

      // Load non-archived categories
      final categoriesData = await _sb
          .from('Category')
          .select(
            'category_id,name,type,monthly_limit,is_archived,icon,icon_color',
          )
          .eq('profile_id', kProfileId)
          .eq('is_archived', false)
          .order('name');

      if (!mounted) return;

      setState(() {
        _currentBalance =
            (profileData['current_balance'] as num?)?.toDouble() ?? 0.0;
        _incomes = (incomesData as List).cast<Map<String, dynamic>>();
        _fixedExpenses = (expensesData as List).cast<Map<String, dynamic>>();
        _categories = (categoriesData as List).cast<Map<String, dynamic>>();
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

  // ---------------- Navigation Methods ----------------
  void _navigateToEditBalance() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBalancePage(
          currentBalance: _currentBalance,
          profileId: kProfileId,
        ),
      ),
    );

    // Reload data if balance was updated
    if (result == true) {
      _loadAll();
    }
  }

  void _navigateToAddEditIncome({Map<String, dynamic>? income}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditIncomePage(income: income, profileId: kProfileId),
      ),
    );

    // Reload data if something was saved
    if (result == true) {
      _loadAll();
    }
  }

  void _navigateToAddEditExpense({Map<String, dynamic>? expense}) async {
    if (_categories.isEmpty) {
      _showError('Please create at least one category first');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExpensePage(
          expense: expense,
          profileId: kProfileId,
          categories: _categories,
        ),
      ),
    );

    // Reload data if something was saved
    if (result == true) {
      _loadAll();
    }
  }

  void _navigateToAddEditCategory({Map<String, dynamic>? category}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditCategoryPage(category: category, profileId: kProfileId),
      ),
    );

    // Reload data if something was saved
    if (result == true) {
      _loadAll();
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
                              // ===== Current Balance =====
                              const Text(
                                'Current Balance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2840),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    _roundIcon(
                                      const Color(0xFF4CAF50),
                                      Icons.account_balance_wallet,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${_fmtMoney(_currentBalance)} SAR',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _editBtn(() => _navigateToEditBalance()),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

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
                                    onTap: () => _navigateToAddEditIncome(),
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
                                        _navigateToAddEditIncome(income: inc),
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
                                    onTap: () => _navigateToAddEditExpense(),
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
                                        _navigateToAddEditExpense(expense: exp),
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
                                    onTap: () => _navigateToAddEditCategory(),
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
                                    onEdit: () => _navigateToAddEditCategory(
                                      category: cat,
                                    ),
                                    onDelete: () => _confirmDeleteCategory(
                                      cat['category_id'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
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

  // ----------------- Confirm deletes -----------------
  void _confirmDeleteIncome(String incomeId) {
    _confirmDelete('Income', () async {
      try {
        // Set end_time to archive the income
        await _sb
            .from('Fixed_Income')
            .update({'end_time': _iso(DateTime.now())})
            .eq('income_id', incomeId);

        await _loadAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Income deleted successfully'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        _showError('Error deleting income: $e');
      }
    });
  }

  void _confirmDeleteExpense(String expenseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Expense',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this expense?',
          style: TextStyle(color: Colors.white70),
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
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              try {
                // Permanently delete the expense from database
                await _sb
                    .from('Fixed_Expense')
                    .delete()
                    .eq('expense_id', expenseId);

                await _loadAll();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Expense deleted successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              } catch (e) {
                _showError('Error deleting expense: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  // ----------------- Utils -----------------
  String _fmtMoney(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
