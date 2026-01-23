import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  ParsedReceipt({
    required this.merchant,
    required this.date,
    required this.items,
    required this.total,
    required this.currency,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

// This is the text we send to the category model
String buildTextForCategoryModel(ParsedReceipt r) {
  final itemsText =
      r.items.map((i) => "${i.name} ${i.price} SAR").join(", ");
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
  static const String preprocessUrl =
      "http://127.0.0.1:8000/receipt/preprocess";
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

    // -------------------------------
    // PARSE RECEIPT SAFELY
    // -------------------------------
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

    // -------------------------------
    // OPEN REVIEW SCREEN
    // -------------------------------
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

    _showSnack("Receipt processed successfully");
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
          // TOP GRADIENT
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6B4CE6),
                  Color(0xFF4A35B8),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BACK + TITLE
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Scan Receipt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // CONTENT CARD
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
                          'Choose how to scan',
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
/// REVIEW AND LOG SCREEN
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

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  bool _loadingCategory = true;
  bool _logging = false;


  // What the user sees and what we store in Supabase
  final List<String> _categories = <String>[
    "Groceries",
    "Transportation",
    "Utilities",
    "Health",
    "Entertainment",
    "Other",
  ];

  // Model labels from backend CATEGORIES
  // CATEGORIES = ["groceries", "transportation", "utilities", "health", "entertainment", "others"]
  static const Map<String, String> _modelToUi = {
    "groceries": "Groceries",
    "transportation": "Transportation",
    "utilities": "Utilities",
    "health": "Health",
    "entertainment": "Entertainment",
    "others": "Other",
  };

  // Inverse map: pretty label -> model label
  late final Map<String, String> _uiToModel =
      {for (final e in _modelToUi.entries) e.value: e.key};


  final SupabaseClient _sb = Supabase.instance.client;
  String? _profileIdCache;
  String? _selectedCategory;
  String? _modelSuggestedCategory;

  @override
  void initState() {
    super.initState();
    _initCategory();
  }

  Future<void> _initCategory() async {
    try {
      final text = buildTextForCategoryModel(widget.receipt);

      final resp = await http.post(
        Uri.parse(widget.categoryPredictUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final modelCat = json['category'] as String;

        // Save both model label and pretty label
        final uiCat = _modelToUi[modelCat] ?? "Other";
        _modelSuggestedCategory = uiCat;

        if (_categories.contains(uiCat)) {
          _selectedCategory = uiCat;
        } else {
          _selectedCategory = "Other";
        }
      } else {
        _selectedCategory = "Other";
      }
    } catch (_) {
      _selectedCategory = "Other";
    } finally {
      if (mounted) {
        setState(() => _loadingCategory = false);
      }
    }
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

  String _fmt(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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


  Future<void> _onLogPressed() async {
    if (_selectedCategory == null) return;

    setState(() => _logging = true);
    try {
      // 1. Send feedback to backend so model can learn
      final text = buildTextForCategoryModel(widget.receipt);

      final uiCategory = _selectedCategory!;
      // Map pretty label (Other) to model label (others, groceries, ...)
      final backendCategory = _uiToModel[uiCategory] ?? "others";

      await http.post(
        Uri.parse(widget.feedbackUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "text": text,
          "correct_category": backendCategory,
        }),
      );

      // 2. Log expense in your database
      await _logExpenseTransaction(
        widget.receipt,
        _selectedCategory!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense logged")),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _logging = false);
      }
    }
  }

  Future<void> _logExpenseTransaction(
      ParsedReceipt receipt, String categoryName) async {
    // 1. Resolve profile and category
    final profileId = await _getProfileId();
    final categoryId = await _getCategoryIdByName(categoryName);

    final DateTime date = receipt.date ?? DateTime.now();
    final String dateStr = _fmt(date);

    // 2. Insert one Transaction row per item
    num totalAmount = 0;

    for (final item in receipt.items) {
      final double amount = item.price;
      totalAmount += amount;

      final Map<String, dynamic> payload = {
        'type': 'Expense',
        'amount': amount,
        'date': dateStr,
        'profile_id': profileId,
        'category_id': categoryId,
        // you can add extra fields here if your table has them:
        // 'merchant': receipt.merchant,
        // 'description': item.name,
        // 'source': 'receipt_ocr',
      };

      await _sb.from('Transaction').insert(payload);
    }

    // 3. Update current balance once using totalAmount
    await _updateBalanceForExpense(totalAmount: totalAmount);

    // 4. Update monthly totals and category summary once
    await _bumpMonthTotalsAndCategorySummary(
      profileId: profileId,
      categoryId: categoryId,
      date: date,
      amount: totalAmount,
    );

    // If you want, you can also add overspend warnings here later
    // by reusing the same logic from LogTransactionManuallyPage.
  }


  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header like your design
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.merchant,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.date != null
                            ? "${r.date!.day}-${r.date!.month}-${r.date!.year}"
                            : "",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Items list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: r.items.length,
                itemBuilder: (context, index) {
                  final item = r.items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${item.price} SAR",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Total pill
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 80),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CE6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "${r.total}  SAR",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Category",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: _loadingCategory,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: AppColors.card,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ),
                  if (_loadingCategory)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        "Predicting category...",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (_modelSuggestedCategory != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Suggested: $_modelSuggestedCategory",
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Log button
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton(
                onPressed: _logging ? null : _onLogPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CE6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 80, vertical: 14),
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
                        "Log",
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
  }
}
