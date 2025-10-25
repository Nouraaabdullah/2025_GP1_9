import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart';

class AddEditExpensePage extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final List<Map<String, dynamic>> categories;

  const AddEditExpensePage({super.key, this.expense, required this.categories});

  @override
  State<AddEditExpensePage> createState() => _AddEditExpensePageState();
}

class _AddEditExpensePageState extends State<AddEditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDayController = TextEditingController();
  String? _selectedCategoryId;
  final _sb = Supabase.instance.client;

  bool _loading = false;
  late List<Map<String, dynamic>> _uniqueCategories;
  List<Map<String, dynamic>> _existingExpenses = [];

  // DEBUG: Override current date for testing (set to null for production)
  DateTime? _debugCurrentDate = null;
  // DateTime? _debugCurrentDate = DateTime(2024, 3, 20); // Test Case 2a
  // DateTime? _debugCurrentDate = DateTime(2024, 3, 28); // Test Case 2b
  // DateTime? _debugCurrentDate = DateTime(2024, 3, 20); // Test Case 2c

  // Helper method to get current date (uses debug override if set)
  DateTime get _currentDate {
    return _debugCurrentDate ?? DateTime.now();
  }

  // ======= GET PROFILE ID USING UTILITY FUNCTION =======
  Future<String> _getProfileId() async {
    final profileId = await getProfileId(context);
    if (profileId == null) {
      throw Exception('User not authenticated');
    }
    return profileId;
  }

  @override
  void initState() {
    super.initState();

    // REMOVE DUPLICATE CATEGORIES - FIX FOR DROPDOWN ERROR
    _uniqueCategories = _removeDuplicateCategories(widget.categories);

    // Load existing expenses for duplicate name validation
    _loadExistingExpenses();

    // Pre-fill data if editing - COMPLETELY SAFE APPROACH
    if (widget.expense != null) {
      // Safely get name
      final name = widget.expense!['name'];
      if (name != null) {
        _nameController.text = name.toString();
      }

      // Safely get amount
      final amount = widget.expense!['amount'];
      if (amount != null) {
        _amountController.text = amount.toString();
      } else {
        _amountController.text = '0.0';
      }

      // Safely get due date
      final dueDate = widget.expense!['due_date'];
      if (dueDate != null) {
        _dueDayController.text = (dueDate is int ? dueDate : 27).toString();
      } else {
        _dueDayController.text = '27';
      }

      // Safely get category ID - THIS IS THE MAIN FIX
      final categoryId = widget.expense!['category_id'];
      if (categoryId != null) {
        _selectedCategoryId = categoryId.toString();
      }
    } else {
      _dueDayController.text = '27'; // Default value
    }
  }

  Future<void> _loadExistingExpenses() async {
    try {
      final profileId = await _getProfileId();
      final expensesData = await _sb
          .from('Fixed_Expense')
          .select('name, expense_id')
          .eq('profile_id', profileId)
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
      if (widget.expense != null) {
        final currentExpenseId = widget.expense!['expense_id'];
        if (existingId == currentExpenseId?.toString()) {
          continue;
        }
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

    try {
      final category = _uniqueCategories.firstWhere((cat) {
        final catId = cat['category_id']?.toString();
        return catId == _selectedCategoryId;
      }, orElse: () => <String, dynamic>{});

      if (category.isEmpty) return false;

      final monthlyLimit = (category['monthly_limit'] as num?)?.toDouble();
      return monthlyLimit != null && monthlyLimit > 0 && amount > monthlyLimit;
    } catch (e) {
      return false;
    }
  }

  // Get category name by ID
  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return '';
    try {
      final category = _uniqueCategories.firstWhere(
        (cat) => cat['category_id']?.toString() == categoryId,
        orElse: () => <String, dynamic>{},
      );
      return category.isNotEmpty ? (category['name'] as String? ?? '') : '';
    } catch (e) {
      return '';
    }
  }

  // Get category limit by ID
  double? _getCategoryLimit(String? categoryId) {
    if (categoryId == null) return null;
    try {
      final category = _uniqueCategories.firstWhere(
        (cat) => cat['category_id']?.toString() == categoryId,
        orElse: () => <String, dynamic>{},
      );
      return category.isNotEmpty
          ? (category['monthly_limit'] as num?)?.toDouble()
          : null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to check if due day has passed in current month
  bool _isDueDayPassed(int dueDay) {
    final now = _currentDate;

    // Get the actual due day date for current month
    final currentMonthDueDay = _getDueDayDate(now.year, now.month, dueDay);

    return now.isAfter(currentMonthDueDay);
  }

  // Helper method to get the actual due day date (handles invalid dates like Feb 30)
  DateTime _getDueDayDate(int year, int month, int dueDay) {
    // Get the last day of the month
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;

    // If due day is greater than last day of month, use last day
    final actualDueDay = dueDay > lastDayOfMonth ? lastDayOfMonth : dueDay;

    return DateTime(year, month, actualDueDay);
  }

  // Helper method to check if we're between due days
  bool _isBetweenDueDays(int oldDueDay, int newDueDay) {
    final now = _currentDate;

    final currentMonth = now.month;
    final currentYear = now.year;

    // Get actual due day dates considering month boundaries
    final oldDueDayDate = _getDueDayDate(currentYear, currentMonth, oldDueDay);
    final newDueDayDate = _getDueDayDate(currentYear, currentMonth, newDueDay);

    return now.isAfter(oldDueDayDate) && now.isBefore(newDueDayDate);
  }

  void _showLimitExceededDialog(double amount, Function onConfirm) {
    final categoryName = _getCategoryName(_selectedCategoryId);
    final categoryLimit = _getCategoryLimit(_selectedCategoryId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Category Limit Exceeded',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            _buildConfirmationRow('Expense Amount', '${_fmtMoney(amount)} SAR'),
            _buildConfirmationRow(
              'Category Limit',
              '${_fmtMoney(categoryLimit ?? 0)} SAR',
            ),
            _buildConfirmationRow(
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
              backgroundColor: const Color(0xFF704EF4),
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

  List<Map<String, dynamic>> _removeDuplicateCategories(
    List<Map<String, dynamic>> categories,
  ) {
    final uniqueCategories = <String, Map<String, dynamic>>{};

    for (final category in categories) {
      final categoryId = category['category_id'];
      if (categoryId != null) {
        final categoryIdString = categoryId.toString();
        if (!uniqueCategories.containsKey(categoryIdString)) {
          uniqueCategories[categoryIdString] = category;
        }
      }
    }

    return uniqueCategories.values.toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
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
      final profileId = await _getProfileId();
      final now = _currentDate;
      final dueDay = int.tryParse(_dueDayController.text.trim()) ?? 27;

      // Debug logging
      print('=== Expense Update Debug ===');
      print('Current date: $now');
      print('Current day: ${now.day}');
      print('Due day: $dueDay');
      print('Due day passed: ${_isDueDayPassed(dueDay)}');

      if (widget.expense == null) {
        // Add new expense
        await _sb.from('Fixed_Expense').insert({
          'name': name,
          'amount': amount,
          'due_date': dueDay,
          'category_id': _selectedCategoryId,
          'profile_id': profileId,
          'start_time': _iso(now),
          'end_time': null,
        });
      } else {
        // Update existing expense - Handle all cases
        final expenseId = widget.expense!['expense_id'];
        final originalAmount = _getSafeDouble(widget.expense!['amount']);
        final originalDueDay = widget.expense!['due_date'] ?? 27;

        final amountChanged = amount != originalAmount;
        final dueDayChanged = dueDay != originalDueDay;

        // Debug logging for edits
        print('Original due day: $originalDueDay');
        print('New due day: $dueDay');
        print('Amount changed: $amountChanged');
        print('Due day changed: $dueDayChanged');
        print('Old due day passed: ${_isDueDayPassed(originalDueDay)}');
        print('New due day passed: ${_isDueDayPassed(dueDay)}');

        if (amountChanged) {
          // Case 1: Amount changed - archive old record and create new one
          print('Case 1: Amount changed - archiving old and creating new');
          await _sb
              .from('Fixed_Expense')
              .update({'end_time': _iso(now)})
              .eq('expense_id', expenseId);

          await _sb.from('Fixed_Expense').insert({
            'name': name,
            'amount': amount,
            'due_date': dueDay,
            'category_id': _selectedCategoryId,
            'profile_id': profileId,
            'start_time': _iso(now),
            'end_time': null,
          });
        } else if (dueDayChanged) {
          // Case 2: Due day changed
          final oldDueDayPassed = _isDueDayPassed(originalDueDay);
          final newDueDayPassed = _isDueDayPassed(dueDay);

          if (!oldDueDayPassed && dueDay > originalDueDay) {
            // Case 2a: Old due day NOT passed AND new due day > old due day
            if (_isBetweenDueDays(originalDueDay, dueDay)) {
              print('Case 2a: Between due days - updating same row');
              // Just update the due day in the same row
              await _sb
                  .from('Fixed_Expense')
                  .update({
                    'name': name,
                    'due_date': dueDay,
                    'category_id': _selectedCategoryId,
                  })
                  .eq('expense_id', expenseId);
            } else {
              print(
                'Case 2a: Not between due days - archiving and creating new',
              );
              // Current day is before old due day, archive and create new
              await _sb
                  .from('Fixed_Expense')
                  .update({'end_time': _iso(now)})
                  .eq('expense_id', expenseId);

              await _sb.from('Fixed_Expense').insert({
                'name': name,
                'amount': amount,
                'due_date': dueDay,
                'category_id': _selectedCategoryId,
                'profile_id': profileId,
                'start_time': _iso(now),
                'end_time': null,
              });
            }
          } else if (oldDueDayPassed) {
            // Case 2b: Old due day has passed (expense already occurred this month)
            print('Case 2b: Old due day passed - archiving and creating new');
            // Update due day for future expense only - archive current and create new
            await _sb
                .from('Fixed_Expense')
                .update({'end_time': _iso(now)})
                .eq('expense_id', expenseId);

            await _sb.from('Fixed_Expense').insert({
              'name': name,
              'amount': amount,
              'due_date': dueDay,
              'category_id': _selectedCategoryId,
              'profile_id': profileId,
              'start_time': _iso(now),
              'end_time': null,
            });
          } else if (!oldDueDayPassed && dueDay < now.day) {
            // Case 2c: Due day NOT passed AND user updates due day to be in the past
            print('Case 2c: New due day in past - archiving and creating new');
            // Archive current and create new with updated due day
            await _sb
                .from('Fixed_Expense')
                .update({'end_time': _iso(now)})
                .eq('expense_id', expenseId);

            await _sb.from('Fixed_Expense').insert({
              'name': name,
              'amount': amount,
              'due_date': dueDay,
              'category_id': _selectedCategoryId,
              'profile_id': profileId,
              'start_time': _iso(now),
              'end_time': null,
            });
          } else {
            // Default case: Just update name, category and due day
            print('Default case: Updating same row');
            await _sb
                .from('Fixed_Expense')
                .update({
                  'name': name,
                  'due_date': dueDay,
                  'category_id': _selectedCategoryId,
                })
                .eq('expense_id', expenseId);
          }
        } else {
          // Only name or category changed - simple update
          print('Only name/category changed - updating same row');
          await _sb
              .from('Fixed_Expense')
              .update({'name': name, 'category_id': _selectedCategoryId})
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

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final dueDay = int.tryParse(_dueDayController.text.trim());
    final categoryName = _getCategoryName(_selectedCategoryId);

    if (amount == null || dueDay == null || _selectedCategoryId == null) return;

    final originalAmount = widget.expense != null
        ? _getSafeDouble(widget.expense!['amount'])
        : 0.0;

    final amountChanged = widget.expense != null && amount != originalAmount;
    final double difference = amount - originalAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.expense == null ? 'Add Expense' : 'Update Expense',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.expense == null
                  ? 'Are you sure you want to add this expense?'
                  : 'Are you sure you want to update this expense?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildConfirmationRow('Expense Name', name),
            _buildConfirmationRow('Category', categoryName),
            _buildConfirmationRow('Amount', '${_fmtMoney(amount)} SAR'),
            _buildConfirmationRow('Due Day', '$dueDay'),
            if (amountChanged && widget.expense != null) ...[
              const SizedBox(height: 8),
              _buildConfirmationRow(
                'Amount Change',
                '${_fmtMoney(difference.abs())} SAR',
                isHighlighted: true,
                color: difference > 0
                    ? const Color(0xFFF44336) // Red for expense increase
                    : const Color(0xFF4CAF50), // Green for expense decrease
              ),
            ],
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
              backgroundColor: const Color(0xFF704EF4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _saveExpense();
            },
            child: Text(
              widget.expense == null ? 'Add Expense' : 'Update Expense',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(
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
                  (isHighlighted ? const Color(0xFF704EF4) : Colors.white),
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to safely get double values
  double _getSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }

  // Due day validation
  String? _validateDueDay(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter due day';
    }

    final dueDay = int.tryParse(value);
    if (dueDay == null) {
      return 'Please enter a valid number';
    }

    if (dueDay < 1 || dueDay > 31) {
      return 'Due day must be between 1 and 31';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Check if categories are available
    if (widget.categories.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1F33),
        body: Stack(
          children: [
            // Top gradient background
            Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF704EF4),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B48),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No Categories Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
                        backgroundColor: const Color(0xFF704EF4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(72),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F33),
      body: Stack(
        children: [
          // Top gradient background
          Container(
            height: 230,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF704EF4),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Main content
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: size.width,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B48),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.expense == null ? 'Add Expense' : 'Edit Expense',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Expense Name
                      const _FieldLabel('Expense Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter expense name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter expense name';
                            }
                            if (_isExpenseNameDuplicate(value)) {
                              return 'This expense name already exists';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Category
                      const _FieldLabel('Category'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategoryId,
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
                                ..._uniqueCategories
                                    .map<DropdownMenuItem<String>>((category) {
                                      final categoryId = category['category_id']
                                          ?.toString();
                                      final categoryName =
                                          category['name'] as String? ??
                                          'Unnamed Category';

                                      return DropdownMenuItem<String>(
                                        value: categoryId,
                                        child: Text(
                                          categoryName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                      );
                                    }),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategoryId = value);
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Amount
                      const _FieldLabel('Amount (SAR)'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration().copyWith(
                            hintText: '0.00',
                          ),
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
                      ),
                      const SizedBox(height: 18),

                      // Due Day (Text Field)
                      const _FieldLabel('Due Day (1-31)'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _dueDayController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter due day (1-31)',
                          ),
                          validator: _validateDueDay,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save Button
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF704EF4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(72),
                              ),
                              elevation: 10,
                              shadowColor: const Color(0xFF704EF4),
                            ),
                            onPressed: _loading
                                ? null
                                : _showConfirmationDialog,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    widget.expense == null
                                        ? 'Add Expense'
                                        : 'Save Changes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _rounded({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
