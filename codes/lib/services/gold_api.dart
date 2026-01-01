import 'dart:convert';
import 'package:http/http.dart' as http;

class GoldApi {
  static const String _baseUrl = 'http://10.0.2.2:8000'; 
  static const String _apiKey = 'localdev-123';

  static Future<Map<String, dynamic>> fetchGoldTrends() async {
    final url = Uri.parse('$_baseUrl/gold/predict?samples=60');

    final res = await http.get(
      url,
      headers: {
        'x-api-key': _apiKey,
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
