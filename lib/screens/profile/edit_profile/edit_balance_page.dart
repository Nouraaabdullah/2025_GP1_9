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
        backgroundColor: const Color(0xFF1F1D33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Balance Update',
          style: TextStyle(color: Colors.white),
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
              backgroundColor: const Color(0xFF5E52E6),
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
                  (isHighlighted ? const Color(0xFF5E52E6) : Colors.white),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1F1D33),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D33),
        title: const Text(
          'Edit Current Balance',
          style: TextStyle(color: Colors.white),
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
              // Current Balance Display
              _buildSheetLabel('Current Balance'),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2840),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // New Balance Input
              _buildSheetLabel('New Balance'),
              const SizedBox(height: 8),
              _buildSheetWhiteField(
                controller: _balanceController,
                hintText: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: 20),

              // Difference Display
              if (difference != 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetLabel(
                      difference > 0 ? 'Balance Increase' : 'Balance Decrease',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: difference > 0
                            ? const Color(0xFF4CAF50).withOpacity(0.2)
                            : const Color(0xFFF44336).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: difference > 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            child: Text(
                              '${_fmtMoney(difference.abs())} SAR',
                              style: TextStyle(
                                color: difference > 0
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            difference > 0 ? 'Earning' : 'Expense',
                            style: TextStyle(
                              color: difference > 0
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      difference > 0
                          ? 'This increase will be recorded as an earning transaction'
                          : 'This decrease will be recorded as an expense transaction',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              const Spacer(),

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
            onPressed: _loading ? null : _showConfirmationDialog,
            child: const Text(
              'Update Balance',
              style: TextStyle(
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

  String _fmtMoney(double value) {
    return value.toStringAsFixed(2);
  }
}
