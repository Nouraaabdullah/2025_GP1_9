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

  // DEBUG override (keep null in production)
  DateTime? _debugCurrentDate = null;
  DateTime get _currentDate => _debugCurrentDate ?? DateTime.now();

  // ======= GET PROFILE ID =======
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

    _uniqueCategories = _removeDuplicateCategories(widget.categories);
    _loadExistingExpenses();

    if (widget.expense != null) {
      final name = widget.expense!['name'];
      if (name != null) _nameController.text = name.toString();

      final amount = widget.expense!['amount'];
      _amountController.text = amount != null ? amount.toString() : '0.0';

      final dueDate = widget.expense!['due_date'];
      _dueDayController.text = (dueDate is int ? dueDate : 27).toString();

      final categoryId = widget.expense!['category_id'];
      if (categoryId != null) _selectedCategoryId = categoryId.toString();
    } else {
      _dueDayController.text = '27';
    }
  }

  Future<void> _loadExistingExpenses() async {
    try {
      final profileId = await _getProfileId();
      final expensesData = await _sb
          .from('Fixed_Expense')
          .select('name, expense_id')
          .eq('profile_id', profileId)
          .filter('end_time', 'is', null);

      if (mounted) {
        setState(() {
          _existingExpenses =
              (expensesData as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (_) {
      // keep silent
    }
  }

  bool _isExpenseNameDuplicate(String name) {
    final trimmedName = name.trim().toLowerCase();
    for (final expense in _existingExpenses) {
      final existingName = (expense['name'] as String?)?.toLowerCase() ?? '';
      final existingId = expense['expense_id'] as String?;

      if (widget.expense != null) {
        final currentExpenseId = widget.expense!['expense_id'];
        if (existingId == currentExpenseId?.toString()) continue;
      }

      if (existingName == trimmedName) return true;
    }
    return false;
  }

  bool _isAmountExceedingLimit(double amount) {
    if (_selectedCategoryId == null) return false;

    try {
      final category = _uniqueCategories.firstWhere(
        (cat) => cat['category_id']?.toString() == _selectedCategoryId,
        orElse: () => <String, dynamic>{},
      );

      if (category.isEmpty) return false;

      final monthlyLimit = (category['monthly_limit'] as num?)?.toDouble();
      return monthlyLimit != null && monthlyLimit > 0 && amount > monthlyLimit;
    } catch (_) {
      return false;
    }
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return '';
    try {
      final category = _uniqueCategories.firstWhere(
        (cat) => cat['category_id']?.toString() == categoryId,
        orElse: () => <String, dynamic>{},
      );
      return category.isNotEmpty ? (category['name'] as String? ?? '') : '';
    } catch (_) {
      return '';
    }
  }

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
    } catch (_) {
      return null;
    }
  }

  // Dates helpers
  bool _isDueDayPassed(int dueDay) {
    final now = _currentDate;
    final d = _getDueDayDate(now.year, now.month, dueDay);
    return now.isAfter(d);
  }

  DateTime _getDueDayDate(int year, int month, int dueDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final actual = dueDay > lastDay ? lastDay : dueDay;
    return DateTime(year, month, actual);
  }

  bool _isBetweenDueDays(int oldDueDay, int newDueDay) {
    final now = _currentDate;
    final dOld = _getDueDayDate(now.year, now.month, oldDueDay);
    final dNew = _getDueDayDate(now.year, now.month, newDueDay);
    return now.isAfter(dOld) && now.isBefore(dNew);
  }

  // Show limit exceeded dialog
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
          ],
        ),
        actions: [
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
            child: const Text('Add', style: TextStyle(color: Colors.white)),
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
        final key = categoryId.toString();
        uniqueCategories.putIfAbsent(key, () => category);
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

  Future<void> _showSuccessDialog({required String message}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141427),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1F1F33),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.6),
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
                const SizedBox(height: 24),
                const Text(
                  'Done!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 120,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF704EF4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 16,
                      shadowColor: const Color(0xFF704EF4).withOpacity(0.7),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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

    if (_isAmountExceedingLimit(amount)) {
      _showLimitExceededDialog(amount, () {
        _performSave(name, amount);
      });
    } else {
      _performSave(name, amount);
    }
  }

  // ====== NEW: is_transacted decisions for EXPENSE ======
  bool _decideIsTransactedOnAdd({required int newDueDay}) {
    final today = _currentDate.day;
    if (newDueDay == today) return true; // transact now
    if (newDueDay < today) return false; // past → don't transact now
    return false; // future
  }

  bool _decideIsTransactedOnEdit({
    required bool currentIsTransacted,
    required int newDueDay,
  }) {
    final today = _currentDate.day;
    if (currentIsTransacted) return true; // keep true, only change date/fields
    if (newDueDay == today) return true; // transact now
    if (newDueDay < today) return true; // past & false → transact now
    return false; // future
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return v.isEmpty ? null : double.tryParse(v);
    return null;
  }

  // ====== NEW: apply EXPENSE to balance (subtract) ======
  Future<void> _applyExpenseToBalance({
    required String profileId,
    required double amount,
  }) async {
    final prof = await _sb
        .from('User_Profile')
        .select('current_balance')
        .eq('profile_id', profileId)
        .maybeSingle();

    final curr = _toDouble(prof?['current_balance']) ?? 0.0;
    await _sb
        .from('User_Profile')
        .update({'current_balance': curr - amount})
        .eq('profile_id', profileId);
  }

  Future<void> _performSave(String name, double amount) async {
    setState(() => _loading = true);

    try {
      final profileId = await _getProfileId();
      final now = _currentDate;
      final dueDay = int.tryParse(_dueDayController.text.trim()) ?? 27;

      final todayIso = _iso(now);

      if (widget.expense == null) {
        // ============== ADD NEW EXPENSE ==============
        final isTransactedNow = _decideIsTransactedOnAdd(newDueDay: dueDay);

        if (isTransactedNow) {
          // IMPORTANT: subtract from balance first
          await _applyExpenseToBalance(profileId: profileId, amount: amount);
        }

        await _sb.from('Fixed_Expense').insert({
          'name': name,
          'amount': amount,
          'due_date': dueDay,
          'category_id': _selectedCategoryId,
          'profile_id': profileId,
          'start_time': todayIso,
          'end_time': null,
          'is_transacted': isTransactedNow,
        });
      } else {
        // ============== EDIT EXISTING EXPENSE ==============
        final expenseId = widget.expense!['expense_id'];
        final originalAmount = _getSafeDouble(widget.expense!['amount']);
        final originalDueDay = widget.expense!['due_date'] ?? 27;

        final fresh = await _sb
            .from('Fixed_Expense')
            .select('is_transacted')
            .eq('expense_id', expenseId)
            .maybeSingle();

        final currentIsTransacted =
            (fresh?['is_transacted'] ??
                widget.expense?['is_transacted'] ??
                false) ==
            true;

        final amountChanged = amount != originalAmount;
        final dueDayChanged = dueDay != originalDueDay;

        // Decide new is_transacted
        final decidedIsTransacted = _decideIsTransactedOnEdit(
          currentIsTransacted: currentIsTransacted,
          newDueDay: dueDay,
        );

        // If we’re transitioning from false → true, subtract FIRST
        final willTransactNow = decidedIsTransacted && !currentIsTransacted;
        if (willTransactNow) {
          await _applyExpenseToBalance(profileId: profileId, amount: amount);
        }

        if (amountChanged) {
          // Archive old + insert new (carry is_transacted decision)
          await _sb
              .from('Fixed_Expense')
              .update({'end_time': todayIso})
              .eq('expense_id', expenseId);

          await _sb.from('Fixed_Expense').insert({
            'name': name,
            'amount': amount,
            'due_date': dueDay,
            'category_id': _selectedCategoryId,
            'profile_id': profileId,
            'start_time': todayIso,
            'end_time': null,
            'is_transacted': decidedIsTransacted,
          });
        } else if (dueDayChanged) {
          // Mirror your previous branching (using due day helpers), but always write is_transacted
          final oldDueDayPassed = _isDueDayPassed(originalDueDay);

          if (!oldDueDayPassed && dueDay > originalDueDay) {
            if (_isBetweenDueDays(originalDueDay, dueDay)) {
              // simple row update
              await _sb
                  .from('Fixed_Expense')
                  .update({
                    'name': name,
                    'due_date': dueDay,
                    'category_id': _selectedCategoryId,
                    'is_transacted': decidedIsTransacted,
                  })
                  .eq('expense_id', expenseId);
            } else {
              // archive + insert
              await _sb
                  .from('Fixed_Expense')
                  .update({'end_time': todayIso})
                  .eq('expense_id', expenseId);

              await _sb.from('Fixed_Expense').insert({
                'name': name,
                'amount': amount,
                'due_date': dueDay,
                'category_id': _selectedCategoryId,
                'profile_id': profileId,
                'start_time': todayIso,
                'end_time': null,
                'is_transacted': decidedIsTransacted,
              });
            }
          } else if (oldDueDayPassed) {
            // archive + insert
            await _sb
                .from('Fixed_Expense')
                .update({'end_time': todayIso})
                .eq('expense_id', expenseId);

            await _sb.from('Fixed_Expense').insert({
              'name': name,
              'amount': amount,
              'due_date': dueDay,
              'category_id': _selectedCategoryId,
              'profile_id': profileId,
              'start_time': todayIso,
              'end_time': null,
              'is_transacted': decidedIsTransacted,
            });
          } else if (!oldDueDayPassed && dueDay < now.day) {
            // moved due date earlier in the month → archive + insert
            await _sb
                .from('Fixed_Expense')
                .update({'end_time': todayIso})
                .eq('expense_id', expenseId);

            await _sb.from('Fixed_Expense').insert({
              'name': name,
              'amount': amount,
              'due_date': dueDay,
              'category_id': _selectedCategoryId,
              'profile_id': profileId,
              'start_time': todayIso,
              'end_time': null,
              'is_transacted': decidedIsTransacted,
            });
          } else {
            // simple row update
            await _sb
                .from('Fixed_Expense')
                .update({
                  'name': name,
                  'due_date': dueDay,
                  'category_id': _selectedCategoryId,
                  'is_transacted': decidedIsTransacted,
                })
                .eq('expense_id', expenseId);
          }
        } else {
          // Name/category only — still persist decided is_transacted
          await _sb
              .from('Fixed_Expense')
              .update({
                'name': name,
                'category_id': _selectedCategoryId,
                'is_transacted': decidedIsTransacted,
              })
              .eq('expense_id', expenseId);
        }
      }

      if (mounted) {
        await _showSuccessDialog(
          message: widget.expense == null
              ? 'Fixed expense added successfully.'
              : 'Fixed expense updated successfully.',
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
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
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI + helpers ----------
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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
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

  double _getSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtMoney(double value) => value.toStringAsFixed(2);

  String? _validateDueDay(String? value) {
    if (value == null || value.isEmpty) return 'Please enter due day';
    final dueDay = int.tryParse(value);
    if (dueDay == null) return 'Please enter a valid number';
    if (dueDay < 1 || dueDay > 31) return 'Due day must be between 1 and 31';
    return null;
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final dueDay = int.tryParse(_dueDayController.text.trim());
    final categoryName = _getCategoryName(_selectedCategoryId);

    if (amount == null || dueDay == null || _selectedCategoryId == null) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (widget.categories.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1F33),
        body: Stack(
          children: [
            Container(
              height: 230,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF704EF4),
                borderRadius: BorderRadius.only(
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
          Container(
            height: 230,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF704EF4),
              borderRadius: BorderRadius.only(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'Choose a category',
                                    style: TextStyle(color: Color(0xFF7A7A7A)),
                                  ),
                                ),
                                ..._uniqueCategories
                                    .map<DropdownMenuItem<String>>((category) {
                                  final categoryId =
                                      category['category_id']?.toString();
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
                          keyboardType: const TextInputType.numberWithOptions(
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

                      // Due Day
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

                      // Save
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
                            onPressed:
                                _loading ? null : _showConfirmationDialog,
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
