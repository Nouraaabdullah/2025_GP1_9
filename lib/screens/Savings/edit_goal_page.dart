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
      });
    }
  }

Future<void> _save() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  final newTitle = _titleCtrl.text.trim();
  final newTarget = double.parse(_amountCtrl.text);

  try {
    // 👇 Get current user's profile ID dynamically
    final profileId = await getProfileId(context);
    if (profileId == null) return; // user not logged in

    // 1️⃣ Fetch all transfers for this goal
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

    // 2️⃣ Auto-unassign if over-assigned
    if (totalAssigned > newTarget) {
      final excess = totalAssigned - newTarget;

      await supabase.from('Goal_Transfer').insert({
        'goal_id': widget.id,
        'amount': excess,
        'direction': 'Unassign',
        'created_at': DateTime.now().toIso8601String(),
      });

      totalAssigned -= excess;
      debugPrint('💸 Auto-unassigned $excess SAR from goal "${widget.id}"');
    }

    // 3️⃣ Update goal info (title, amount, date, status)
    final newStatus = totalAssigned >= newTarget ? 'Completed' : 'Active';
    await supabase.from('Goal').update({
      'name': newTitle,
      'target_amount': newTarget,
      'target_date': _targetDate?.toIso8601String() ??
          widget.initialTargetDate?.toIso8601String(),
      'status': newStatus,
      'profile_id': profileId, // ✅ ensure correct ownership
    }).eq('goal_id', widget.id);

    // 4️⃣ Allow backend triggers time to update
    await Future.delayed(const Duration(milliseconds: 250));

    // 5️⃣ Refresh parent SavingsPage
    final parent = context.findAncestorStateOfType<State<StatefulWidget>>();
    if (parent != null) {
      final dyn = parent as dynamic;
      try {
        await dyn._fetchGoals?.call();
        await dyn._generateMonthlySavings?.call();
        dyn._recalculateBalances?.call();
      } catch (e) {
        debugPrint('⚠️ Parent refresh failed: $e');
      }
    }

    // ✅ Close and show confirmation
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Goal updated successfully!')),
      );
    }
  } catch (e) {
    debugPrint('❌ Error updating goal: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating goal: $e')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Edit Goal',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Goal name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Target amount (SAR)'),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Target date').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.8), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
