// edit_goal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/../../theme/app_colors.dart';
import '/../../utils/auth_helpers.dart';

// ── Kid-savings theme colours ─────────────────────────────────────────────────
const _kidBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.45, 1.0],
  colors: [Color(0xFFD4B3F5), Color(0xFFB8D4F8), Color(0xFFF7B8D4)],
);
const _kPurple    = Color(0xFF8B5CF6);
const _kText      = Color(0xFF2D1B69);
const _kTextSoft  = Color(0xFF7C6FA0);
const _kGreen     = Color(0xFF34D399);
const _kGreenSoft = Color(0xFFD1FAE5);

class EditGoalPage extends StatefulWidget {
  final String    id;
  final String    initialTitle;
  final double    initialTargetAmount;
  final DateTime? initialTargetDate;
  final String?   initialStatus;

  const EditGoalPage({
    super.key,
    required this.id,
    required this.initialTitle,
    required this.initialTargetAmount,
    required this.initialTargetDate,
    required this.initialStatus,
  });

  @override
  State<EditGoalPage> createState() => _EditGoalPageState();
}

class _EditGoalPageState extends State<EditGoalPage> {
  final _formKey   = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  final _dateCtrl  = TextEditingController();
  DateTime? _targetDate;
  bool      _submitting = false;
  String?   _titleError;
  String?   _amountError;
  String?   _dateError;
  final supabase = Supabase.instance.client;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _titleCtrl  = TextEditingController();
    _amountCtrl = TextEditingController();
    _loadFreshGoal();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _targetDate ?? widget.initialTargetDate ?? now,
      firstDate:   DateTime(now.year - 3),
      lastDate:    DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   _kPurple,
            onPrimary: Colors.white,
            onSurface: _kText,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _targetDate    = DateTime(picked.year, picked.month, picked.day);
        _dateCtrl.text = _formatDate(_targetDate!);
        _validateDate();
      });
    }
  }

  // ── Load fresh goal from DB ───────────────────────────────────────────────
  Future<void> _loadFreshGoal() async {
    final row = await supabase
        .from('Goal')
        .select()
        .eq('goal_id', widget.id)
        .single();

    setState(() {
      _titleCtrl.text  = row['name'] ?? widget.initialTitle;
      _amountCtrl.text =
          (row['target_amount'] ?? widget.initialTargetAmount).toString();
      if (row['target_date'] != null) {
        _targetDate    = DateTime.parse(row['target_date']);
        _dateCtrl.text = _formatDate(_targetDate!);
      }
    });
  }

  // ── Validation ────────────────────────────────────────────────────────────
  void _validateForm() {
    setState(() {
      _titleError  = _titleCtrl.text.trim().isEmpty ? 'Name required' : null;
      _amountError = _amountCtrl.text.trim().isEmpty
          ? 'Amount is required'
          : double.tryParse(_amountCtrl.text) == null ||
                  double.parse(_amountCtrl.text) <= 0
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
    if ((widget.initialStatus ?? '').toLowerCase() == 'completed') return null;
    if (d.isBefore(t)) return 'Target date cannot be in the past';
    return null;
  }

  // ── Status alert dialog — light theme ─────────────────────────────────────
  Future<void> _showGoalStatusAlert(String status) {
    final s = status.toLowerCase();

    final IconData icon;
    final Color    ringColor;
    final String   title;
    final String   message;

    if (s == 'achieved') {
      icon      = Icons.emoji_events_rounded;
      ringColor = const Color(0xFFFBBF24);
      title     = 'What an Achievement!';
      message   = 'Goal status has been updated to Achieved.';
    } else if (s == 'completed') {
      icon      = Icons.check_circle_rounded;
      ringColor = _kGreen;
      title     = 'Goal Completed!';
      message   = 'Goal status has been updated to Completed.';
    } else if (s == 'failed' || s == 'incomplete' || s == 'incompleted') {
      icon      = Icons.error_outline_rounded;
      ringColor = const Color(0xFFF472B6);
      title     = 'Target Day is Due!';
      message   = 'Goal status has been updated to Incomplete.';
    } else {
      icon      = Icons.flash_on_rounded;
      ringColor = _kPurple;
      title     = 'Active Again!';
      message   = 'Goal status has been updated to Active.';
    }

    return showDialog<void>(
      context:            context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(
                color:      ringColor.withOpacity(0.2),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                color:    ringColor.withOpacity(0.1),
                boxShadow: [BoxShadow(
                    color: ringColor.withOpacity(0.3), blurRadius: 20)],
                border: Border.all(color: ringColor, width: 3),
              ),
              child: Icon(icon, size: 40, color: ringColor),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: _kText)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: _kTextSoft, height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(
              width: 120, height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                  elevation:   8,
                  shadowColor: _kPurple.withOpacity(0.4),
                ),
                child: const Text('OK',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    _validateForm();
    if (_titleError != null || _amountError != null || _dateError != null) return;

    final newTitle  = _titleCtrl.text.trim();
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
        if (dir == 'assign')   totalAssigned += amt;
        if (dir == 'unassign') totalAssigned -= amt;
      }

      if (totalAssigned > newTarget) {
        final excess = totalAssigned - newTarget;
        await supabase.from('Goal_Transfer').insert({
          'goal_id':    widget.id,
          'amount':     excess,
          'direction':  'Unassign',
          'created_at': DateTime.now().toIso8601String(),
        });
        totalAssigned -= excess;
      }

      final oldRow    = await supabase
          .from('Goal').select('status').eq('goal_id', widget.id).single();
      final oldStatus = (oldRow['status'] ?? '').toString();

      final now     = DateTime.now();
      final today   = DateTime(now.year, now.month, now.day);
      final goalDate = DateTime(
          _targetDate!.year, _targetDate!.month, _targetDate!.day);
      final bool targetIncreased = newTarget > widget.initialTargetAmount;

      String newStatus;
      if (goalDate.isBefore(today)) {
        newStatus = totalAssigned >= newTarget ? 'Completed' : 'Incomplete';
      } else {
        if (targetIncreased) {
          newStatus = 'Active';
        } else if (totalAssigned >= newTarget) {
          newStatus = 'Completed';
        } else {
          newStatus = 'Active';
        }
      }

      await supabase.from('Goal').update({
        'name':          newTitle,
        'target_amount': newTarget,
        'target_date':   _targetDate?.toIso8601String() ??
            widget.initialTargetDate?.toIso8601String(),
        'status':        newStatus,
        'profile_id':    profileId,
      }).eq('goal_id', widget.id);

      await Future.delayed(const Duration(milliseconds: 300));

      if (newStatus.toLowerCase() != oldStatus.toLowerCase()) {
        await _showGoalStatusAlert(newStatus);
      }

      final parent = context.findAncestorStateOfType<State<StatefulWidget>>();
      if (parent != null) {
        final dyn = parent as dynamic;
        try {
          await dyn._fetchGoals?.call();
          await dyn._generateMonthlySavings?.call();
          dyn._recalculateBalances?.call();
        } catch (_) {}
      }

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

  // ── Success dialog — light theme ──────────────────────────────────────────
  Future<void> _showSuccessDialog({required String message}) async {
    await showDialog<void>(
      context:            context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40)),
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(
                color:      _kPurple.withOpacity(0.15),
                blurRadius: 30, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                color:    _kGreenSoft,
                boxShadow: [BoxShadow(
                    color:      _kGreen.withOpacity(0.4),
                    blurRadius: 18, spreadRadius: 2)],
                border: Border.all(color: _kGreen, width: 3),
              ),
              child: const Center(
                child: Icon(Icons.check_circle_outline,
                    color: _kGreen, size: 42),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Done!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: _kText)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _kTextSoft, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            SizedBox(
              width: 120, height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  elevation:   16,
                  shadowColor: _kPurple.withOpacity(0.5),
                ),
                child: const Text('OK',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [

          // ── Full page gradient background ─────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: _kidBg),
          ),

          // ── Header block with rounded bottom corners ──────────────────
          // Card sits at top:150 — its rounded corners cut into this block
          // creating the same curved cutout as the dark theme
          Container(
            height: 230,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B6FFF), Color(0xFF6C8FFF)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          // ── "Back" + chevron centered on the header ───────────────────
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(height: 8),
                    Text('Back',
                        style: TextStyle(
                            color:      Colors.white,
                            fontSize:   22,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Icon(Icons.expand_more, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),

          // ── Form card — Positioned exactly like dark theme ────────────
          Positioned(
            top:    150,
            left:   0,
            right:  0,
            bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: size.width,
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                      color:      _kPurple.withOpacity(0.13),
                      blurRadius: 28,
                      offset:     const Offset(0, 6))],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Card title
                      const Text('Edit Goal',
                          style: TextStyle(
                              color:      _kText,
                              fontSize:   22,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),

                      // ── Goal Name ──────────────────────────────────
                      const _FieldLabel('Goal Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        hasError: _titleError != null,
                        child: TextFormField(
                          controller: _titleCtrl,
                          style:      const TextStyle(color: _kText),
                          decoration: _inputDecoration(),
                          onChanged: (_) =>
                              setState(() => _titleError = null),
                        ),
                      ),
                      if (_titleError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_titleError!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 18),

                      // ── Target Amount ──────────────────────────────
                      const _FieldLabel('Target Amount'),
                      const SizedBox(height: 8),
                      _rounded(
                        hasError: _amountError != null,
                        child: TextFormField(
                          controller:      _amountCtrl,
                          keyboardType:    TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(color: _kText),
                          decoration: _inputDecoration().copyWith(
                            prefixText:  'SAR  ',
                            prefixStyle: const TextStyle(
                                fontSize:   12,
                                color:      _kTextSoft,
                                fontWeight: FontWeight.w600),
                          ),
                          onChanged: (_) =>
                              setState(() => _amountError = null),
                        ),
                      ),
                      if (_amountError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_amountError!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 18),

                      // ── Target Date ────────────────────────────────
                      const _FieldLabel('Target Date'),
                      const SizedBox(height: 8),
                      _rounded(
                        hasError: _dateError != null,
                        child: InkWell(
                          onTap:        _pickDate,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  _dateCtrl.text.isEmpty
                                      ? 'Select date'
                                      : _dateCtrl.text,
                                  style: TextStyle(
                                    color: _dateCtrl.text.isEmpty
                                        ? _kTextSoft
                                        : _kText,
                                    fontSize:   16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color:        _kPurple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: _kPurple, size: 18),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      if (_dateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(_dateError!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 28),

                      // ── Save button — same pill as dark theme ──────
                      Center(
                        child: SizedBox(
                          width:  150,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPurple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(72)),
                              elevation:   10,
                              shadowColor: _kPurple.withOpacity(0.5),
                            ),
                            onPressed: _submitting ? null : _save,
                            child: const Text('Save',
                                style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   18,
                                    fontWeight: FontWeight.w600)),
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

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled:     true,
      fillColor:  Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide:   BorderSide.none,
      ),
    );
  }

  Widget _rounded({required Widget child, bool hasError = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(
          color: hasError
              ? Colors.redAccent
              : _kPurple.withOpacity(0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:      _kPurple.withOpacity(0.07),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color:      _kTextSoft,
            fontSize:   15,
            fontWeight: FontWeight.w600));
  }
}