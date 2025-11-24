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

  Future<String> _getProfileId() async {
    final profileId = await getProfileId(context);
    if (profileId == null) throw Exception('User not authenticated');
    return profileId;
  }

  @override
  void initState() {
    super.initState();
    _loadExistingIncomes();
    if (widget.income != null) {
      _nameController.text = widget.income!['name'] ?? '';
      _amountController.text = (widget.income!['monthly_income'] ?? 0.0)
          .toString();
      _paydayController.text = (widget.income!['payday'] ?? 27).toString();
    } else {
      _paydayController.text = '27';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _paydayController.dispose();
    super.dispose();
  }

  // ---------- SUCCESS DIALOG ADDED ----------
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

  // ---------- Load active incomes ----------
  Future<void> _loadExistingIncomes() async {
    try {
      final profileId = await _getProfileId();
      final response = await _sb
          .from('Fixed_Income')
          .select('name, income_id')
          .eq('profile_id', profileId)
          .filter('end_time', 'is', null);

      setState(() {
        _existingIncomes = response is List
            ? response.cast<Map<String, dynamic>>()
            : [];
      });
    } catch (e) {
      setState(() => _existingIncomes = []);
    }
  }

  bool _isIncomeNameDuplicate(String name) {
    final t = name.trim().toLowerCase();
    for (final inc in _existingIncomes) {
      final existingName = (inc['name'] as String?)?.toLowerCase() ?? '';
      final existingId = inc['income_id'] as String?;
      if (widget.income != null && existingId == widget.income!['income_id']) {
        continue;
      }
      if (existingName == t) return true;
    }
    return false;
  }

  // ---------- Helpers ----------
  bool _isPaydayPassed(int payDay) {
    final now = DateTime.now();
    final d = _getPaydayDate(now.year, now.month, payDay);
    return now.isAfter(d);
  }

  DateTime _getPaydayDate(int year, int month, int payDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final actual = payDay > lastDay ? lastDay : payDay;
    return DateTime(year, month, actual);
  }

  bool _isBetweenPaydays(int oldPayDay, int newPayDay) {
    final now = DateTime.now();
    final dOld = _getPaydayDate(now.year, now.month, oldPayDay);
    final dNew = _getPaydayDate(now.year, now.month, newPayDay);
    return now.isAfter(dOld) && now.isBefore(dNew);
  }

  Future<String?> _getCurrentMonthlyRecordId() async {
    final profileId = await _getProfileId();
    final now = DateTime.now();
    final rows = await _sb
        .from('Monthly_Financial_Record')
        .select('record_id, period_start, period_end')
        .eq('profile_id', profileId)
        .order('period_start', ascending: false);

    for (final r in rows) {
      final ps = DateTime.parse(r['period_start'] as String);
      final pe = DateTime.parse(r['period_end'] as String);
      if (now.isAfter(ps) && now.isBefore(pe)) return r['record_id'] as String;
    }
    return null;
  }

  Future<void> _updateMonthlyRecordIncome(
    double amountChange,
    bool isAdding,
  ) async {
    try {
      final recordId = await _getCurrentMonthlyRecordId();
      if (recordId == null) return;

      final rec = await _sb
          .from('Monthly_Financial_Record')
          .select('total_income, total_balance, total_expense')
          .eq('record_id', recordId)
          .single();

      final currInc = _toDouble(rec['total_income']) ?? 0.0;
      final currBal = _toDouble(rec['total_balance']) ?? 0.0;
      final currExp = _toDouble(rec['total_expense']) ?? 0.0;

      final newInc = isAdding ? currInc + amountChange : currInc - amountChange;
      final newBal = isAdding ? currBal + amountChange : currBal - amountChange;

      await _sb
          .from('Monthly_Financial_Record')
          .update({
            'total_income': newInc,
            'total_balance': newBal,
            'monthly_saving': newInc - currExp,
          })
          .eq('record_id', recordId);
    } catch (_) {}
  }

  Future<bool> _blockedThisMonthForPaydayChange(String incomeId) async {
    try {
      final row = await _sb
          .from('Fixed_Income')
          .select('last_update')
          .eq('income_id', incomeId)
          .single();

      final lu = row['last_update'];
      if (lu == null) return false;

      final lastUpdate = DateTime.tryParse(lu.toString());
      if (lastUpdate == null) return false;

      final now = DateTime.now();
      return lastUpdate.year == now.year && lastUpdate.month == now.month;
    } catch (_) {
      return false;
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return v.isEmpty ? null : double.tryParse(v);
    return null;
  }

  String _fmtMoney(double? v) => (v ?? 0).toStringAsFixed(2);

  String? _validatePayDay(String? v) {
    if (v == null || v.isEmpty) return 'Please enter pay day';
    final d = int.tryParse(v);
    if (d == null) return 'Please enter a valid number';
    if (d < 1 || d > 31) return 'Pay day must be between 1 and 31';
    return null;
  }

  // ---------- is_transacted helpers ----------
  bool _decideIsTransactedOnAdd({required int newPayday}) {
    final todayDay = DateTime.now().day;
    if (newPayday == todayDay) return true;
    if (newPayday < todayDay) return false;
    return false;
  }

  bool _decideIsTransactedOnEdit({
    required bool currentIsTransacted,
    required int newPayday,
  }) {
    final todayDay = DateTime.now().day;
    if (currentIsTransacted) return true;
    if (newPayday == todayDay) return true;
    if (newPayday < todayDay) return true;
    return false;
  }

  Future<void> _applyIncomeToBalance({
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
        .update({'current_balance': curr + amount})
        .eq('profile_id', profileId);
  }

  // ----------------------------------------------------------------
  // --------------------------- SAVE -------------------------------
  // ----------------------------------------------------------------
  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final profileId = await _getProfileId();
      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final payDay = int.tryParse(_paydayController.text.trim()) ?? 27;
      final today = _iso(DateTime.now());

      if (widget.income == null) {
        // ADD NEW
        final isTransactedNow = _decideIsTransactedOnAdd(newPayday: payDay);

        if (isTransactedNow) {
          await _applyIncomeToBalance(profileId: profileId, amount: amount);
        }

        await _sb.from('Fixed_Income').insert({
          'name': name,
          'monthly_income': amount,
          'payday': payDay,
          'profile_id': profileId,
          'start_time': today,
          'end_time': null,
          'is_primary': false,
          'last_update': today,
          'is_transacted': isTransactedNow,
        });

        await _updateMonthlyRecordIncome(amount, true);
      } else {
        // EDIT
        final incomeId = widget.income!['income_id'];
        final originalAmount =
            (widget.income!['monthly_income'] as num?)?.toDouble() ?? 0.0;
        final originalPayDay = widget.income!['payday'] ?? 27;
        final isPrimary = widget.income!['is_primary'] ?? false;

        final fresh = await _sb
            .from('Fixed_Income')
            .select('is_transacted')
            .eq('income_id', incomeId)
            .maybeSingle();

        final currentIsTransacted =
            (fresh?['is_transacted'] ??
                widget.income!['is_transacted'] ??
                false) ==
            true;

        final amountChanged = amount != originalAmount;
        final payDayChanged = payDay != originalPayDay;

        if (payDayChanged) {
          final blocked = await _blockedThisMonthForPaydayChange(incomeId);
          if (blocked) {
            await _showBlockedDialog();
            setState(() => _loading = false);
            return;
          }
        }

        final decidedIsTransacted = _decideIsTransactedOnEdit(
          currentIsTransacted: currentIsTransacted,
          newPayday: payDay,
        );

        final willTransactNow = decidedIsTransacted && !currentIsTransacted;
        if (willTransactNow) {
          await _applyIncomeToBalance(profileId: profileId, amount: amount);
        }

        if (amountChanged) {
          await _sb
              .from('Fixed_Income')
              .update({'end_time': today})
              .eq('income_id', incomeId);

          await _sb.from('Fixed_Income').insert({
            'name': name,
            'monthly_income': amount,
            'payday': payDay,
            'profile_id': profileId,
            'start_time': today,
            'end_time': null,
            'is_primary': isPrimary,
            'last_update': today,
            'is_transacted': decidedIsTransacted,
          });

          final diff = amount - originalAmount;
          if (diff != 0) {
            await _updateMonthlyRecordIncome(diff.abs(), diff > 0);
          }
        } else if (payDayChanged) {
          final oldPayDayPassed = _isPaydayPassed(originalPayDay);

          if (!oldPayDayPassed && payDay > originalPayDay) {
            if (_isBetweenPaydays(originalPayDay, payDay)) {
              await _sb
                  .from('Fixed_Income')
                  .update({
                    'name': name,
                    'payday': payDay,
                    'last_update': today,
                    'is_transacted': decidedIsTransacted,
                  })
                  .eq('income_id', incomeId);
            } else {
              await _sb
                  .from('Fixed_Income')
                  .update({'end_time': today})
                  .eq('income_id', incomeId);

              await _sb.from('Fixed_Income').insert({
                'name': name,
                'monthly_income': amount,
                'payday': payDay,
                'profile_id': profileId,
                'start_time': today,
                'end_time': null,
                'is_primary': isPrimary,
                'last_update': today,
                'is_transacted': decidedIsTransacted,
              });
            }
          } else if (oldPayDayPassed) {
            await _sb
                .from('Fixed_Income')
                .update({'end_time': today})
                .eq('income_id', incomeId);

            await _sb.from('Fixed_Income').insert({
              'name': name,
              'monthly_income': amount,
              'payday': payDay,
              'profile_id': profileId,
              'start_time': today,
              'end_time': null,
              'is_primary': isPrimary,
              'last_update': today,
              'is_transacted': decidedIsTransacted,
            });
          } else if (!oldPayDayPassed && payDay < DateTime.now().day) {
            await _sb
                .from('Fixed_Income')
                .update({'end_time': today})
                .eq('income_id', incomeId);

            await _sb.from('Fixed_Income').insert({
              'name': name,
              'monthly_income': amount,
              'payday': payDay,
              'profile_id': profileId,
              'start_time': today,
              'end_time': null,
              'is_primary': isPrimary,
              'last_update': today,
              'is_transacted': decidedIsTransacted,
            });
          } else {
            await _sb
                .from('Fixed_Income')
                .update({
                  'name': name,
                  'payday': payDay,
                  'last_update': today,
                  'is_transacted': decidedIsTransacted,
                })
                .eq('income_id', incomeId);
          }
        } else {
          await _sb
              .from('Fixed_Income')
              .update({
                'name': name,
                'last_update': today,
                'is_transacted': decidedIsTransacted,
              })
              .eq('income_id', incomeId);
        }
      }

      // ---------- SHOW SUCCESS DIALOG CALL ----------
      if (mounted) {
        await _showSuccessDialog(
          message: widget.income == null
              ? 'Fixed income added successfully.'
              : 'Fixed income updated successfully.',
        );
      }

      if (mounted) Navigator.pop(context, true);

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
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Dialogs ----------

  void _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final payDay = int.tryParse(_paydayController.text.trim());
    if (amount == null || payDay == null) return;

    final originalAmount = widget.income != null
        ? (widget.income!['monthly_income'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final originalPayDay = widget.income != null
        ? (widget.income!['payday'] ?? 27)
        : 27;

    final amountChanged = widget.income != null && amount != originalAmount;
    final payDayChanged = widget.income != null && payDay != originalPayDay;
    final diff = amount - originalAmount;

    if (widget.income != null && payDayChanged) {
      final blocked = await _blockedThisMonthForPaydayChange(
        widget.income!['income_id'],
      );
      if (blocked) {
        await _showBlockedDialog();
        return;
      }
    }

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
            if (amountChanged && widget.income != null)
              _buildConfirmationRow(
                'Amount Change',
                '${_fmtMoney(diff.abs())} SAR',
                isHighlighted: true,
                color: diff > 0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
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
              _saveIncome();
            },
            child: Text(
              widget.income == null ? 'Add Income' : 'Save Changes',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockedDialog() async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Pay Day Locked',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have already updated this income this month. You can change the pay day again next month.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------
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

  InputDecoration _inputDecoration() => const InputDecoration(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide.none,
    ),
  );

  Widget _rounded({required Widget child}) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
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

                      const _FieldLabel('Income Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter income name',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter income name';
                            }
                            if (_isIncomeNameDuplicate(v)) {
                              return 'This income name already exists';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      const _FieldLabel('Monthly Amount (SAR)'),
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
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter amount';
                            }
                            final amt = double.tryParse(v);
                            if (amt == null || amt <= 0) {
                              return 'Please enter valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

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
