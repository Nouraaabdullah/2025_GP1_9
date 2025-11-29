import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/theme/app_colors.dart';
import 'package:surra_application/widgets/top_gradient.dart';
import 'package:surra_application/widgets/bottom_nav_bar.dart';
import 'package:surra_application/utils/auth_helpers.dart'; // Import the utility
import 'add_edit_income_page.dart';
import 'add_edit_expense_page.dart';
import 'add_edit_category_page.dart';
import 'edit_balance_page.dart';

class EditProfilePage
    extends
        StatefulWidget {
  const EditProfilePage({
    super.key,
  });

  @override
  State<
    EditProfilePage
  >
  createState() => _EditProfilePageState();
}

class _EditProfilePageState
    extends
        State<
          EditProfilePage
        > {
  final _sb = Supabase.instance.client;

  List<
    Map<
      String,
      dynamic
    >
  >
  _incomes = [];
  List<
    Map<
      String,
      dynamic
    >
  >
  _fixedExpenses = [];
  List<
    Map<
      String,
      dynamic
    >
  >
  _categories = [];
  double _currentBalance = 0.0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ======= GET PROFILE ID USING UTILITY FUNCTION =======
  Future<
    String
  >
  _getProfileId() async {
    final profileId = await getProfileId(
      context,
    );
    if (profileId ==
        null) {
      // The utility function already handles navigation to login
      throw Exception(
        'User not authenticated',
      );
    }
    return profileId;
  }

  Future<
    void
  >
  _loadAll() async {
    if (!mounted) return;

    setState(
      () {
        _loading = true;
        _error = null;
      },
    );
    try {
      final profileId = await _getProfileId();

      // Load user profile to get current balance
      final profileData = await _sb
          .from(
            'User_Profile',
          )
          .select(
            'current_balance',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .single();

      // Load active incomes (where end_time is null) - INCLUDING is_primary
      final incomesData = await _sb
          .from(
            'Fixed_Income',
          )
          .select(
            'income_id,name,monthly_income,payday,start_time,end_time,is_primary',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .isFilter(
            'end_time',
            null,
          )
          .order(
            'name',
          );

      // Load active expenses (where end_time is null)
      final expensesData = await _sb
          .from(
            'Fixed_Expense',
          )
          .select(
            'expense_id,name,amount,due_date,category_id,start_time,end_time',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .isFilter(
            'end_time',
            null,
          )
          .order(
            'name',
          );

      // Load non-archived categories
      final categoriesData = await _sb
          .from(
            'Category',
          )
          .select(
            'category_id,name,type,monthly_limit,is_archived,icon,icon_color',
          )
          .eq(
            'profile_id',
            profileId,
          )
          .eq(
            'is_archived',
            false,
          )
          .order(
            'name',
          );

      if (!mounted) return;

      setState(
        () {
          _currentBalance =
              (profileData['current_balance']
                      as num?)
                  ?.toDouble() ??
              0.0;
          _incomes =
              (incomesData
                      as List)
                  .cast<
                    Map<
                      String,
                      dynamic
                    >
                  >();
          _fixedExpenses =
              (expensesData
                      as List)
                  .cast<
                    Map<
                      String,
                      dynamic
                    >
                  >();
          _categories =
              (categoriesData
                      as List)
                  .cast<
                    Map<
                      String,
                      dynamic
                    >
                  >();
          _loading = false;
        },
      );
    } catch (
      e
    ) {
      if (!mounted) return;
      setState(
        () {
          _error = e.toString();
          _loading = false;
        },
      );
    }
  }

  // ---------------- Navigation Methods ----------------
  void _navigateToEditBalance() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (
                context,
              ) => EditBalancePage(
                currentBalance: _currentBalance,
              ),
        ),
      );

      // Reload data if balance was updated
      if (result ==
          true) {
        _loadAll();
      }
    } catch (
      e
    ) {
      _showError(
        'Error navigating to edit balance: $e',
      );
    }
  }

  void _navigateToAddEditIncome({
    Map<
      String,
      dynamic
    >?
    income,
  }) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (
                context,
              ) => AddEditIncomePage(
                income: income,
              ),
        ),
      );

      // Reload data if something was saved
      if (result ==
          true) {
        _loadAll();
      }
    } catch (
      e
    ) {
      _showError(
        'Error navigating to income page: $e',
      );
    }
  }

  void _navigateToAddEditExpense({
    Map<
      String,
      dynamic
    >?
    expense,
  }) async {
    if (_categories.isEmpty) {
      _showError(
        'Please create at least one category first',
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (
                context,
              ) => AddEditExpensePage(
                expense: expense,
                categories: _categories,
              ),
        ),
      );

      // Reload data if something was saved
      if (result ==
          true) {
        _loadAll();
      }
    } catch (
      e
    ) {
      _showError(
        'Error navigating to expense page: $e',
      );
    }
  }

  void _navigateToAddEditCategory({
    Map<
      String,
      dynamic
    >?
    category,
  }) async {
    try {
      final profileId = await _getProfileId(); // Get profileId here

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (
                context,
              ) => AddEditCategoryPage(
                category: category,
                profileId: profileId, // Pass the required profileId
              ),
        ),
      );

      // Reload data if something was saved
      if (result ==
          true) {
        _loadAll();
      }
    } catch (
      e
    ) {
      _showError(
        'Error navigating to category page: $e',
      );
    }
  }

  // Get fixed categories (sorted)
  List<
    Map<
      String,
      dynamic
    >
  >
  get _fixedCategories {
    return _categories
        .where(
          (
            cat,
          ) =>
              cat['type'] ==
              'Fixed',
        )
        .toList()
      ..sort(
        (
          a,
          b,
        ) =>
            (a['name']
                    as String)
                .compareTo(
                  b['name']
                      as String,
                ),
      );
  }

  // Get custom categories (sorted)
  List<
    Map<
      String,
      dynamic
    >
  >
  get _customCategories {
    return _categories
        .where(
          (
            cat,
          ) =>
              cat['type'] ==
              'Custom',
        )
        .toList()
      ..sort(
        (
          a,
          b,
        ) =>
            (a['name']
                    as String)
                .compareTo(
                  b['name']
                      as String,
                ),
      );
  }

  // ---------------- UI ----------------
  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : (_error !=
                    null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text(
                            'Retry',
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Top header
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            const TopGradient(
                              height: 260,
                            ),
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
                                      onPressed: () => Navigator.pop(
                                        context,
                                      ),
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
                                    const SizedBox(
                                      width: 48,
                                    ),
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
                            color: Color(
                              0xFF1F1D33,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                34,
                              ),
                              topRight: Radius.circular(
                                34,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            20,
                            22,
                            20,
                          ),
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
                              const SizedBox(
                                height: 12,
                              ),
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2A2840,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    16,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    // UPDATED: Square icon styling
                                    _squareIcon(
                                      const Color(
                                        0xFF4CAF50,
                                      ),
                                      Icons.account_balance_wallet,
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
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
                                    _editBtn(
                                      () => _navigateToEditBalance(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),

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
                              const SizedBox(
                                height: 12,
                              ),
                              ..._incomes.map(
                                (
                                  inc,
                                ) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                  ),
                                  child: _incomeItem(
                                    name:
                                        inc['name'] ??
                                        '',
                                    amount: _fmtMoney(
                                      inc['monthly_income'] ??
                                          0.0,
                                    ),
                                    onEdit: () => _navigateToAddEditIncome(
                                      income: inc,
                                    ),
                                    onDelete: () => _confirmDeleteIncome(
                                      inc['income_id'],
                                    ),
                                    canDelete:
                                        _incomes.length >
                                        1,
                                    isLastIncome:
                                        _incomes.length <=
                                        1,
                                    isPrimary:
                                        inc['is_primary'] ==
                                        true, // NEW: Check if primary
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),

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
                              const SizedBox(
                                height: 12,
                              ),
                              ..._fixedExpenses.map(
                                (
                                  exp,
                                ) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                  ),
                                  child: _expenseItem(
                                    name:
                                        exp['name'] ??
                                        '',
                                    amount: _fmtMoney(
                                      exp['amount'] ??
                                          0.0,
                                    ),
                                    onEdit: () => _navigateToAddEditExpense(
                                      expense: exp,
                                    ),
                                    onDelete: () => _confirmDeleteExpense(
                                      exp['expense_id'],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),

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
                              const SizedBox(
                                height: 12,
                              ),

                              // Fixed Categories
                              if (_fixedCategories.isNotEmpty) ...[
                                ..._fixedCategories.map(
                                  (
                                    cat,
                                  ) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 8,
                                    ),
                                    child: _categoryItem(
                                      name:
                                          cat['name'] ??
                                          '',
                                      limit: _fmtMoney(
                                        cat['monthly_limit'] ??
                                            0.0,
                                      ),
                                      icon:
                                          cat['icon'] ??
                                          'category',
                                      iconColor:
                                          cat['icon_color'] ??
                                          '#7D5EF6',
                                      type:
                                          cat['type']
                                              as String? ??
                                          'Fixed',
                                      onEdit: () => _navigateToAddEditCategory(
                                        category: cat,
                                      ),
                                      onDelete: null, // No delete for fixed categories
                                    ),
                                  ),
                                ),
                              ],

                              // Custom Categories
                              if (_customCategories.isNotEmpty) ...[
                                ..._customCategories.map(
                                  (
                                    cat,
                                  ) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 8,
                                    ),
                                    child: _categoryItem(
                                      name:
                                          cat['name'] ??
                                          '',
                                      limit: _fmtMoney(
                                        cat['monthly_limit'] ??
                                            0.0,
                                      ),
                                      icon:
                                          cat['icon'] ??
                                          'category',
                                      iconColor:
                                          cat['icon_color'] ??
                                          '#7D5EF6',
                                      type:
                                          cat['type']
                                              as String? ??
                                          'Custom',
                                      onEdit: () => _navigateToAddEditCategory(
                                        category: cat,
                                      ),
                                      onDelete: () => _confirmDeleteCategory(
                                        cat['category_id'],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(
                                height: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 100,
                        ),
                      ),
                    ],
                  )),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushNamed(
          context,
          '/dashboard',
        ),
        onTapSavings: () {},
        onTapProfile: () => Navigator.pop(
          context,
        ),
      ),
    );
  }

  // ----------------- Simplified Item rows -----------------
  Widget _incomeItem({
    required String name,
    required String amount,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required bool canDelete,
    required bool isLastIncome,
    required bool isPrimary, // NEW: Primary income flag
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(
          0xFF2A2840,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        children: [
          // UPDATED: Square icon styling
          _squareIcon(
            const Color(
              0xFF5E52E6,
            ),
            Icons.attach_money,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(
                        width: 6,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(
                            0.2,
                          ),
                          borderRadius: BorderRadius.circular(
                            4,
                          ),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '$amount SAR',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // DELETE BUTTON ON LEFT (hidden for primary incomes)
          if (!isPrimary &&
              canDelete &&
              !isLastIncome)
            _deleteBtn(
              onDelete,
              enabled: true,
            ),
          const SizedBox(
            width: 8,
          ),
          // EDIT BUTTON ON RIGHT
          _editBtn(
            onEdit,
          ),
        ],
      ),
    );
  }

  Widget _expenseItem({
    required String name,
    required String amount,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(
          0xFF2A2840,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        children: [
          // UPDATED: Square icon styling
          _squareIcon(
            const Color(
              0xFFB388FF,
            ),
            Icons.receipt_long,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '$amount SAR',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // DELETE BUTTON ON LEFT
          _deleteBtn(
            onDelete,
            enabled: true,
          ),
          const SizedBox(
            width: 8,
          ),
          // EDIT BUTTON ON RIGHT
          _editBtn(
            onEdit,
          ),
        ],
      ),
    );
  }

  Widget _categoryItem({
    required String name,
    required String limit,
    required String icon,
    required String iconColor,
    required String type,
    required VoidCallback onEdit,
    required VoidCallback? onDelete, // Can be null for fixed categories
  }) {
    Color color = _hexToColor(
      iconColor,
    );
    IconData iconData = _iconDataFromString(
      icon,
    );

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(
          0xFF2A2840,
        ),
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        children: [
          // UPDATED: Square icon styling
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(
                0.12,
              ),
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              iconData,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  'Limit: $limit SAR',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // DELETE BUTTON ON LEFT (only for custom categories)
          if (onDelete !=
              null)
            _deleteBtn(
              onDelete,
              enabled: true,
            ),
          const SizedBox(
            width: 8,
          ),
          // EDIT BUTTON ON RIGHT
          _editBtn(
            onEdit,
          ),
        ],
      ),
    );
  }

  // ----------------- Small UI helpers -----------------
  // UPDATED: Square icon styling (replaces _roundIcon)
  Widget
  _squareIcon(
    Color c,
    IconData i,
  ) => Container(
    height: 32,
    width: 32,
    decoration: BoxDecoration(
      color: c.withOpacity(
        0.12,
      ),
      borderRadius: BorderRadius.circular(
        12,
      ),
    ),
    child: Icon(
      i,
      color: c,
      size: 18,
    ),
  );

  Widget
  _editBtn(
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(
      8,
    ),
    child: Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(
          .08,
        ),
        borderRadius: BorderRadius.circular(
          8,
        ),
      ),
      child: const Icon(
        Icons.edit,
        size: 16,
        color: Colors.white,
      ),
    ),
  );

  Widget
  _deleteBtn(
    VoidCallback onTap, {
    bool enabled = true,
  }) => IconButton(
    icon: Icon(
      Icons.delete_outline,
      color: enabled
          ? Colors.red
          : Colors.grey, // Red when enabled, grey when disabled
      size: 20,
    ),
    onPressed: enabled
        ? onTap
        : null,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
  );

  Widget _purpleCircleButton({
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 32,
        width: 32,
        decoration: const BoxDecoration(
          color: Color(
            0xFF5E52E6,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  // ----------------- Icon Data Conversion for IconData(U+0E37B) format -----------------
  IconData _iconDataFromString(
    String iconString,
  ) {
    try {
      // Handle IconData(U+0E37B) format
      if (iconString.startsWith(
        'IconData(U+',
      )) {
        // Extract the hex code from "IconData(U+0E37B)"
        final hexCode = iconString.substring(
          11,
          iconString.length -
              1,
        ); // Gets "0E37B"
        final codePoint = int.parse(
          hexCode,
          radix: 16,
        );
        return IconData(
          codePoint,
          fontFamily: 'MaterialIcons',
        );
      }

      // Handle old string format as fallback
      return _stringToIconData(
        iconString,
      );
    } catch (
      e
    ) {
      debugPrint(
        'Error converting icon string: $iconString, error: $e',
      );
      return Icons.category; // Fallback icon
    }
  }

  // Fallback for old string format
  IconData _stringToIconData(
    String iconString,
  ) {
    try {
      if (iconString.contains(
        '.',
      )) {
        final iconName = iconString
            .split(
              '.',
            )
            .last;
        return _findIconByName(
          iconName,
        );
      } else {
        return _findIconByName(
          iconString,
        );
      }
    } catch (
      e
    ) {
      debugPrint(
        'Error converting string to IconData: $e',
      );
      return Icons.category;
    }
  }

  // Find icon by name from available icons
  IconData _findIconByName(
    String iconName,
  ) {
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

    return iconMap[iconName] ??
        Icons.category;
  }

  // ----------------- Unified Delete Confirmation -----------------
  void _showDeleteConfirmation({
    required String title,
    required String content,
    required Future<
      void
    >
    Function()
    onConfirm,
  }) {
    showDialog(
      context: context,
      builder:
          (
            ctx,
          ) => AlertDialog(
            backgroundColor: const Color(
              0xFF1F1D33,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              content,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  ctx,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF5E52E6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(
                    ctx,
                  );
                  try {
                    await onConfirm();

                    // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                    // REPLACED SNACKBAR WITH YOUR SUCCESS DIALOG
                    // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

                    if (mounted) {
                      await _showSuccessDialog(
                        message: 'Deleted successfully.',
                      );
                    }
                  } catch (
                    e
                  ) {
                    if (mounted) {
                      _showError(
                        'Error deleting: $e',
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ----------------- Warning Dialog -----------------
  void _showWarningDialog({
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,
      builder:
          (
            ctx,
          ) => AlertDialog(
            backgroundColor: const Color(
              0xFF1F1D33,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              content,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF5E52E6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () => Navigator.pop(
                  ctx,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<
    void
  >
  _showSuccessDialog({
    required String message,
  }) async {
    await showDialog<
      void
    >(
      context: context,
      barrierDismissible: true,
      builder:
          (
            ctx,
          ) {
            return Dialog(
              backgroundColor: const Color(
                0xFF141427,
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  40,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  32,
                  24,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF1F1F33,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(
                              0.6,
                            ),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.greenAccent,
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_outline,
                          color: Colors.greenAccent,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 24,
                    ),
                    const Text(
                      'Done!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(
                      height: 28,
                    ),
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(
                          ctx,
                        ).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF704EF4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              999,
                            ),
                          ),
                          elevation: 16,
                          shadowColor:
                              const Color(
                                0xFF704EF4,
                              ).withOpacity(
                                0.7,
                              ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  // ----------------- Confirm deletes -----------------
  void _confirmDeleteIncome(
    String incomeId,
  ) {
    // Double check (in case UI state is out of sync)
    if (_incomes.length <=
        1) {
      _showWarningDialog(
        title: 'Cannot Delete Income',
        content:
            'You must have at least one income source. '
            'Please add another income before deleting this one.',
      );
      return;
    }

    _showDeleteConfirmation(
      title: 'Delete Income',
      content: 'Are you sure you want to delete this income?',
      onConfirm: () async {
        final profileId = await _getProfileId();
        // Set end_time to archive the income
        await _sb
            .from(
              'Fixed_Income',
            )
            .update(
              {
                'end_time': _iso(
                  DateTime.now(),
                ),
              },
            )
            .eq(
              'income_id',
              incomeId,
            )
            .eq(
              'profile_id',
              profileId,
            );
        await _loadAll();
      },
    );
  }

  void _confirmDeleteExpense(
    String expenseId,
  ) {
    _showDeleteConfirmation(
      title: 'Delete Expense',
      content: 'Are you sure you want to permanently delete this expense?',
      onConfirm: () async {
        final profileId = await _getProfileId();
        // Permanently delete the expense from database
        await _sb
            .from(
              'Fixed_Expense',
            )
            .delete()
            .eq(
              'expense_id',
              expenseId,
            )
            .eq(
              'profile_id',
              profileId,
            );
        await _loadAll();
      },
    );
  }

  void _confirmDeleteCategory(
    String categoryId,
  ) {
    _showDeleteConfirmation(
      title: 'Delete Category',
      content: 'Are you sure you want to delete this category?',
      onConfirm: () async {
        final profileId = await _getProfileId();
        await _sb
            .from(
              'Category',
            )
            .update(
              {
                'is_archived': true,
              },
            )
            .eq(
              'category_id',
              categoryId,
            )
            .eq(
              'profile_id',
              profileId,
            );
        await _loadAll();
      },
    );
  }

  // ----------------- Utils -----------------
  String _fmtMoney(
    dynamic v,
  ) {
    final d =
        (v
            is num)
        ? v.toDouble()
        : double.tryParse(
                v.toString(),
              ) ??
              0.0;
    return d.toStringAsFixed(
      2,
    );
  }

  String _iso(
    DateTime d,
  ) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _catName(
    String? id,
  ) {
    if (id ==
        null)
      return 'Uncategorized';
    final m = _categories.firstWhere(
      (
        c,
      ) =>
          c['category_id'] ==
          id,
      orElse: () =>
          <
            String,
            dynamic
          >{},
    );
    return (m.isEmpty)
        ? 'Uncategorized'
        : (m['name']
                  as String? ??
              '—');
  }

  Color _hexToColor(
    String value,
  ) {
    // Remove leading #
    value = value.replaceAll(
      '#',
      '',
    );

    // If it’s only digits and longer than 8 chars, treat as decimal Color.value
    final isDecimal =
        RegExp(
          r'^[0-9]+$',
        ).hasMatch(
          value,
        ) &&
        value.length >
            8;
    if (isDecimal) {
      final dec = int.parse(
        value,
      ); // decimal
      return Color(
        dec,
      ); // directly use ARGB int
    }

    // Otherwise treat as hex string (old users)
    if (value.length ==
        6) {
      value = 'FF$value'; // add full alpha
    }
    return Color(
      int.parse(
        value,
        radix: 16,
      ),
    );
  }

  void _showError(
    String message,
  ) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
