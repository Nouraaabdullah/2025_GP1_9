import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditIncomePage extends StatefulWidget {
  final Map<String, dynamic>? income;
  final String profileId;

  const AddEditIncomePage({super.key, this.income, required this.profileId});

  @override
  State<AddEditIncomePage> createState() => _AddEditIncomePageState();
}

class _AddEditIncomePageState extends State<AddEditIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  int _selectedPayDay = 27;
  final _sb = Supabase.instance.client;

  bool _loading = false;
  List<Map<String, dynamic>> _existingIncomes = [];

  @override
  void initState() {
    super.initState();
    _loadExistingIncomes();
    // Pre-fill data if editing
    if (widget.income != null) {
      _nameController.text = widget.income!['name'] ?? '';
      _amountController.text = (widget.income!['monthly_income'] ?? 0.0)
          .toString();
      _selectedPayDay = widget.income!['payday'] ?? 27;
    }
  }

  Future<void> _loadExistingIncomes() async {
    try {
      final incomesData = await _sb
          .from('Fixed_Income')
          .select('name, income_id')
          .eq('profile_id', widget.profileId)
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
    super.dispose();
  }

  // Get current monthly record ID
  Future<String?> _getCurrentMonthlyRecordId() async {
    final now = DateTime.now();
    final monthlyRecords = await _sb
        .from('Monthly_Financial_Record')
        .select('record_id, period_start, period_end')
        .eq('profile_id', widget.profileId)
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
          .select('total_income, total_balance')
          .eq('record_id', recordId)
          .single();

      final currentIncome = _toDouble(monthlyRecord['total_income']) ?? 0.0;
      final currentBalance = _toDouble(monthlyRecord['total_balance']) ?? 0.0;

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
            'monthly_saving':
                newIncome - (_toDouble(monthlyRecord['total_expense']) ?? 0.0),
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
      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final now = DateTime.now();

      if (widget.income == null) {
        // Add new income
        await _sb.from('Fixed_Income').insert({
          'name': name,
          'monthly_income': amount,
          'payday': _selectedPayDay,
          'profile_id': widget.profileId,
          'start_time': _iso(now),
          'end_time': null,
        });

        // Update monthly record with new income
        await _updateMonthlyRecordIncome(amount, true);
      } else {
        // Update existing income
        final incomeId = widget.income!['income_id'];
        final originalAmount =
            (widget.income!['monthly_income'] as num?)?.toDouble() ?? 0.0;

        if (amount != originalAmount) {
          // Archive old and create new if amount changed
          await _sb
              .from('Fixed_Income')
              .update({'end_time': _iso(now)})
              .eq('income_id', incomeId);

          await _sb.from('Fixed_Income').insert({
            'name': name,
            'monthly_income': amount,
            'payday': _selectedPayDay,
            'profile_id': widget.profileId,
            'start_time': _iso(now),
            'end_time': null,
          });

          // Update monthly record with amount difference
          final amountDifference = amount - originalAmount;
          if (amountDifference != 0) {
            await _updateMonthlyRecordIncome(
              amountDifference.abs(),
              amountDifference > 0,
            );
          }
        } else {
          // Just update name and payday if amount unchanged
          await _sb
              .from('Fixed_Income')
              .update({'name': name, 'payday': _selectedPayDay})
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1D33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D33),
        title: Text(
          widget.income == null ? 'Add Income' : 'Edit Income',
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
              _buildSheetLabel('Income Name'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _nameController,
                hintText: 'Enter income name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter income name';
                  }

                  // Check for duplicate name
                  if (_isIncomeNameDuplicate(value)) {
                    return 'This income name already exists';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildSheetLabel('Monthly Amount (SAR)'),
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

              _buildSheetLabel('Pay Day (1-31)'),
              const SizedBox(height: 8),
              _buildWhiteDropdown<int>(
                value: _selectedPayDay,
                items: List.generate(
                  31,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                ),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedPayDay = v);
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
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
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
          items: items,
          onChanged: onChanged,
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
            onPressed: _loading ? null : _saveIncome,
            child: Text(
              widget.income == null ? 'Add Income' : 'Save Changes',
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
