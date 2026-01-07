import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class MistralOcrService {
  final String apiKey;
  MistralOcrService({required this.apiKey});

  Future<String> extractTextFromBytes({
    required Uint8List bytes,
    required String fileName, // pdf/jpg/png...
  }) async {
    // 1) upload to files as multipart -> get file_id
    final fileId = await _uploadForOcrMultipart(
      bytes: bytes,
      fileName: fileName,
    );

    // 2) call OCR with file_id
    final uri = Uri.parse("https://api.mistral.ai/v1/ocr");
    final payload = {
      "model": "mistral-ocr-latest",
      "document": {"file_id": fileId},
    };

    final resp = await http
        .post(
          uri,
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 120));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception("OCR failed: ${resp.statusCode}\n${resp.body}");
    }

    final data = jsonDecode(resp.body);
    return _extractTextFromOcrResponse(data);
  }

  Future<String> _uploadForOcrMultipart({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse("https://api.mistral.ai/v1/files");

    final req = http.MultipartRequest("POST", uri);

    req.headers["Authorization"] = "Bearer $apiKey";

    // required fields (purpose usually required)
    req.fields["purpose"] = "ocr";

    // THIS is what your error complains about: field name must be "file"
    req.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName,
      ),
    );

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("File upload failed: ${streamed.statusCode}\n$body");
    }

    final data = jsonDecode(body);
    final id = (data is Map) ? data["id"] : null;

    if (id == null || id.toString().isEmpty) {
      throw Exception("Upload returned no file id: $data");
    }

    return id.toString();
  }

  String _extractTextFromOcrResponse(dynamic data) {
    String extracted = "";

    if (data is Map) {
      if (data["pages"] is List && (data["pages"] as List).isNotEmpty) {
        final first = (data["pages"] as List).first;
        if (first is Map) {
          extracted = (first["markdown"] ??
                  first["text"] ??
                  first["content"] ??
                  "")
              .toString();
        }
      }
      extracted = extracted.isNotEmpty ? extracted : data.toString();
    } else {
      extracted = data.toString();
    }

    return extracted.trim();
  }
}
