// lib/pages/goals/create_goal_page.dart
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
const _kPurple   = Color(0xFF8B5CF6);
const _kText     = Color(0xFF2D1B69);
const _kTextSoft = Color(0xFF7C6FA0);
const _kGreen    = Color(0xFF34D399);
const _kGreenSoft = Color(0xFFD1FAE5);

class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl   = TextEditingController();
  DateTime? _targetDate;
  bool      _submitting = false;
  String?   _titleError;
  String?   _amountError;
  String?   _dateError;
  final supabase = Supabase.instance.client;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _targetDate ?? now,
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
        _targetDate    = picked;
        _dateCtrl.text = _fmt(_targetDate!);
        _validateDate();
      });
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────
  void _validateForm() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty
          ? 'Name is required'
          : _titleCtrl.text.trim().length < 2
              ? 'Name must be at least 2 characters'
              : null;

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
    return d.isBefore(t) ? 'Target date cannot be in the past' : null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    _validateForm();
    if (_titleError != null || _amountError != null || _dateError != null) return;

    setState(() => _submitting = true);

    final title  = _titleCtrl.text.trim();
    final amount = double.parse(_amountCtrl.text);
    final date   = _targetDate!;

    try {
      final profileId = await getProfileId(context);
      if (profileId == null) return;

      final response = await supabase.from('Goal').insert({
        'name':          title,
        'target_amount': amount,
        'target_date':   date.toIso8601String(),
        'status':        'Active',
        'created_at':    DateTime.now().toIso8601String(),
        'profile_id':    profileId,
      }).select();

      if (response.isEmpty) throw Exception('Insert failed');

      await _showSuccessDialog(message: 'Goal created successfully!');
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pop();
      });
    } catch (e) {
      debugPrint('CreateGoal error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot creating goal: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [

          // ── Full page background — gradient (shows below the card) ─────
          Container(
            decoration: const BoxDecoration(gradient: _kidBg),
          ),

          // ── Header block — same height/radius as dark theme ───────────
          // Card sits on top at top:150, its rounded corners cut into this
          // block creating the curved cutout effect identical to dark theme
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

          // ── "Back" + chevron on the header ───────────────────────────
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
                    Text(
                      'Back',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                      const Text(
                        'Create Goal',
                        style: TextStyle(
                          color:      _kText,
                          fontSize:   22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Goal Name ──────────────────────────────────
                      const _FieldLabel('Goal Name'),
                      const SizedBox(height: 8),
                      _rounded(
                        hasError: _titleError != null,
                        child: TextFormField(
                          controller:      _titleCtrl,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: _kText),
                          decoration:      _inputDecoration(),
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
                              fontWeight: FontWeight.w600,
                            ),
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
                          onTap:         _pickDate,
                          borderRadius:  BorderRadius.circular(18),
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

                      // ── Submit button — same pill size as dark theme ──
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
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white)),
                                  )
                                : const Text(
                                    'Create Goal',
                                    style: TextStyle(
                                        color:      Colors.white,
                                        fontSize:   18,
                                        fontWeight: FontWeight.w600),
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

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      filled:     true,
      fillColor:  Colors.white,
      hintText:   hint,
      hintStyle:  const TextStyle(color: _kTextSoft),
      border: const OutlineInputBorder(
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
                blurRadius: 30,
                offset:     const Offset(0, 8))],
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
                style: TextStyle(
                    color:      _kText,
                    fontSize:   22,
                    fontWeight: FontWeight.w800)),
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
                    style: TextStyle(
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
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
          color:      _kTextSoft,
          fontSize:   15,
          fontWeight: FontWeight.w600),
    );
  }
}