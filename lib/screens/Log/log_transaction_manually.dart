import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class LogTransactionManuallyPage extends StatefulWidget {
  const LogTransactionManuallyPage({super.key});

  @override
  State<LogTransactionManuallyPage> createState() =>
      _LogTransactionManuallyPageState();
}

class _LogTransactionManuallyPageState extends State<LogTransactionManuallyPage> {
  final _formKey = GlobalKey<FormState>();

  final List<String> _types = ['Expense', 'Earning'];

  // categories now come from DB
  final List<String> _categories = [];
  bool _loadingCats = false;

  String? _selectedType;
  String? _selectedCategory; // stores the category *name* (unchanged)
  final TextEditingController _amountCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _datePicked = false;

  // cache profile_id once we fetch it
  String? _profileId;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCats = true);
    try {
      // fetch current user's profile_id (you already have _getProfileId)
      final profileId = await _getProfileId();

      // pull this user's active expense categories by name
      final rows = await _sb
          .from('Category')
          .select('name')
          .eq('profile_id', profileId)
          .eq('is_archived', false)         // keep if you use archiving
          .eq('type', 'expense')            // keep if your enum has 'expense'
          .order('name');

      _categories
        ..clear()
        ..addAll(rows.map<String>((r) => (r['name'] as String)).toList());

      if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load categories: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _datePicked = true;
      });
    }
  }

  Future<String> _getProfileId() async {
    if (_profileId != null) return _profileId!;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('You must be signed in');
    }
    final row = await _sb
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', uid)
        .single();
    _profileId = row['profile_id'] as String;
    return _profileId!;
  }

  Future<String> _getCategoryIdByName(String name) async {
    final row = await _sb
        .from('Category')
        .select('category_id')
        .eq('name', name)
        .single();
    return row['category_id'] as String;
  }

  Future<void> _submitToDb() async {
    final profileId = await _getProfileId();

    final typeDb = (_selectedType ?? '').toLowerCase(); // expense or earning
    final amount = num.parse(_amountCtrl.text.trim());
    final dateStr = _fmt(_selectedDate); // yyyy-mm-dd

    final payload = <String, dynamic>{
      'type': typeDb,
      'amount': amount,
      'date': dateStr,
      'profile_id': profileId,
    };

    // only attach category for expense (unchanged)
    if (typeDb == 'expense') {
      final catName = _selectedCategory!;
      final catId = await _getCategoryIdByName(catName);
      payload['category_id'] = catId;
    }

    await _sb.from('Transaction').insert(payload);
  }

  void _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      await _submitToDb();

      final preview =
          '${_selectedType ?? ''} • ${_selectedCategory ?? ''} • ${_amountCtrl.text.trim()} • ${_fmt(_selectedDate)}';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $preview'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isEarning = _selectedType == 'Earning';

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F33),
      body: Stack(
        children: [
          // purple header
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

          // back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF704EF4)),
                onPressed: () => Navigator.pop(context),
                tooltip: '',
              ),
            ),
          ),

          // hero target
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Hero(tag: 'surra-add-fab', child: SizedBox(width: 0, height: 0)),
          ),

          // form card
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
                        'Log Transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const _FieldLabel('Type'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          isExpanded: true,
                          decoration: _inputDecoration(),
                          items: _types
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedType = v;
                              if (v == 'Earning') {
                                _selectedCategory = null; // clear category when earning
                              }
                            });
                          },
                          validator: (v) => v == null ? 'Select a type' : null,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Category hidden for Earning; items come from DB
                      if (!isEarning) ...[
                        const _FieldLabel('Category'),
                        const SizedBox(height: 8),
                        _rounded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            items: _categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: _loadingCats
                                ? null
                                : (v) => setState(() => _selectedCategory = v),
                            validator: (v) =>
                                v == null ? 'Select a category' : null,
                          ),
                        ),
                        if (_loadingCats)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('Loading categories...',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        const SizedBox(height: 18),
                      ],

                      const _FieldLabel('Amount'),
                      const SizedBox(height: 8),
                      _rounded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration().copyWith(
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.attach_money, size: 18, color: Color(0xFF7A7A8C)),
                            ),
                            suffixIconConstraints:
                                const BoxConstraints(minHeight: 0, minWidth: 0),
                          ),
                          validator: (v) {
                            final txt = v?.trim() ?? '';
                            if (txt.isEmpty) return 'Enter an amount';
                            final val = double.tryParse(txt);
                            if (val == null || val <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 18),

                      const _FieldLabel('Date'),
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
                                    _datePicked ? _fmt(_selectedDate) : _fmt(DateTime.now()),
                                    style: TextStyle(
                                      color: _datePicked ? Colors.black : const Color(0xFF989898),
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
                            onPressed: _submit,
                            child: const Text(
                              'Log',
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

  String _fmt(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
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
