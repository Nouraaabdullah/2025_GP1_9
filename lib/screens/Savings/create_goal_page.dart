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
        _dateCtrl.text = _formatDate(_targetDate!);
        _validateDate(); // Validate date on selection
      });
    }
  }

  void _validateForm() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty
          ? 'Name is required'
          : _titleCtrl.text.trim().length < 2
              ? 'Name must be at least 2 characters'
              : null;
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

  Future<void> _submit() async {
    _validateForm();
    if (_titleError != null || _amountError != null || _dateError != null) return;
    setState(() => _submitting = true);

    final title = _titleCtrl.text.trim();
    final amount = double.parse(_amountCtrl.text);
    final date = _targetDate!;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating goal...')),
    );

    try {
      final profileId = await getProfileId(context);
      if (profileId == null) return;

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
      backgroundColor: const Color(0xFF1F1F33),
      body: Stack(
        children: [
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
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Goal',
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
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.black),
                          decoration: _inputDecoration(hint: 'e.g., Buy a new phone'),
                          onChanged: (_) => setState(() => _titleError = null),
                        ),
                      ),
                      if (_titleError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 12),
                          child: Text(
                            _titleError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
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
                          decoration: _inputDecoration(hint: 'e.g., 2000').copyWith(
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
                          child: Text(
                            _amountError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
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
                                    _dateCtrl.text.isEmpty
                                        ? 'Select date'
                                        : _dateCtrl.text,
                                    style: TextStyle(
                                      color: _dateCtrl.text.isEmpty
                                          ? const Color(0xFF989898)
                                          : Colors.black,
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
                          child: Text(
                            _dateError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 28),
                      Center(
                        child: SizedBox(
                          width: 150,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(72),
                              ),
                              elevation: 10,
                              shadowColor: AppColors.accent,
                            ),
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white)),
                                  )
                                : const Text(
                                    'Create Goal',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF989898)),
      border: const OutlineInputBorder(
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