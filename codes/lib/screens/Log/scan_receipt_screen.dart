import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../services/ocr_service.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;



class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  
  
  
  final _picker = ImagePicker();
  bool _loading = false;

  static const String mistralApiKey = "aCjrHSUoLleLLnHgR9d7Ig7KEBzVW7KE";

  static const String backendUrl =
    "http://10.0.2.2:8080/receipt/preprocess";

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
      Uri.parse(backendUrl),
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

    final decoded = jsonDecode(response.body);

    debugPrint("========== BACKEND RESULT ==========");
  const encoder = JsonEncoder.withIndent('  ');
debugPrint(encoder.convert(decoded));
    debugPrint("======== END BACKEND RESULT ========");

    _showSnack("Receipt processed successfully");
  } catch (e) {
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
      withData: true, // important to get bytes
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );

    if (res == null || res.files.isEmpty) return;

    final file = res.files.first;

    // Prefer bytes directly
    Uint8List? bytes = file.bytes;

    // Fallback: read from path
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
          // ===== TOP GRADIENT =====
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
                // ===== BACK + TITLE =====
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

                // ===== CONTENT CARD =====
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

                        // ===== CAMERA OPTION =====
                        _BigScanOption(
                          icon: Icons.camera_alt_rounded,
                          title: 'Use Camera',
                          subtitle: 'Take a photo of your receipt',
                          onTap: _loading ? () {} : _useCamera,
                        ),

                        const SizedBox(height: 20),

                        // ===== UPLOAD OPTION =====
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

// ============================================================
// BIG OPTION CARD
// ============================================================

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
            // ICON CIRCLE
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

            // TEXT
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
