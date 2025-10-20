import 'dart:math' as math;
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

  String _type = 'Expense';
  final List<String> _categories = [];
  bool _loadingCats = false;

  String? _selectedCategory;
  final TextEditingController _amountCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _datePicked = false;

  String? _profileId;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _getProfileId();
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth or data error: $e')),
      );
      Navigator.pop(context);
    }
  }

  // data

  Future<String> _getProfileId() async {
    if (_profileId != null) return _profileId!;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Sign in required');
    }
    final dynamic res = await _sb
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', uid)
        .single();
    final map = res as Map<String, dynamic>;
    _profileId = map['profile_id'] as String;
    return _profileId!;
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCats = true);
    try {
      final profileId = await _getProfileId();
      final dynamic res = await _sb
          .from('Category')
          .select('name')
          .eq('profile_id', profileId)
          .eq('is_archived', false)
          .order('name');
      final rows = (res as List);
      final names = rows
          .map<String>((r) => ((r as Map<String, dynamic>)['name'] as String))
          .toList();

      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(names);
        if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<String> _getCategoryIdByName(String name) async {
    final profileId = await _getProfileId();
    final dynamic res = await _sb
        .from('Category')
        .select('category_id')
        .eq('profile_id', profileId)
        .eq('name', name)
        .single();
    final map = res as Map<String, dynamic>;
    return map['category_id'] as String;
  }

  Future<Map<String, dynamic>> _getOrCreateCurrentMonthRecord(String profileId, DateTime date) async {
    final first = DateTime(date.year, date.month, 1);
    final last = DateTime(date.year, date.month + 1, 0);

    final List recs = await _sb
        .from('Monthly_Financial_Record')
        .select('record_id,total_expense,total_income,monthly_saving,period_start,period_end')
        .eq('profile_id', profileId)
        .gte('period_start', _fmt(first))
        .lte('period_end', _fmt(last));

    if (recs.isNotEmpty) {
      return recs.first as Map<String, dynamic>;
    }

    final insertRes = await _sb.from('Monthly_Financial_Record').insert({
      'period_start': _fmt(first),
      'period_end': _fmt(last),
      'total_expense': 0,
      'total_income': 0,
      'monthly_saving': 0,
      'profile_id': profileId,
    }).select().single();

    return insertRes as Map<String, dynamic>;
  }

  Future<num> _sumAllMonthlySavingsExceptCurrent(String profileId, DateTime now) async {
    final first = DateTime(now.year, now.month, 1);

    final dynamic res = await _sb
        .from('Monthly_Financial_Record')
        .select('monthly_saving,period_start')
        .eq('profile_id', profileId);

    num total = 0;
    for (final row in (res as List)) {
      final ps = DateTime.parse(row['period_start']);
      if (ps.year == first.year && ps.month == first.month) continue;
      final v = row['monthly_saving'];
      if (v is num) total += v;
      else {
        final parsed = num.tryParse('$v');
        if (parsed != null) total += parsed;
      }
    }
    return total;
  }

  Future<void> _updateBalance({required num amount, required bool isEarning}) async {
    final profileId = await _getProfileId();
    final dynamic getRes = await _sb
        .from('User_Profile')
        .select('current_balance')
        .eq('profile_id', profileId)
        .single();

    final getMap = getRes as Map<String, dynamic>;
    final num current = (getMap['current_balance'] is num)
        ? getMap['current_balance'] as num
        : num.tryParse('${getMap['current_balance']}') ?? 0;

    final num next = isEarning ? current + amount : current - amount;

    await _sb
        .from('User_Profile')
        .update({'current_balance': next})
        .eq('profile_id', profileId);
  }

  Future<void> _bumpMonthTotalsAndCategorySummary({
    required String profileId,
    required String categoryId,
    required DateTime date,
    required num amount,
  }) async {
    final month = await _getOrCreateCurrentMonthRecord(profileId, date);
    final recordId = month['record_id'] as String;

    final num currTotal = (month['total_expense'] is num)
        ? month['total_expense'] as num
        : num.tryParse('${month['total_expense']}') ?? 0;
    final num nextTotal = currTotal + amount;

    await _sb
        .from('Monthly_Financial_Record')
        .update({'total_expense': nextTotal})
        .eq('record_id', recordId);

    final List existing = await _sb
        .from('Category_Summary')
        .select('summary_id,total_expense')
        .eq('record_id', recordId)
        .eq('category_id', categoryId);

    if (existing.isEmpty) {
      await _sb.from('Category_Summary').insert({
        'total_expense': amount,
        'record_id': recordId,
        'category_id': categoryId,
      });
    } else {
      final row = existing.first as Map<String, dynamic>;
      final num was = (row['total_expense'] is num)
          ? row['total_expense'] as num
          : num.tryParse('${row['total_expense']}') ?? 0;
      final num now = was + amount;
      await _sb
          .from('Category_Summary')
          .update({'total_expense': now})
          .eq('summary_id', row['summary_id'] as String);
    }
  }

  Future<Map<String, dynamic>> _fetchCategoryById(String categoryId) async {
    final row = await _sb
        .from('Category')
        .select('category_id,name,monthly_limit')
        .eq('category_id', categoryId)
        .single();
    return row as Map<String, dynamic>;
  }

  Future<num> _getCategoryMonthlySpent(String profileId, String categoryId, DateTime date) async {
    final month = await _getOrCreateCurrentMonthRecord(profileId, date);
    final recordId = month['record_id'] as String;

    final List rows = await _sb
        .from('Category_Summary')
        .select('total_expense')
        .eq('record_id', recordId)
        .eq('category_id', categoryId);

    if (rows.isEmpty) return 0;
    final v = (rows.first as Map<String, dynamic>)['total_expense'];
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  // color picker helper opened via root navigator to avoid nested dependents
  Future<Color?> _pickWheelColor(Color initial) async {
    Color tempColor = initial;
    return showDialog<Color>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2550),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Pick a Color",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setInner) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onPanDown: (d) => _updateColor(d.localPosition, setInner, (c) => tempColor = c),
                    onPanUpdate: (d) => _updateColor(d.localPosition, setInner, (c) => tempColor = c),
                    child: CustomPaint(
                      size: const Size(150, 150),
                      painter: _ColorWheelPainter(tempColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tempColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(tempColor),
              child: const Text("Done", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // create category dialog

Future<String> _createCategoryDialog() async {
  final nameCtrl = TextEditingController();
  final limitCtrl = TextEditingController();

  Color chosenColor = const Color(0xFF7959F5);
  IconData? chosenIcon;

  final availableIcons = <IconData>[
    Icons.fastfood,
    Icons.shopping_bag,
    Icons.home,
    Icons.airplanemode_active,
    Icons.movie,
    Icons.sports_soccer,
    Icons.work,
    Icons.pets,
    Icons.brush,
    Icons.local_cafe,
    Icons.computer,
    Icons.attach_money,
  ];

  String? createdCategoryName;

  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false, // prevent swipe-tap dismiss races
    builder: (ctx) {
      final formKey = GlobalKey<FormState>();
      return StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('New Category', style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _inputDecoration().copyWith(hintText: 'Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: limitCtrl,
                      decoration: _inputDecoration().copyWith(hintText: 'Monthly limit'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a limit'
                          : (double.tryParse(v.trim()) == null ? 'Enter a number' : null),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Color', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final picked = await _pickWheelColor(chosenColor);
                            if (picked != null) setDialog(() => chosenColor = picked);
                          },
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: chosenColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableIcons.map((icon) {
                          final isSelected = chosenIcon == icon;
                          return GestureDetector(
                            onTap: () => setDialog(() => chosenIcon = icon),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : const Color(0xFF2A2550),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: Colors.white, size: 22),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (chosenIcon == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pick an icon')),
                    );
                    return;
                  }

                  final profileId = await _getProfileId();
                  final name = nameCtrl.text.trim();
                  final limit = num.parse(limitCtrl.text.trim());

                  final inserted = await _sb.from('Category').insert({
                    'name': name,
                    'type': 'Custom', // ← correct enum for user-created
                    'monthly_limit': limit,
                    'icon': chosenIcon.toString().split('.').last,
                    'icon_color': chosenColor.value.toRadixString(16),
                    'is_archived': false,
                    'profile_id': profileId,
                  }).select('category_id,name').single();

                  createdCategoryName = inserted['name'] as String;

                  // Close dialog last, after DB call finishes
                  if (context.mounted) {
                    Navigator.of(ctx, rootNavigator: true).pop();
                  }
                },
                child: const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );

  // Do NOT dispose local controllers here; it can race with dialog teardown.
  // nameCtrl.dispose();
  // limitCtrl.dispose();

  if (createdCategoryName == null) {
    throw Exception('Creation cancelled');
  }
  return createdCategoryName!;
}


  // color wheel math
  void _updateColor(
    Offset position,
    void Function(void Function()) setStateDialog,
    void Function(Color) setColor,
  ) {
    const radius = 75.0;
    const center = Offset(radius, radius);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > radius || distance < radius - 15) return;

    final angle = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
    final color = HSVColor.fromAHSV(1, angle, 1, 1).toColor();

    setStateDialog(() {});
    setColor(color);
  }

  Future<void> _submitToDb() async {
    final profileId = await _getProfileId();

    final String typeDb = _type;
    final num amount = num.parse(_amountCtrl.text.trim());
    final String dateStr = _fmt(_selectedDate);

    final Map<String, dynamic> payload = {
      'type': typeDb,
      'amount': amount,
      'date': dateStr,
      'profile_id': profileId,
    };

    String? categoryId;

    if (typeDb == 'Expense') {
      if (_selectedCategory == null) {
        try {
          final createdName = await _createCategoryDialog();
          await _loadCategories();
          _selectedCategory = createdName;
        } catch (_) {
          throw Exception('Select or create a category');
        }
      }
      final catName = _selectedCategory!;
      categoryId = await _getCategoryIdByName(catName);
      payload['category_id'] = categoryId;
    }

    await _sb.from('Transaction').insert(payload);
    await _updateBalance(amount: amount, isEarning: typeDb == 'Earning');

    if (typeDb == 'Expense' && categoryId != null) {
      await _bumpMonthTotalsAndCategorySummary(
        profileId: profileId,
        categoryId: categoryId,
        date: _selectedDate,
        amount: amount,
      );

      final catRow = await _fetchCategoryById(categoryId);
      final limitVal = catRow['monthly_limit'];
      if (limitVal != null) {
        final num limit = (limitVal is num) ? limitVal : num.tryParse('$limitVal') ?? 0;
        final num spentNow = await _getCategoryMonthlySpent(profileId, categoryId, _selectedDate);
        if (limit > 0 && spentNow > limit && mounted) {
          _showOverspendNote(
            'Category limit exceeded for ${catRow['name']}. Spent $spentNow over $limit.',
          );
        }
      }

      final currBalRow = await _sb
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', profileId)
          .single();
      final num currentBalance = (currBalRow['current_balance'] is num)
          ? currBalRow['current_balance'] as num
          : num.tryParse('${currBalRow['current_balance']}') ?? 0;

      final num savedTotal = await _sumAllMonthlySavingsExceptCurrent(profileId, _selectedDate);

      if (currentBalance <= savedTotal && mounted) {
        _showOverspendNote(
          'Alert: your balance $currentBalance is at or below your saved total $savedTotal.',
        );
      }
    }
  }

  void _showOverspendNote(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ui

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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF704EF4),
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

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_type == 'Expense' && _selectedCategory == null) {
      try {
        final created = await _createCategoryDialog();
        await _loadCategories();
        setState(() => _selectedCategory = created);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or create a category')),
        );
        return;
      }
    }

    try {
      await _submitToDb();
      final preview =
          '$_type • ${_selectedCategory ?? ''} • ${_amountCtrl.text.trim()} • ${_fmt(_selectedDate)}';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: $preview'), behavior: SnackBarBehavior.floating),
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
    final isEarning = _type == 'Earning';

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
                onPressed: () => Navigator.pop(context),
                tooltip: '',
              ),
            ),
          ),

          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Hero(tag: 'surra-add-fab', child: SizedBox(width: 0, height: 0)),
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
                      const SizedBox(height: 10),
                      _TypeTabs(
                        value: _type,
                        onChanged: (v) {
                          setState(() {
                            _type = v;
                            if (v == 'Earning') _selectedCategory = null;
                          });
                        },
                      ),
                      const SizedBox(height: 18),

                      if (!isEarning) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _FieldLabel('Category'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _rounded(
                          child: Row(
                            children: [
                              Expanded(
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
                                      _type == 'Expense' && v == null ? 'Select a category' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'New',
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(const Color(0xFF393A65)),
                                  foregroundColor: MaterialStateProperty.all(Colors.white),
                                ),
                                onPressed: () async {
                                  try {
                                    final created = await _createCategoryDialog();
                                    await _loadCategories();
                                    setState(() => _selectedCategory = created);
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.add),
                              ),
                              const SizedBox(width: 8),
                            ],
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
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeTabs({required this.value, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final isExpense = value == 'Expense';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B48),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tab(
            label: 'Expense',
            selected: isExpense,
            onTap: () => onChanged('Expense'),
          ),
          _tab(
            label: 'Earning',
            selected: !isExpense,
            onTap: () => onChanged('Earning'),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1F1F33) : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final Color selectedColor;
  _ColorWheelPainter(this.selectedColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (double i = 0; i < 360; i++) {
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1, i, 1, 1).toColor()
        ..strokeWidth = 15
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * math.pi / 180,
        math.pi / 180,
        false,
        paint,
      );
    }

    final highlight = Paint()
      ..color = selectedColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, highlight);
  }

  @override
  bool shouldRepaint(_) => true;
}
