import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surra_application/utils/auth_helpers.dart'; // Import the utility

class EditBalancePage extends StatefulWidget {
  final double currentBalance;

  const EditBalancePage({super.key, required this.currentBalance});

  @override
  State<EditBalancePage> createState() => _EditBalancePageState();
}

class _EditBalancePageState extends State<EditBalancePage> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  final _sb = Supabase.instance.client;

  bool _loading = false;

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
    // Pre-fill with current balance
    _balanceController.text = widget.currentBalance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    final newBalance = double.tryParse(_balanceController.text.trim());
    if (newBalance == null) return;

    final double oldBalance = widget.currentBalance;
    final double difference = (newBalance - oldBalance).abs();
    final String transactionType = newBalance > oldBalance
        ? 'Earning'
        : 'Expense';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Balance Update',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to update your balance?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildConfirmationRow(
              'Current Balance',
              '${_fmtMoney(oldBalance)} SAR',
            ),
            _buildConfirmationRow(
              'New Balance',
              '${_fmtMoney(newBalance)} SAR',
            ),
            if (difference > 0) ...[
              _buildConfirmationRow(
                'Difference',
                '${_fmtMoney(difference)} SAR',
                isHighlighted: true,
                color: transactionType == 'Earning'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
              ),
              _buildConfirmationRow(
                'Transaction Type',
                transactionType,
                isHighlighted: true,
                color: transactionType == 'Earning'
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
              _saveBalance();
            },
            child: const Text(
              'Confirm Update',
              style: TextStyle(color: Colors.white),
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

  Future<void> _saveBalance() async {
    setState(() => _loading = true);

    try {
      final profileId = await _getProfileId();
      final newBalance = double.tryParse(_balanceController.text.trim());

      if (newBalance == null) {
        _showError('Please enter a valid amount');
        return;
      }

      final double oldBalance = widget.currentBalance;
      final double difference = (newBalance - oldBalance).abs();
      final String transactionType = newBalance > oldBalance
          ? 'Earning'
          : 'Expense';

      // Update balance in User_Profile
      await _sb
          .from('User_Profile')
          .update({'current_balance': newBalance})
          .eq('profile_id', profileId);

      // Record transaction only if there's a difference
      if (difference > 0) {
        await _sb.from('Transaction').insert({
          'type': transactionType,
          'amount': difference,
          'date': _iso(DateTime.now()),
          'profile_id': profileId,
          'category_id': null, // No category for balance adjustments
        });
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating balance: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double difference =
        double.tryParse(_balanceController.text.trim()) != null
        ? double.tryParse(_balanceController.text.trim())! -
              widget.currentBalance
        : 0.0;

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
                      const Text(
                        'Edit Current Balance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Current Balance Display
                      const _FieldLabel('Current Balance'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 32,
                                width: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_fmtMoney(widget.currentBalance)} SAR',
                                  style: const TextStyle(
                                    color: Color(0xFF1E1E1E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // New Balance Input
                      const _FieldLabel('New Balance'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _balanceController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _inputDecoration().copyWith(
                            hintText: '0.00',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter new balance';
                            }
                            final balance = double.tryParse(value);
                            if (balance == null || balance < 0) {
                              return 'Please enter valid balance';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Difference Display
                      if (difference != 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Balance Change'),
                            const SizedBox(height: 8),
                            _rounded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: difference > 0
                                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                                      : const Color(
                                          0xFFF44336,
                                        ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        difference > 0
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        color: difference > 0
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFF44336),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_fmtMoney(difference.abs())} SAR',
                                              style: TextStyle(
                                                color: difference > 0
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFF44336),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              difference > 0
                                                  ? 'Balance Increase'
                                                  : 'Balance Decrease',
                                              style: TextStyle(
                                                color: difference > 0
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFF44336),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: difference > 0
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFF44336),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          difference > 0
                                              ? 'Earning'
                                              : 'Expense',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              difference > 0
                                  ? 'This increase will be recorded as an earning transaction'
                                  : 'This decrease will be recorded as an expense transaction',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),

                      const SizedBox(height: 28),

                      // Update Button
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
                                : const Text(
                                    'Update Balance',
                                    style: TextStyle(
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

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
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
