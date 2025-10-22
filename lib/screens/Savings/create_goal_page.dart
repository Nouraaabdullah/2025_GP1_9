// create_goal_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_helpers.dart'; 


class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // stable controller
  DateTime? _targetDate;
  bool _submitting = false;
  final supabase = Supabase.instance.client;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

    final safeInitialDate = _targetDate ?? now.add(const Duration(days: 1));
    final adjustedInitialDate =
        safeInitialDate.isBefore(earliest) ? earliest : safeInitialDate;

    final picked = await showDatePicker(
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDate: adjustedInitialDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
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
        _dateCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _submitting = true);

    final title = _titleCtrl.text.trim();
    final amount = double.parse(_amountCtrl.text);
    final date = _targetDate!;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating goal...')),
    );

    try {
      final profileId = await getProfileId(context);
      if (profileId == null) return; // not logged in or no profile found

      final response = await supabase.from('Goal').insert({
        'name': title.trim(),
        'target_amount': amount,
        'target_date': date.toIso8601String(),
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
        'profile_id': profileId,
      }).select();


      if (response.isEmpty) throw Exception('Insert failed — no data returned.');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal created successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Cannot create goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating goal: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Create Goal',
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _fieldDecoration('Goal name', hint: 'e.g., Buy a new phone'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Target amount (SAR)',
                      hint: 'e.g., 2000'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Non-typed date field: readOnly + onTap
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Target date', hint: 'Select date')
                      .copyWith(suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70)),
                  validator: (_) {
                    if (_targetDate == null) return 'Target date is required';
                    final today = DateTime.now();
                    final d = DateTime(_targetDate!.year, _targetDate!.month, _targetDate!.day);
                    final t = DateTime(today.year, today.month, today.day);
                    if (d.isBefore(t)) return 'Target date cannot be in the past';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.accent.withValues(alpha:0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                      shadowColor: AppColors.accent.withValues(alpha:0.4),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text('Create Goal',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withValues(alpha:0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha:0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}