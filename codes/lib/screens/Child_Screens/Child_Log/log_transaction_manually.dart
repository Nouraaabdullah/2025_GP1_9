// /codes/lib/screens/Child_Screens/Child_Log/log_transaction_manually.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utils/auth_helpers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kid_widgets.dart';

class ChildLogTransactionManuallyPage extends StatefulWidget {
  const ChildLogTransactionManuallyPage({super.key});

  @override
  State<ChildLogTransactionManuallyPage> createState() =>
      _ChildLogTransactionManuallyPageState();
}

class _ChildLogTransactionManuallyPageState
    extends State<ChildLogTransactionManuallyPage> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'Expense';
  final List<String> _categories = [];
  bool _loadingCats = false;

  String? _selectedCategory;

  final TextEditingController _amountCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _datePicked = false;

  String? _profileId;

  String? _dateErrorText;
  String? _categoryErrorText;

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

  Future<String> _getProfileId() async {
    if (_profileId != null) return _profileId!;
    final pid = await getProfileId(context);
    if (pid == null) {
      throw Exception('Sign in required');
    }
    _profileId = pid;
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
        if (_selectedCategory != null &&
            !_categories.contains(_selectedCategory)) {
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

  Future<Map<String, dynamic>> _getOrCreateCurrentMonthRecord(
    String profileId,
    DateTime date,
  ) async {
    final first = DateTime(date.year, date.month, 1);
    final last = DateTime(date.year, date.month + 1, 0);

    final List recs = await _sb
        .from('Monthly_Financial_Record')
        .select(
          'record_id,total_expense,total_income,monthly_saving,period_start,period_end',
        )
        .eq('profile_id', profileId)
        .gte('period_start', _fmt(first))
        .lte('period_end', _fmt(last));

    if (recs.isNotEmpty) {
      return recs.first as Map<String, dynamic>;
    }

    final insertRes = await _sb
        .from('Monthly_Financial_Record')
        .insert({
          'period_start': _fmt(first),
          'period_end': _fmt(last),
          'total_expense': 0,
          'total_income': 0,
          'monthly_saving': 0,
          'profile_id': profileId,
        })
        .select()
        .single();

    return insertRes as Map<String, dynamic>;
  }

  Future<num> _getCurrentBalance() async {
    final profileId = await _getProfileId();
    final dynamic res = await _sb
        .from('User_Profile')
        .select('current_balance')
        .eq('profile_id', profileId)
        .single();
    final map = res as Map<String, dynamic>;
    final v = map['current_balance'];
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  Future<void> _updateBalance({
    required num amount,
    required bool isEarning,
  }) async {
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

  Future<num> _getCategoryMonthlySpent(
    String profileId,
    String categoryId,
    DateTime date,
  ) async {
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

  String _normalizeName(String s) => s.trim().toLowerCase();

  Color _hexToColor(String value) {
    value = value.replaceAll('#', '');

    final isDecimal =
        RegExp(r'^[0-9]+$').hasMatch(value) && value.length > 8;

    if (isDecimal) {
      final dec = int.parse(value);
      return Color(dec);
    }

    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  }

  Future<DateTime?> _pickDateDialog(DateTime initial) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.kPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.kText,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  Future<void> _showKidDialog({
    required Widget child,
    bool dismissible = true,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: KidCard(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    await _showKidDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Done!',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 22,
              color: AppColors.kText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.kTextSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          KidPrimaryButton(
            label: 'OK',
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarningDialog(String message) async {
    await _showKidDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Warning!',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 22,
              color: AppColors.kText,
            ),
          ),
          const SizedBox(height: 10),
          KidAlert(message),
          const SizedBox(height: 16),
          KidPrimaryButton(
            label: 'OK',
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required double currentBalance,
    required double amount,
    required bool isExpense,
    String? categoryName,
    required String dateText,
  }) async {
    final newBalance = isExpense ? currentBalance - amount : currentBalance + amount;

    bool confirmed = false;

    await _showKidDialog(
      dismissible: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Confirm',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 22,
              color: AppColors.kText,
            ),
          ),
          const SizedBox(height: 12),
          _ConfirmLine(label: 'Current balance', value: '${currentBalance.toStringAsFixed(2)} SAR'),
          _ConfirmLine(label: 'New balance', value: '${newBalance.toStringAsFixed(2)} SAR'),
          _ConfirmLine(label: 'Date', value: dateText),
          _ConfirmLine(
            label: 'Amount',
            value: '${isExpense ? '-' : '+'}${amount.toStringAsFixed(2)} SAR',
            valueColor: isExpense ? AppColors.kPink : AppColors.kGreen,
          ),
          if (isExpense && categoryName != null && categoryName.isNotEmpty)
            _ConfirmLine(label: 'Category', value: categoryName),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: KidGhostButton(
                  label: 'Cancel',
                  onTap: () {
                    confirmed = false;
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KidPrimaryButton(
                  label: 'Confirm',
                  onTap: () {
                    confirmed = true;
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return confirmed;
  }

  Future<String> _createCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();

    final colors = <Color>[
      AppColors.kPurple,
      AppColors.kBlue,
      AppColors.kPink,
      AppColors.kGreen,
      AppColors.kYellow,
      AppColors.kOrange,
    ];

    Color chosenColor = AppColors.kPurple;
    IconData? chosenIcon;

    final icons = <IconData>[
      Icons.shopping_cart,
      Icons.restaurant,
      Icons.directions_car,
      Icons.home,
      Icons.local_hospital,
      Icons.school,
      Icons.sports_esports,
      Icons.flight,
      Icons.movie,
      Icons.music_note,
      Icons.pets,
      Icons.spa,
      Icons.local_cafe,
      Icons.account_balance_wallet,
      Icons.description,
      Icons.local_offer,
    ];

    String? createdCategoryName;

    String? nameErrorText;
    String? colorErrorText;
    String? iconErrorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: StatefulBuilder(
            builder: (context, setDialog) {
              return KidCard(
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Category',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 22,
                          color: AppColors.kText,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _KidDialogTextField(
                        controller: nameCtrl,
                        label: 'Name',
                        hint: 'Example: Snacks',
                      ),
                      if (nameErrorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          nameErrorText!,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.nunito,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.kErrorText,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      _KidDialogTextField(
                        controller: limitCtrl,
                        label: 'Monthly limit (optional)',
                        hint: 'Example: 100',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'Color',
                        style: TextStyle(
                          fontFamily: AppTextStyles.nunito,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.kText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: colors.map((c) {
                          final selected = c.value == chosenColor.value;
                          return GestureDetector(
                            onTap: () => setDialog(() {
                              chosenColor = c;
                              colorErrorText = null;
                            }),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? AppColors.kText : Colors.white,
                                  width: selected ? 3 : 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (colorErrorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          colorErrorText!,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.nunito,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.kErrorText,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Text(
                        'Icon',
                        style: TextStyle(
                          fontFamily: AppTextStyles.nunito,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.kText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: icons.map((ic) {
                          final selected = chosenIcon == ic;
                          return GestureDetector(
                            onTap: () => setDialog(() {
                              chosenIcon = ic;
                              iconErrorText = null;
                            }),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.kPurple.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.kPurple
                                      : AppColors.kPurple.withOpacity(0.25),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                ic,
                                color: AppColors.kText,
                                size: 22,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (iconErrorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          iconErrorText!,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.nunito,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.kErrorText,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: KidGhostButton(
                              label: 'Cancel',
                              onTap: () => Navigator.of(ctx, rootNavigator: true).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KidPrimaryButton(
                              label: 'Create',
                              onTap: () async {
                                final rawName = nameCtrl.text.trim();
                                if (rawName.isEmpty) {
                                  setDialog(() => nameErrorText = 'Enter a name');
                                  return;
                                }

                                final lt = limitCtrl.text.trim();
                                if (lt.isNotEmpty) {
                                  final parsed = num.tryParse(lt);
                                  if (parsed == null || parsed < 0) {
                                    setDialog(() => nameErrorText = null);
                                    await _showWarningDialog('Please enter a valid monthly limit.');
                                    return;
                                  }
                                }

                                setDialog(() {
                                  nameErrorText = null;
                                  colorErrorText = null;
                                  iconErrorText = null;
                                });

                                if (chosenIcon == null) {
                                  setDialog(() => iconErrorText = 'Pick an icon');
                                  return;
                                }

                                final profileId = await _getProfileId();

                                try {
                                  final List rows = await _sb
                                      .from('Category')
                                      .select('icon_color,name')
                                      .eq('profile_id', profileId)
                                      .eq('is_archived', false);

                                  final takenColors = <String>{
                                    for (final r in rows)
                                      _hexToColor(
                                        ((r as Map<String, dynamic>)['icon_color'] ?? '')
                                            .toString(),
                                      ).value.toRadixString(16).toUpperCase(),
                                  };

                                  final takenNames = <String>{
                                    for (final r in rows)
                                      _normalizeName(
                                        ((r as Map<String, dynamic>)['name'] ?? '')
                                            .toString(),
                                      ),
                                  };

                                  final chosenHex =
                                      chosenColor.value.toRadixString(16).toUpperCase();
                                  final normalized = _normalizeName(rawName);

                                  if (takenColors.contains(chosenHex)) {
                                    setDialog(() {
                                      colorErrorText =
                                          'This color is already used. Pick a different color.';
                                    });
                                    return;
                                  }

                                  if (takenNames.contains(normalized)) {
                                    setDialog(() {
                                      nameErrorText = 'A category with this name already exists';
                                    });
                                    return;
                                  }
                                } catch (_) {
                                  setDialog(() {
                                    nameErrorText = 'Could not validate. Please try again.';
                                  });
                                  return;
                                }

                                num? limit;
                                if (lt.isNotEmpty) limit = num.tryParse(lt);

                                final payload = {
                                  'name': rawName,
                                  'type': 'Custom',
                                  'monthly_limit': limit,
                                  'icon': chosenIcon.toString().split('.').last,
                                  'icon_color': chosenColor.value.toRadixString(16),
                                  'is_archived': false,
                                  'profile_id': profileId,
                                };

                                final inserted = await _sb
                                    .from('Category')
                                    .insert(payload)
                                    .select('category_id,name')
                                    .single();

                                createdCategoryName = inserted['name'] as String;

                                if (context.mounted) {
                                  Navigator.of(ctx, rootNavigator: true).pop();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (createdCategoryName == null) {
      throw Exception('Creation cancelled');
    }

    return createdCategoryName!;
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
          _categoryErrorText = null;
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
        final num limit =
            (limitVal is num) ? limitVal : num.tryParse('$limitVal') ?? 0;

        final num spentNow = await _getCategoryMonthlySpent(
          profileId,
          categoryId,
          _selectedDate,
        );

        if (limit > 0 && spentNow > limit && mounted) {
          await _showWarningDialog(
            'You went over the monthly limit for ${catRow['name']}.',
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

      if (currentBalance < 0) {
        await _showWarningDialog('Your balance is negative now.');
      } else if (currentBalance == 0) {
        await _showWarningDialog('Your balance is zero now.');
      }
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (picked.isAfter(today)) {
      if (!mounted) return;
      setState(() {
        _dateErrorText = 'Pick today or a past date';
      });
      return;
    } else {
      if (_dateErrorText != null) setState(() => _dateErrorText = null);
    }

    if (_type == 'Expense' && _selectedCategory == null) {
      try {
        final created = await _createCategoryDialog();
        await _loadCategories();
        setState(() {
          _selectedCategory = created;
          _categoryErrorText = null;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _categoryErrorText = 'Select or create a category';
        });
        return;
      }
    }

    try {
      final isExpense = _type == 'Expense';
      final amount = double.parse(_amountCtrl.text.trim());
      final currentBalance = (await _getCurrentBalance()).toDouble();

      final confirmed = await _showConfirmDialog(
        currentBalance: currentBalance,
        amount: amount,
        isExpense: isExpense,
        categoryName: isExpense ? _selectedCategory : null,
        dateText: _fmt(_selectedDate),
      );
      if (!confirmed) return;

      final newBalance =
          isExpense ? currentBalance - amount : currentBalance + amount;

      if (isExpense && newBalance == 0) {
        await _showWarningDialog(
          'This will bring your balance to zero.',
        );
      }

      await _submitToDb();

      if (!mounted) return;

      await _showSuccessDialog(
        isExpense ? 'Expense saved.' : 'Earning saved.',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEarning = _type == 'Earning';

    return KidScaffold(
      child: Stack(
        children: [
          const KidBubbles(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 58, 18, 18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: KidBackButton(
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 12),

                    const Text(
                      'Log Transaction',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 26,
                        color: AppColors.kText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    KidCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Type',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.kText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _KidTypeTabs(
                              value: _type,
                              onChanged: (v) {
                                setState(() {
                                  _type = v;
                                  if (v == 'Earning') {
                                    _selectedCategory = null;
                                    _categoryErrorText = null;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            if (!isEarning) ...[
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Category',
                                      style: TextStyle(
                                        fontFamily: AppTextStyles.nunito,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.kText,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        final created = await _createCategoryDialog();
                                        await _loadCategories();
                                        setState(() {
                                          _selectedCategory = created;
                                          _categoryErrorText = null;
                                        });
                                      } catch (_) {}
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.kPurple.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.kPurple.withOpacity(0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Text(
                                        'Add',
                                        style: TextStyle(
                                          fontFamily: AppTextStyles.nunito,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.kPurple,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.kInputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (_categoryErrorText != null)
                                        ? AppColors.kPink.withOpacity(0.6)
                                        : AppColors.kPurple.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    hint: Text(
                                      _loadingCats ? 'Loading...' : 'Pick a category',
                                      style: const TextStyle(
                                        fontFamily: AppTextStyles.nunito,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.kTextSoft,
                                      ),
                                    ),
                                    items: _categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                fontFamily: AppTextStyles.nunito,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.kText,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _loadingCats
                                        ? null
                                        : (v) => setState(() {
                                              _selectedCategory = v;
                                              _categoryErrorText = null;
                                            }),
                                  ),
                                ),
                              ),

                              if (_loadingCats) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Loading categories...',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.nunito,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.kTextSoft,
                                  ),
                                ),
                              ],

                              if (_categoryErrorText != null) ...[
                                const SizedBox(height: 8),
                                KidAlert(_categoryErrorText!),
                              ],

                              const SizedBox(height: 16),
                            ],

                            KidInput(
                              label: 'Amount',
                              placeholder: 'Example: 25',
                              icon: '💰',
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              errorText: null,
                              onChanged: (_) {},
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'SAR',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.kTextSoft,
                              ),
                            ),

                            const SizedBox(height: 14),

                            const Text(
                              '📅  Date',
                              style: TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.kText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final picked = await _pickDateDialog(_selectedDate);
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                    _datePicked = true;
                                    _dateErrorText = null;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: (_dateErrorText != null)
                                      ? AppColors.kPink.withOpacity(0.08)
                                      : AppColors.kInputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (_dateErrorText != null)
                                        ? AppColors.kPink.withOpacity(0.6)
                                        : AppColors.kPurple.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _datePicked ? _fmt(_selectedDate) : _fmt(DateTime.now()),
                                        style: TextStyle(
                                          fontFamily: AppTextStyles.nunito,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _datePicked ? AppColors.kText : AppColors.kTextSoft,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month, color: AppColors.kPurple),
                                  ],
                                ),
                              ),
                            ),
                            if (_dateErrorText != null) ...[
                              const SizedBox(height: 8),
                              KidAlert(_dateErrorText!),
                            ],

                            const SizedBox(height: 18),

                            KidPrimaryButton(
                              label: 'Log',
                              onTap: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    const KidInfoBox(
                      'Tip: Use Expense for spending and Earning for money you get.',
                    ),
                  ],
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
}

class _KidTypeTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _KidTypeTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isExpense = value == 'Expense';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Expense',
            emoji: '🧾',
            selected: isExpense,
            onTap: () => onChanged('Expense'),
          ),
          const SizedBox(width: 8),
          _tab(
            label: 'Earning',
            emoji: '✨',
            selected: !isExpense,
            onTap: () => onChanged('Earning'),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.purpleBtn : null,
            color: selected ? null : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white.withOpacity(0.0) : Colors.white.withOpacity(0.55),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '$emoji  $label',
              style: TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppColors.kText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ConfirmLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTextStyles.nunito,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.kTextSoft,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppColors.kText,
            ),
          ),
        ],
      ),
    );
  }
}

class _KidDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _KidDialogTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.kText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.kText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: AppTextStyles.nunito,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB8AED4),
            ),
            filled: true,
            fillColor: AppColors.kInputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.kPurple.withOpacity(0.2), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.kPurple.withOpacity(0.2), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.kPurple, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}