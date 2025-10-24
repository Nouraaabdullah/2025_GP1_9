import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart';

class AddEditIncomePage extends StatefulWidget {
  final Map<String, dynamic>? income;

  const AddEditIncomePage({super.key, this.income});

  @override
  State<AddEditIncomePage> createState() => _AddEditIncomePageState();
}

class _AddEditIncomePageState extends State<AddEditIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _paydayController = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _loading = false;
  List<Map<String, dynamic>> _existingIncomes = [];

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
    _loadExistingIncomes();
    // Pre-fill data if editing
    if (widget.income != null) {
      _nameController.text = widget.income!['name'] ?? '';
      _amountController.text = (widget.income!['monthly_income'] ?? 0.0)
          .toString();
      _paydayController.text = (widget.income!['payday'] ?? 27).toString();
    } else {
      _paydayController.text = '27'; // Default value
    }
  }

  Future<void> _loadExistingIncomes() async {
    try {
      final profileId = await _getProfileId();
      final incomesData = await _sb
          .from('Fixed_Income')
          .select('name, income_id')
          .eq('profile_id', profileId)
          .isFilter('end_time', null);

      if (mounted) {
        setState(() {
          _existingIncomes = (incomesData as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      // Silently fail, we'll still have basic validation
    }
  }

  // Check if income name already exists (excluding current income if editing)
  bool _isIncomeNameDuplicate(String name) {
    final trimmedName = name.trim().toLowerCase();
    for (final income in _existingIncomes) {
      final existingName = (income['name'] as String?)?.toLowerCase() ?? '';
      final existingId = income['income_id'] as String?;

      // If editing, exclude the current income from duplicate check
      if (widget.income != null && existingId == widget.income!['income_id']) {
        continue;
      }

      if (existingName == trimmedName) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _paydayController.dispose();
    super.dispose();
  }

  // Helper method to check if payday has passed in current month
  bool _isPaydayPassed(int payDay) {
    final now = DateTime.now();

    // Get the actual payday date for current month
    final currentMonthPayday = _getPaydayDate(now.year, now.month, payDay);

    return now.isAfter(currentMonthPayday);
  }

  // Helper method to get the actual payday date (handles invalid dates like Feb 30)
  DateTime _getPaydayDate(int year, int month, int payDay) {
    // Get the last day of the month
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;

    // If payday is greater than last day of month, use last day
    final actualPayDay = payDay > lastDayOfMonth ? lastDayOfMonth : payDay;

    return DateTime(year, month, actualPayDay);
  }

  // Helper method to check if we're between paydays
  bool _isBetweenPaydays(int oldPayDay, int newPayDay) {
    final now = DateTime.now();

    final currentMonth = now.month;
    final currentYear = now.year;

    // Get actual payday dates considering month boundaries
    final oldPaydayDate = _getPaydayDate(currentYear, currentMonth, oldPayDay);
    final newPaydayDate = _getPaydayDate(currentYear, currentMonth, newPayDay);

    return now.isAfter(oldPaydayDate) && now.isBefore(newPaydayDate);
  }

  // Get current monthly record ID
  Future<String?> _getCurrentMonthlyRecordId() async {
    final profileId = await _getProfileId();
    final now = DateTime.now();
    final monthlyRecords = await _sb
        .from('Monthly_Financial_Record')
        .select('record_id, period_start, period_end')
        .eq('profile_id', profileId)
        .order('period_start', ascending: false);

    for (final record in monthlyRecords) {
      final periodStart = DateTime.parse(record['period_start'] as String);
      final periodEnd = DateTime.parse(record['period_end'] as String);

      if (now.isAfter(periodStart) && now.isBefore(periodEnd)) {
        return record['record_id'] as String;
      }
    }
    return null;
  }

  // Update monthly record with income change
  Future<void> _updateMonthlyRecordIncome(
    double amountChange,
    bool isAdding,
  ) async {
    try {
      final recordId = await _getCurrentMonthlyRecordId();
      if (recordId == null) {
        print('No current monthly record found');
        return;
      }

      // Get current monthly record
      final monthlyRecord = await _sb
          .from('Monthly_Financial_Record')
          .select('total_income, total_balance, total_expense')
          .eq('record_id', recordId)
          .single();

      final currentIncome = _toDouble(monthlyRecord['total_income']) ?? 0.0;
      final currentBalance = _toDouble(monthlyRecord['total_balance']) ?? 0.0;
      final currentExpense = _toDouble(monthlyRecord['total_expense']) ?? 0.0;

      double newIncome;
      double newBalance;

      if (isAdding) {
        newIncome = currentIncome + amountChange;
        newBalance = currentBalance + amountChange;
      } else {
        newIncome = currentIncome - amountChange;
        newBalance = currentBalance - amountChange;
      }

      // Update monthly record
      await _sb
          .from('Monthly_Financial_Record')
          .update({
            'total_income': newIncome,
            'total_balance': newBalance,
            'monthly_saving': newIncome - currentExpense,
          })
          .eq('record_id', recordId);

      print(
        'Monthly record updated: Income ${isAdding ? 'increased' : 'decreased'} by $amountChange',
      );
    } catch (e) {
      print('Error updating monthly record: $e');
    }
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final profileId = await _getProfileId();
      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final payDay = int.tryParse(_paydayController.text.trim()) ?? 27;
      final now = DateTime.now();

      // Debug logging
      print('=== Income Update Debug ===');
      print('Current date: $now');
      print('Current day: ${now.day}');
      print('Payday: $payDay');
      print('Payday passed: ${_isPaydayPassed(payDay)}');

      if (widget.income == null) {
        // Add new income
        await _sb.from('Fixed_Income').insert({
          'name': name,
          'monthly_income': amount,
          'payday': payDay,
          'profile_id': profileId,
          'start_time': _iso(now),
          'end_time': null,
          'is_primary': false,
        });

        // Update monthly record with new income
        await _updateMonthlyRecordIncome(amount, true);
      } else {
        // Update existing income - Handle all cases
        final incomeId = widget.income!['income_id'];
        final originalAmount =
            (widget.income!['monthly_income'] as num?)?.toDouble() ?? 0.0;
        final originalPayDay = widget.income!['payday'] ?? 27;
        final isPrimary = widget.income!['is_primary'] ?? false;

        final amountChanged = amount != originalAmount;
        final payDayChanged = payDay != originalPayDay;

        // Debug logging for edits
        print('Original payday: $originalPayDay');
        print('New payday: $payDay');
        print('Amount changed: $amountChanged');
        print('Payday changed: $payDayChanged');
        print('Old payday passed: ${_isPaydayPassed(originalPayDay)}');
        print('New payday passed: ${_isPaydayPassed(payDay)}');

        if (amountChanged) {
          // Case 1: Amount changed - archive old record and create new one
          print('Case 1: Amount changed - archiving old and creating new');
          await _sb
              .from('Fixed_Income')
              .update({'end_time': _iso(now)})
              .eq('income_id', incomeId);

          await _sb.from('Fixed_Income').insert({
            'name': name,
            'monthly_income': amount,
            'payday': payDay,
            'profile_id': profileId,
            'start_time': _iso(now),
            'end_time': null,
            'is_primary': isPrimary,
          });

          // Update monthly record with amount difference
          final amountDifference = amount - originalAmount;
          if (amountDifference != 0) {
            await _updateMonthlyRecordIncome(
              amountDifference.abs(),
              amountDifference > 0,
            );
          }
        } else if (payDayChanged) {
          // Case 2: Pay day changed
          final oldPayDayPassed = _isPaydayPassed(originalPayDay);
          final newPayDayPassed = _isPaydayPassed(payDay);

          if (!oldPayDayPassed && payDay > originalPayDay) {
            // Case 2a: Old payday NOT passed AND new payday > old payday
            if (_isBetweenPaydays(originalPayDay, payDay)) {
              print('Case 2a: Between paydays - updating same row');
              // Just update the payday in the same row
              await _sb
                  .from('Fixed_Income')
                  .update({'name': name, 'payday': payDay})
                  .eq('income_id', incomeId);
            } else {
              print(
                'Case 2a: Not between paydays - archiving and creating new',
              );
              // Current day is before old payday, archive and create new
              await _sb
                  .from('Fixed_Income')
                  .update({'end_time': _iso(now)})
                  .eq('income_id', incomeId);

              await _sb.from('Fixed_Income').insert({
                'name': name,
                'monthly_income': amount,
                'payday': payDay,
                'profile_id': profileId,
                'start_time': _iso(now),
                'end_time': null,
                'is_primary': isPrimary,
              });
            }
          } else if (oldPayDayPassed) {
            // Case 2b: Old payday has passed (income already added this month)
            print('Case 2b: Old payday passed - archiving and creating new');
            // Update payday for future income only - archive current and create new
            await _sb
                .from('Fixed_Income')
                .update({'end_time': _iso(now)})
                .eq('income_id', incomeId);

            await _sb.from('Fixed_Income').insert({
              'name': name,
              'monthly_income': amount,
              'payday': payDay,
              'profile_id': profileId,
              'start_time': _iso(now),
              'end_time': null,
              'is_primary': isPrimary,
            });
          } else if (!oldPayDayPassed && payDay < now.day) {
            // Case 2c: Payday NOT passed AND user updates payday to be in the past
            print('Case 2c: New payday in past - archiving and creating new');
            // Archive current and create new with updated payday
            await _sb
                .from('Fixed_Income')
                .update({'end_time': _iso(now)})
                .eq('income_id', incomeId);

            await _sb.from('Fixed_Income').insert({
              'name': name,
              'monthly_income': amount,
              'payday': payDay,
              'profile_id': profileId,
              'start_time': _iso(now),
              'end_time': null,
              'is_primary': isPrimary,
            });
          } else {
            // Default case: Just update name and payday
            print('Default case: Updating same row');
            await _sb
                .from('Fixed_Income')
                .update({'name': name, 'payday': payDay})
                .eq('income_id', incomeId);
          }
        } else {
          // Only name changed - simple update
          print('Only name changed - updating same row');
          await _sb
              .from('Fixed_Income')
              .update({'name': name})
              .eq('income_id', incomeId);
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving income: $e'),
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
    final payDay = int.tryParse(_paydayController.text.trim());

    if (amount == null || payDay == null) return;

    final originalAmount = widget.income != null
        ? (widget.income!['monthly_income'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final amountChanged = widget.income != null && amount != originalAmount;
    final double difference = amount - originalAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.income == null ? 'Add Income' : 'Update Income',
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
              widget.income == null
                  ? 'Are you sure you want to add this income?'
                  : 'Are you sure you want to update this income?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildConfirmationRow('Income Name', name),
            _buildConfirmationRow('Monthly Amount', '${_fmtMoney(amount)} SAR'),
            _buildConfirmationRow('Pay Day', '$payDay'),
            if (amountChanged && widget.income != null) ...[
              const SizedBox(height: 8),
              _buildConfirmationRow(
                'Amount Change',
                '${_fmtMoney(difference.abs())} SAR',
                isHighlighted: true,
                color: difference > 0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
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
              _saveIncome();
            },
            child: Text(
              widget.income == null ? 'Add Income' : 'Update Income',
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

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v.isEmpty) return null;
      return double.tryParse(v);
    }
    return null;
  }

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }

  // Payday validation
  String? _validatePayDay(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter pay day';
    }

    final payDay = int.tryParse(value);
    if (payDay == null) {
      return 'Please enter a valid number';
    }

    if (payDay < 1 || payDay > 31) {
      return 'Pay day must be between 1 and 31';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
                        widget.income == null ? 'Add Income' : 'Edit Income',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Income Name
                      const _FieldLabel('Income Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter income name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter income name';
                            }
                            if (_isIncomeNameDuplicate(value)) {
                              return 'This income name already exists';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Monthly Amount
                      const _FieldLabel('Monthly Amount (SAR)'),
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

                      // Pay Day (Text Field)
                      const _FieldLabel('Pay Day (1-31)'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _paydayController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter pay day (1-31)',
                          ),
                          validator: _validatePayDay,
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
                                    widget.income == null
                                        ? 'Add Income'
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
