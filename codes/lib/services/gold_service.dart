import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class GoldService {
  static final SupabaseClient _sb = Supabase.instance.client;

 
  static const String _backendBaseUrl = 'http://127.0.0.1:8000';
  // Android emulator: http://10.0.2.2:8000
  // static const String _backendBaseUrl = 'http://10.0.2.2:8080';

static Future<void> refreshGoldOnBackend({int samples = 60}) async {
  final uri = Uri.parse('$_backendBaseUrl/gold/refresh?samples=$samples');

  final res = await http.post(uri);

  if (res.statusCode >= 400) {
    
    throw Exception('Backend refresh failed ${res.statusCode}: ${res.body}');
  }
}

  ///  Get latest gold prices from DB
  static Future<Map<String, dynamic>?> getLatestGoldFromDb() async {
    final rows = await _sb
        .from('Gold')
        .select(
          'karat, past_price, current_price, predicted_price, confidence_level, created_at',
        )
        .order('created_at', ascending: false)
        .limit(200);

    final Map<String, Map<String, dynamic>> latestByKarat = {};

    for (final r in (rows as List)) {
      final karatInt = (r['karat'] as num).toInt();
      final key = '${karatInt}K';

      if (!latestByKarat.containsKey(key)) {
        latestByKarat[key] = r as Map<String, dynamic>;
      }
      if (latestByKarat.length == 3) break;
    }

    if (latestByKarat.isEmpty) return null;

    return {
      'unit': 'SAR_per_gram',
      'prices': {
        for (final e in latestByKarat.entries)
          e.key: {
            'past': (e.value['past_price'] as num).toDouble(),
            'current': (e.value['current_price'] as num).toDouble(),
            'predicted_tomorrow':
                (e.value['predicted_price'] as num).toDouble(),
            'confidence': (e.value['confidence_level'] as String? ?? 'low').toLowerCase(),

            'created_at': e.value['created_at'],
          }
      }
    };
  }


}
