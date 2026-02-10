import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:surra_application/screens/profile/profile_main.dart';

import '../../theme/app_colors.dart';
import '../../services/ocr_service.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/auth_helpers.dart';

/// ===========================================================
/// MODELS FOR PARSED RECEIPT
/// ===========================================================

class ReceiptItem {
  final String name;
  final double price;

  ReceiptItem({required this.name, required this.price});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }
}

class ParsedReceipt {
  final String merchant;
  final DateTime? date;
  final List<ReceiptItem> items;
  final double total;
  final String currency;
  final String type; // "expense" or "earning" 

  ParsedReceipt({
    required this.merchant,
    required this.date,
    required this.items,
    required this.total,
    required this.currency,
    required this.type,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? 'expense').toString().toLowerCase();
    final normalizedType =
        (rawType == 'earning') ? 'earning' : 'expense'; // default to expense

    return ParsedReceipt(
      merchant: json['merchant'] ?? 'Unknown',
      date: json['date'] != null && json['date'] != ''
          ? DateTime.parse(json['date'])
          : null,
      items: (json['items'] as List<dynamic>)
          .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
      currency: json['currency'] ?? 'SAR',
      type: normalizedType,
    );
  }
}

// This is the text we send to the category model
String buildTextForCategoryModel(ParsedReceipt r) {
  final itemsText = r.items.map((i) => "${i.name} ${i.price} SAR").join(", ");
  return "Merchant: ${r.merchant}. "
      "Total: ${r.total} SAR. "
      "Date: ${r.date?.toIso8601String() ?? "unknown"}. "
      "Items: $itemsText.";
}

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  bool _loading = false;

  static const String mistralApiKey = "aCjrHSUoLleLLnHgR9d7Ig7KEBzVW7KE";

  // Backend endpoints
  static const String preprocessUrl = "http://127.0.0.1:8000/receipt/preprocess";
  static const String categoryPredictUrl =
      "http://127.0.0.1:8000/receipt/category/predict";
  static const String feedbackUrl =
      "http://127.0.0.1:8000/receipt/category/feedback";

  /// =========================================================
  /// OCR + PREPROCESS
  /// =========================================================
  Future<void> _runOcrOnBytes(Uint8List bytes, String fileName) async {
    if (_loading) return;

    if (mistralApiKey.trim().isEmpty ||
        mistralApiKey.contains("PASTE_YOUR")) {
      _showSnack("Add your Mistral API key first.");
      return;
    }

    setState(() => _loading = true);

    try {
      final service = MistralOcrService(apiKey: mistralApiKey);

      final text = await service.extractTextFromBytes(
        bytes: bytes,
        fileName: fileName,
      );

      debugPrint("OCR DONE, sending to backend...");

      final response = await http.post(
        Uri.parse(preprocessUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "ocr_text": text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Backend error: ${response.body}");
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      debugPrint("========== BACKEND RESULT ==========");
      const encoder = JsonEncoder.withIndent('  ');
      debugPrint(encoder.convert(decoded));
      debugPrint("======== END BACKEND RESULT ========");

      // parse receipt safely
      if (decoded["data"] == null || decoded["data"] is! Map) {
        throw Exception("Unexpected backend shape, 'data' is missing or not an object");
      }

      final receiptJson = decoded["data"] as Map<String, dynamic>;
      ParsedReceipt parsedReceipt;

      try {
        parsedReceipt = ParsedReceipt.fromJson(receiptJson);
      } catch (e, st) {
        debugPrint("Error while building ParsedReceipt: $e");
        debugPrint(st.toString());
        throw Exception("Could not parse receipt JSON");
      }

      if (!mounted) {
        debugPrint("ScanReceiptScreen is not mounted anymore, skipping navigation.");
        return;
      }

      debugPrint("Pushing ReceiptReviewScreen...");
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            receipt: parsedReceipt,
            categoryPredictUrl: categoryPredictUrl,
            feedbackUrl: feedbackUrl,
          ),
        ),
      );
      debugPrint("Returned from ReceiptReviewScreen.");

    } catch (e, st) {
      debugPrint("ERROR in _runOcrOnBytes: $e");
      debugPrint(st.toString());
      _showSnack("Error: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // CAMERA -> image bytes
  Future<void> _useCamera() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    await _runOcrOnBytes(bytes, "receipt.jpg");
  }

  // UPLOAD -> file (pdf or image)
  Future<void> _uploadReceiptFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );

    if (res == null || res.files.isEmpty) return;

    final file = res.files.first;

    Uint8List? bytes = file.bytes;

    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes == null) {
      _showSnack("Could not read file bytes.");
      return;
    }

    await _runOcrOnBytes(bytes, file.name);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
          ),
          SafeArea(
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
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scan Receipt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan your receipt to automatically log and categorize your expense.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _BigScanOption(
                          icon: Icons.camera_alt_rounded,
                          title: 'Use Camera',
                          subtitle: 'Take a photo of your receipt',
                          onTap: _loading ? () {} : _useCamera,
                        ),
                        const SizedBox(height: 20),
                        _BigScanOption(
                          icon: Icons.upload_file_rounded,
                          title: 'Upload Receipt',
                          subtitle: 'Upload a PDF or image file',
                          onTap: _loading ? () {} : _uploadReceiptFile,
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 24),
                          const Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===========================================================
/// BIG OPTION CARD
/// ===========================================================

class _BigScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C5CE6),
                    Color(0xFF6B4CE6),
                  ],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================
/// REVIEW AND LOG SCREEN (Figma-style ticket)
/// ===========================================================

class ReceiptReviewScreen extends StatefulWidget {
  final ParsedReceipt receipt;
  final String categoryPredictUrl;
  final String feedbackUrl;

  const ReceiptReviewScreen({
    super.key,
    required this.receipt,
    required this.categoryPredictUrl,
    required this.feedbackUrl,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

/// Category option used in dropdown
class _CategoryOption {
  final String name;          // Category.name in DB and shown to user
  final Color color;          // Category.icon_color
  final bool isFixed;         // Whether this is one of the fixed model labels
  final String? backendLabel; // "groceries", "transportation", etc. for fixed

  _CategoryOption({
    required this.name,
    required this.color,
    required this.isFixed,
    required this.backendLabel,
  });
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  bool _loadingCategory = true;
  bool _logging = false;

  final SupabaseClient _sb = Supabase.instance.client;
  String? _profileIdCache;

  final List<_CategoryOption> _categoryOptions = [];
  _CategoryOption? _selectedCategory;
  _CategoryOption? _predictedCategory;

  String? _modelSuggestedCategoryName;

  bool _transactionFailed = false; 

  // Backend → UI label mapping
  static const Map<String, String> _backendToUi = {
    "groceries": "Groceries",
    "transportation": "Transportation",
    "utilities": "Utilities",
    "health": "Health",
    "entertainment": "Entertainment",
    "others": "Other",
  };

  // UI → backend label
  static final Map<String, String> _uiToBackend = {
    for (final e in _backendToUi.entries) e.value: e.key,
  };

  @override
  void initState() {
    super.initState();
    // If total is 0, mark as failed immediately
    if (widget.receipt.total == 0) {
      _transactionFailed = true;
    }
    _loadCategoriesAndPrediction();
  }

  Future<String> _getProfileId() async {
    if (_profileIdCache != null) return _profileIdCache!;
    final pid = await getProfileId(context);
    if (pid == null) {
      throw Exception('Sign in required');
    }
    _profileIdCache = pid;
    return pid;
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
                'Transaction Logged',
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
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 16,
                    shadowColor: AppColors.accent.withOpacity(0.7),
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
            ],
          ),
        ),
      );
    },
  );
}


  Color _hexToColor(String value) {
    var v = value.replaceAll('#', '');
    if (v.length == 6) {
      v = 'FF$v';
    }
    return Color(int.parse(v, radix: 16));
  }

  String _fmt(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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

  Future<void> _updateBalanceForExpense({
    required num totalAmount,
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

    final num next = current - totalAmount;

    await _sb
        .from('User_Profile')
        .update({'current_balance': next})
        .eq('profile_id', profileId);
  }

  Future<void> _loadCategoriesAndPrediction() async {
    setState(() {
      _loadingCategory = true;
    });

    try {
      final profileId = await _getProfileId();

      // 1) all categories (fixed + custom)
      final List rows = await _sb
          .from('Category')
          .select('name, icon_color')
          .eq('profile_id', profileId)
          .eq('is_archived', false)
          .order('name');

      _categoryOptions.clear();

      for (final raw in rows) {
        final map = raw as Map<String, dynamic>;
        final name = (map['name'] ?? '').toString();
        final rawColor = (map['icon_color'] ?? '').toString();

        Color color;
        try {
          color = _hexToColor(rawColor);
        } catch (_) {
          color = const Color(0xFFFDBA3F);
        }

        final isFixed = _uiToBackend.containsKey(name);
        final backendLabel = isFixed ? _uiToBackend[name] : null;

        _categoryOptions.add(
          _CategoryOption(
            name: name,
            color: color,
            isFixed: isFixed,
            backendLabel: backendLabel,
          ),
        );
      }

      // 2) predicted category from backend
      final text = buildTextForCategoryModel(widget.receipt);
      final resp = await http.post(
        Uri.parse(widget.categoryPredictUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      String? backendPredicted;
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        backendPredicted = json['category'] as String?;
      }

      if (backendPredicted != null) {
        final uiName = _backendToUi[backendPredicted];
        if (uiName != null) {
          _predictedCategory = _categoryOptions.firstWhere(
            (c) => c.name == uiName,
            orElse: () => _categoryOptions.isNotEmpty
                ? _categoryOptions.first
                : _CategoryOption(
                    name: uiName,
                    color: const Color(0xFFFDBA3F),
                    isFixed: true,
                    backendLabel: backendPredicted,
                  ),
          );
        }
      }

      _selectedCategory = _predictedCategory ??
          (_categoryOptions.isNotEmpty ? _categoryOptions.first : null);

      _modelSuggestedCategoryName = _predictedCategory?.name;
    } catch (e) {
      debugPrint("Error in _loadCategoriesAndPrediction: $e");
      if (_categoryOptions.isNotEmpty && _selectedCategory == null) {
        _selectedCategory = _categoryOptions.first;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCategory = false);
      }
    }
  }

  Future<void> _onLogPressed() async {
    if (_selectedCategory == null) return;

    setState(() {
      _logging = true;
      _transactionFailed = false; 
    });

    try {
      final selected = _selectedCategory!;
      final predicted = _predictedCategory;

      // Only send feedback when user changed between fixed labels
      bool sendFeedback = false;
      String? backendCorrectLabel;

      if (predicted != null &&
          predicted.isFixed &&
          selected.isFixed &&
          selected.name != predicted.name) {
        sendFeedback = true;
        backendCorrectLabel = selected.backendLabel;
      }

      if (sendFeedback && backendCorrectLabel != null) {
        final text = buildTextForCategoryModel(widget.receipt);
        await http.post(
          Uri.parse(widget.feedbackUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "text": text,
            "correct_category": backendCorrectLabel,
          }),
        );
      }

      // Log expense in DB (one transaction per line item)
      await _logExpenseTransaction(
        widget.receipt,
        selected.name,
      );

      if (!mounted) return;

    await _showSuccessDialog(
      message: 'Your transaction has been added successfully.',
    );

      // no SnackBar, just close on success
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Error while logging transaction: $e");
      if (!mounted) return;
      setState(() {
        _transactionFailed = true; // this triggers the red header
      });
    } finally {
      if (mounted) {
        setState(() => _logging = false);
      }
    }
  }

Future<void> _logExpenseTransaction(
  ParsedReceipt receipt,
  String categoryName,
) async {
  // 1) Resolve profile and category
  final profileId = await _getProfileId();
  final categoryId = await _getCategoryIdByName(categoryName);

  // Use the receipt date if present, otherwise fallback to today
  final DateTime date = receipt.date ?? DateTime.now();
  final String dateStr = _fmt(date);

  // Total amount from the parsed receipt
  final double amount = receipt.total;

  // Map parsed type ("expense"/"earning") to DB value ("Expense"/"Earning")
  final String dbType =
      receipt.type.toLowerCase() == 'earning' ? 'Earning' : 'Expense';

  // 2) Single Transaction row for the whole receipt
  final Map<String, dynamic> payload = {
    'type': dbType,
    'amount': amount,
    'date': dateStr,
    'profile_id': profileId,
    'category_id': categoryId,
  };

  await _sb.from('Transaction').insert(payload);

  // 3) Update balance and summaries
  // NOTE: currently this always treats it as an expense.
  // If you want earnings to add to balance and go to total_income,
  // we can branch here later.
  await _updateBalanceForExpense(totalAmount: amount);

  await _bumpMonthTotalsAndCategorySummary(
    profileId: profileId,
    categoryId: categoryId,
    date: date,
    amount: amount,
  );
}

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // purple background with rounded bottom – same as ScanReceiptScreen
          Container(
            height: 320,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          // foreground content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Back button (text + arrow)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 350),
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const ProfileMainPage(); 
                        },
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          final tween = Tween<Offset>(
                            begin: const Offset(0, 1), // comes from bottom
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeOutCubic));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                      (route) => false,
                    );
                  },
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

                const SizedBox(height: 24),

                // the receipt ticket in the middle
                Expanded(
                  child: Center(
                    child: ReceiptTicketCard(
                      receipt: r,
                      categories: _categoryOptions,
                      selectedCategory: _selectedCategory,
                      modelSuggestedCategoryName:
                          _modelSuggestedCategoryName,
                      loadingCategory: _loadingCategory,
                      onCategoryChanged: (_CategoryOption opt) {
                        setState(() => _selectedCategory = opt);
                      },
                      transactionFailed: _transactionFailed, 
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Log button area (keeps same height even when hidden)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IgnorePointer(
                    ignoring: _transactionFailed, // no taps when failed
                    child: Opacity(
                      opacity: _transactionFailed ? 0 : 1, // visually hide when failed
                      child: ElevatedButton(
                        onPressed: _logging ? null : _onLogPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A43DD),
                          elevation: 12,
                          shadowColor: const Color(0xFF6A43DD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 80,
                            vertical: 14,
                          ),
                        ),
                        child: _logging
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Log',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // <-- this closes _ReceiptReviewScreenState



/// ===========================================================
/// Ticket widget – matches Figma layout, only items list scrolls
/// ===========================================================
class ReceiptTicketCard extends StatelessWidget {
  final ParsedReceipt receipt;
  final List<_CategoryOption> categories;
  final _CategoryOption? selectedCategory;
  final String? modelSuggestedCategoryName;
  final bool loadingCategory;
  final ValueChanged<_CategoryOption> onCategoryChanged;
  final bool transactionFailed;

  const ReceiptTicketCard({
    super.key,
    required this.receipt,
    required this.categories,
    required this.selectedCategory,
    required this.modelSuggestedCategoryName,
    required this.loadingCategory,
    required this.onCategoryChanged,
    required this.transactionFailed,
  });

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final dropdownColor =
        selectedCategory?.color ?? const Color(0xFFFDBA3F);

    return SizedBox(
      width: 294,
      height: 520,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White ticket
          Container(
            height: double.infinity, 
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.41),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======= HEADER AREA =======
                if (!transactionFailed) ...[
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF22C55E),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transaction Success',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      r.merchant,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      r.date != null
                          ? '${r.date!.day}-${r.date!.month}-${r.date!.year}'
                          : '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.error_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transaction Failed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                const _DashedDivider(),
                const SizedBox(height: 16),

                // ======= MIDDLE AREA (FIXED BY USING Expanded) =======
                Expanded(
                  child: transactionFailed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: const Text(
                              'Please scan a clearer receipt\nand try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: r.items.length,
                          itemBuilder: (context, index) {
                            final item = r.items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item.price.toStringAsFixed(0)} SAR',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 18),
                const _DashedDivider(),

                // ======= BOTTOM AREA (CATEGORY + TOTAL) – HIDDEN ON FAIL =======
                if (!transactionFailed) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Category',
                        style: TextStyle(
                          color: Color(0xFF989898),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _CategoryChipDropdown(
                        categories: categories,
                        selected: selectedCategory,
                        color: dropdownColor,
                        loading: loadingCategory,
                        onChanged: onCategoryChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Color(0xFF989898),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${r.total.toStringAsFixed(1)} SAR',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF6A43DD),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // TOP scallops
          Positioned(
            top: -7.5,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                11,
                (_) => Container(
                  width: 14.77,
                  height: 14.77,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // Side notches
          const Positioned(
            left: -7.5,
            top: 220,
            child: CircleAvatar(
              radius: 7.5,
              backgroundColor: Color(0xFF1D1B32),
            ),
          ),
          const Positioned(
            right: -7.5,
            top: 220,
            child: CircleAvatar(
              radius: 7.5,
              backgroundColor: Color(0xFF1D1B32),
            ),
          ),

          // Bottom scallops
          Positioned(
            bottom: -7.5,
            left: 18,
            right: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                11,
                (_) => Container(
                  width: 14.77,
                  height: 14.77,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1B32),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed divider (grey, like Figma)
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 2,
              color: const Color(0xFFD3D2D3),
            ),
          ),
        );
      },
    );
  }
}

/// Category dropdown styled as coloured pill
class _CategoryChipDropdown extends StatelessWidget {
  final List<_CategoryOption> categories;
  final _CategoryOption? selected;
  final Color color;
  final bool loading;
  final ValueChanged<_CategoryOption> onChanged;

  const _CategoryChipDropdown({
    super.key,
    required this.categories,
    required this.selected,
    required this.color,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: loading,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_CategoryOption>(
            value: selected,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            dropdownColor: const Color(0xFF2B2B48),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            onChanged: (opt) {
              if (opt != null) {
                onChanged(opt);
              }
            },
            items: categories.map((c) {
              return DropdownMenuItem<_CategoryOption>(
                value: c,
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
