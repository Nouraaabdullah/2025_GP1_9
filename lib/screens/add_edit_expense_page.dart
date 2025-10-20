import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditExpensePage extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final String profileId;
  final List<Map<String, dynamic>> categories;

  const AddEditExpensePage({
    super.key,
    this.expense,
    required this.profileId,
    required this.categories,
  });

  @override
  State<AddEditExpensePage> createState() => _AddEditExpensePageState();
}

class _AddEditExpensePageState extends State<AddEditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  int _selectedDueDay = 27;
  String? _selectedCategoryId;
  final _sb = Supabase.instance.client;

  bool _loading = false;
  late List<Map<String, dynamic>> _uniqueCategories;
  List<Map<String, dynamic>> _existingExpenses = [];

  @override
  void initState() {
    super.initState();

    // REMOVE DUPLICATE CATEGORIES - FIX FOR DROPDOWN ERROR
    _uniqueCategories = _removeDuplicateCategories(widget.categories);

    // Load existing expenses for duplicate name validation
    _loadExistingExpenses();

    // Pre-fill data if editing
    if (widget.expense != null) {
      _nameController.text = widget.expense!['name'] ?? '';
      _amountController.text = (widget.expense!['amount'] ?? 0.0).toString();
      _selectedDueDay = widget.expense!['due_date'] ?? 27;
      _selectedCategoryId = widget.expense!['category_id'];
    }

    // Don't set default category - user must choose one
  }

  Future<void> _loadExistingExpenses() async {
    try {
      final expensesData = await _sb
          .from('Fixed_Expense')
          .select('name, expense_id')
          .eq('profile_id', widget.profileId)
          .isFilter('end_time', null);

      if (mounted) {
        setState(() {
          _existingExpenses = (expensesData as List)
              .cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      // Silently fail, we'll still have basic validation
    }
  }

  // Check if expense name already exists (excluding current expense if editing)
  bool _isExpenseNameDuplicate(String name) {
    final trimmedName = name.trim().toLowerCase();
    for (final expense in _existingExpenses) {
      final existingName = (expense['name'] as String?)?.toLowerCase() ?? '';
      final existingId = expense['expense_id'] as String?;

      // If editing, exclude the current expense from duplicate check
      if (widget.expense != null &&
          existingId == widget.expense!['expense_id']) {
        continue;
      }

      if (existingName == trimmedName) {
        return true;
      }
    }
    return false;
  }

  // Check if amount exceeds category limit
  bool _isAmountExceedingLimit(double amount) {
    if (_selectedCategoryId == null) return false;

    final category = _uniqueCategories.firstWhere(
      (cat) => cat['category_id'] == _selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );

    if (category.isEmpty) return false;

    final monthlyLimit = (category['monthly_limit'] as num?)?.toDouble();
    return monthlyLimit != null && monthlyLimit > 0 && amount > monthlyLimit;
  }

  // Get category name by ID
  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return '';
    final category = _uniqueCategories.firstWhere(
      (cat) => cat['category_id'] == categoryId,
      orElse: () => <String, dynamic>{},
    );
    return category.isNotEmpty ? (category['name'] as String? ?? '') : '';
  }

  // Get category limit by ID
  double? _getCategoryLimit(String? categoryId) {
    if (categoryId == null) return null;
    final category = _uniqueCategories.firstWhere(
      (cat) => cat['category_id'] == categoryId,
      orElse: () => <String, dynamic>{},
    );
    return category.isNotEmpty
        ? (category['monthly_limit'] as num?)?.toDouble()
        : null;
  }

  void _showLimitExceededDialog(double amount, Function onConfirm) {
    final categoryName = _getCategoryName(_selectedCategoryId);
    final categoryLimit = _getCategoryLimit(_selectedCategoryId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Category Limit Exceeded',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This expense amount exceeds the monthly limit for "$categoryName":',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildLimitRow('Expense Amount', '${_fmtMoney(amount)} SAR'),
            _buildLimitRow(
              'Category Limit',
              '${_fmtMoney(categoryLimit ?? 0)} SAR',
            ),
            _buildLimitRow(
              'Excess Amount',
              '${_fmtMoney(amount - (categoryLimit ?? 0))} SAR',
              isHighlighted: true,
              color: const Color(0xFFF44336),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to add this expense?',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text(
              'Add Anyway',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(
    String label,
    String value, {
    bool isHighlighted = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color:
                  color ??
                  (isHighlighted ? const Color(0xFF5E52E6) : Colors.white),
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _removeDuplicateCategories(
    List<Map<String, dynamic>> categories,
  ) {
    final uniqueCategories = <String, Map<String, dynamic>>{};

    for (final category in categories) {
      final categoryId = category['category_id'] as String?;
      if (categoryId != null && !uniqueCategories.containsKey(categoryId)) {
        uniqueCategories[categoryId] = category;
      }
    }

    return uniqueCategories.values.toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    // Check if amount exceeds category limit
    if (_isAmountExceedingLimit(amount)) {
      _showLimitExceededDialog(amount, () {
        _performSave(name, amount);
      });
    } else {
      _performSave(name, amount);
    }
  }

  Future<void> _performSave(String name, double amount) async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();

      if (widget.expense == null) {
        // Add new expense
        await _sb.from('Fixed_Expense').insert({
          'name': name,
          'amount': amount,
          'due_date': _selectedDueDay,
          'category_id': _selectedCategoryId,
          'profile_id': widget.profileId,
          'start_time': _iso(now),
          'end_time': null,
        });
      } else {
        // Update existing expense
        final expenseId = widget.expense!['expense_id'];
        final originalAmount =
            (widget.expense!['amount'] as num?)?.toDouble() ?? 0.0;

        if (amount != originalAmount) {
          // Archive old and create new if amount changed
          await _sb
              .from('Fixed_Expense')
              .update({'end_time': _iso(now)})
              .eq('expense_id', expenseId);

          await _sb.from('Fixed_Expense').insert({
            'name': name,
            'amount': amount,
            'due_date': _selectedDueDay,
            'category_id': _selectedCategoryId,
            'profile_id': widget.profileId,
            'start_time': _iso(now),
            'end_time': null,
          });
        } else {
          // Just update other fields if amount unchanged
          await _sb
              .from('Fixed_Expense')
              .update({
                'name': name,
                'due_date': _selectedDueDay,
                'category_id': _selectedCategoryId,
              })
              .eq('expense_id', expenseId);
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
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

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    // Check if categories are available
    if (widget.categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No Categories Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please create at least one category before adding expenses.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E52E6),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1D33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D33),
        title: Text(
          widget.expense == null ? 'Add Expense' : 'Edit Expense',
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
              _buildSheetLabel('Expense Name'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _nameController,
                hintText: 'Enter expense name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter expense name';
                  }

                  // Check for duplicate name
                  if (_isExpenseNameDuplicate(value)) {
                    return 'This expense name already exists';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Category'),
              const SizedBox(height: 8),
              _buildWhiteDropdown<String>(
                value: _selectedCategoryId,
                items: [
                  // "Choose a category" option
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'Choose a category',
                      style: TextStyle(color: Color(0xFF7A7A7A)),
                    ),
                  ),
                  // Category options
                  ..._uniqueCategories.map<DropdownMenuItem<String>>(
                    (c) => DropdownMenuItem(
                      value: c['category_id'] as String,
                      child: Text(
                        c['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedCategoryId = v);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // AMOUNT FIELD BEFORE DUE DATE
              _buildSheetLabel('Amount (SAR)'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _amountController,
                hintText: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amt = double.tryParse(value);
                  if (amt == null || amt <= 0) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Due Day (1-31)'),
              const SizedBox(height: 8),
              _buildWhiteDropdown<int>(
                value: _selectedDueDay,
                items: List.generate(
                  31,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                ),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedDueDay = v);
                  }
                },
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

  Widget _buildWhiteDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    // ADD VALIDATION TO ENSURE NO DUPLICATE VALUES
    final uniqueItems = <T, DropdownMenuItem<T>>{};
    for (final item in items) {
      if (item.value != null && !uniqueItems.containsKey(item.value)) {
        uniqueItems[item.value as T] = item;
      } else if (item.value == null) {
        // Always include the null item (Choose a category)
        uniqueItems[item.value as T] = item;
      }
    }
    final finalItems = uniqueItems.values.toList();

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1E1E1E),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          items: finalItems,
          onChanged: onChanged,
          validator: validator as String? Function(T?)?,
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
            onPressed: _loading ? null : _saveExpense,
            child: Text(
              widget.expense == null ? 'Add Expense' : 'Save Changes',
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
