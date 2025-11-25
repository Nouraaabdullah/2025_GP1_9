// edit_goal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_helpers.dart';

class EditGoalPage extends StatefulWidget {
  final String id;
  final String initialTitle;
  final double initialTargetAmount;
  final DateTime? initialTargetDate;

  const EditGoalPage({
    super.key,
    required this.id,
    required this.initialTitle,
    required this.initialTargetAmount,
    required this.initialTargetDate,
  });

  @override
  State<EditGoalPage> createState() => _EditGoalPageState();
}

class _EditGoalPageState extends State<EditGoalPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  final _dateCtrl = TextEditingController();
  DateTime? _targetDate;
  bool _submitting = false;
  String? _titleError;
  String? _amountError;
  String? _dateError;
  final supabase = Supabase.instance.client;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _amountCtrl = TextEditingController(text: widget.initialTargetAmount.toStringAsFixed(0));
    _targetDate = widget.initialTargetDate;
    if (_targetDate != null) _dateCtrl.text = _formatDate(_targetDate!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = DateTime(now.year - 5);
    final latest = DateTime(now.year + 5);

    final safeInitialDate = _targetDate ?? widget.initialTargetDate ?? now;
    final adjustedInitialDate = safeInitialDate.isBefore(earliest)
        ? earliest
        : safeInitialDate.isAfter(latest)
            ? latest
            : safeInitialDate;

    final picked = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDate: adjustedInitialDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _targetDate = DateTime(picked.year, picked.month, picked.day);
        _dateCtrl.text = _formatDate(_targetDate!);
        _validateDate();
      });
    }
  }

  void _validateForm() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty ? 'Name required' : null;
      _amountError = _amountCtrl.text.trim().isEmpty
          ? 'Amount is required'
          : double.tryParse(_amountCtrl.text) == null || double.parse(_amountCtrl.text) <= 0
              ? 'Enter a valid amount'
              : null;
      _dateError = _validateDate();
    });
  }

  String? _validateDate() {
    if (_targetDate == null) return 'Target date is required';
    final today = DateTime.now();
    final d = DateTime(_targetDate!.year, _targetDate!.month, _targetDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t) ? 'Target date cannot be in the past' : null;
  }

  // ⭐ NEW: Show Surra Status Dialog (same as Savings Page)
  Future<void> _showSurraSuccessDialog({
    required IconData icon,
    required Color ringColor,
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
            decoration: BoxDecoration(
              color: const Color(0xFF151228),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ringColor.withOpacity(0.40),
                        Colors.transparent,
                      ],
                      radius: 1.1,
                    ),
                  ),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF151228),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withOpacity(0.55),
                          blurRadius: 22,
                        ),
                      ],
                      border: Border.all(
                        color: ringColor,
                        width: 4,
                      ),
                    ),
                    child: Icon(icon, size: 40, color: ringColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 140,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B46F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      elevation: 16,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ⭐ NEW: Goal Status Alert (same logic as Savings Page)
  Future<void> _showGoalStatusAlert(String status) {
    final s = status.toLowerCase();

    if (s == 'achieved') {
      return _showSurraSuccessDialog(
        icon: Icons.emoji_events_rounded,
        ringColor: const Color(0xFFFFD54F),
        title: 'What an Achievement!',
        message: 'Goal status has been now updated to Achieved.',
      );
    } else if (s == 'completed') {
      return _showSurraSuccessDialog(
        icon: Icons.check_circle_rounded,
        ringColor: const Color(0xFF4ADE80),
        title: 'Goal Completed!',
        message: 'Goal status has been now updated to Completed.',
      );
    } else if (s == 'uncompleted' || s == 'failed' || s == 'incomplete') {
      return _showSurraSuccessDialog(
        icon: Icons.error_outline_rounded,
        ringColor: const Color(0xFFFF6B6B),
        title: 'Target Day is Due!',
        message: 'Goal status has been now updated to Incomplete.',
      );
    } else if (s == 'active') {
      return _showSurraSuccessDialog(
        icon: Icons.flash_on_rounded,
        ringColor: const Color(0xFF818CF8),
        title: 'Active Again!',
        message: 'Goal status has been now updated to Active.',
      );
    }

    return Future.value();
  }

  Future<void> _save() async {
    _validateForm();
    if (_titleError != null || _amountError != null || _dateError != null) return;

    final newTitle = _titleCtrl.text.trim();
    final newTarget = double.parse(_amountCtrl.text);

    try {
      final profileId = await getProfileId(context);
      if (profileId == null) return;

      final transfers = await supabase
          .from('Goal_Transfer')
          .select('amount, direction')
          .eq('goal_id', widget.id);

      double totalAssigned = 0.0;
      for (final t in (transfers as List? ?? [])) {
        final amt = (t['amount'] ?? 0).toDouble();
        final dir = (t['direction'] ?? '').toLowerCase();
        if (dir == 'assign') totalAssigned += amt;
        if (dir == 'unassign') totalAssigned -= amt;
      }

      if (totalAssigned > newTarget) {
        final excess = totalAssigned - newTarget;
        await supabase.from('Goal_Transfer').insert({
          'goal_id': widget.id,
          'amount': excess,
          'direction': 'Unassign',
          'created_at': DateTime.now().toIso8601String(),
        });
        totalAssigned -= excess;
      }
      // Get old status before update
      final oldRow = await supabase
          .from('Goal')
          .select('status')
          .eq('goal_id', widget.id)
          .single();

      final oldStatus = (oldRow['status'] ?? '').toString();
      final newStatus = totalAssigned >= newTarget ? 'Completed' : 'Active';

      await supabase.from('Goal').update({
        'name': newTitle,
        'target_amount': newTarget,
        'target_date': _targetDate?.toIso8601String() ?? widget.initialTargetDate?.toIso8601String(),
        'status': newStatus,
        'profile_id': profileId,
      }).eq('goal_id', widget.id);

      await Future.delayed(const Duration(milliseconds: 300));

      // ⭐ NEW: Show Status Alert FIRST
      if (newStatus.toLowerCase() != oldStatus.toLowerCase()) {
        await _showGoalStatusAlert(newStatus);
      }

      // Refresh parent
      final parent = context.findAncestorStateOfType<State<StatefulWidget>>();
      if (parent != null) {
        final dyn = parent as dynamic;
        try {
          await dyn._fetchGoals?.call();
          await dyn._generateMonthlySavings?.call();
          dyn._recalculateBalances?.call();
        } catch (_) {}
      }

      // Show your original success dialog second
      if (mounted) {
        await _showSuccessDialog(message: 'Goal updated successfully!');
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pop();
        });
      }
    } catch (e) {
      debugPrint('Error updating goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating goal: $e')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F33),
      body: Stack(
        children: [
          // Header
          Container(
            height: 230,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Column(
                      children: const [
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Icon(Icons.expand_more, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF704EF4)),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '',
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
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Goal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const _FieldLabel('Goal Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: Colors.black),
                          decoration: _inputDecoration(),
                          onChanged: (_) => setState(() => _titleError = null),
                        ),
                      ),
                      if (_titleError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_titleError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 18),

                      const _FieldLabel('Target Amount'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.black),
                          decoration: _inputDecoration().copyWith(
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.attach_money, size: 18, color: Color(0xFF7A7A8C)),
                            ),
                            suffixIconConstraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                          ),
                          onChanged: (_) => setState(() => _amountError = null),
                        ),
                      ),
                      if (_amountError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_amountError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 18),

                      const _FieldLabel('Target Date'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dateCtrl.text.isEmpty ? 'Select date' : _dateCtrl.text,
                                    style: TextStyle(
                                      color: _dateCtrl.text.isEmpty ? const Color(0xFF989898) : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF393A65),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_dateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_dateError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 28),

                      Center(
                        child: SizedBox(
                          width: 150,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(72)),
                              elevation: 10,
                              shadowColor: AppColors.accent,
                            ),
                            onPressed: _submitting ? null : _save,
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400),
    );
  }
}
