import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class GoldService {
  static final SupabaseClient _sb = Supabase.instance.client;

  static const String _backendBaseUrl = 'http://127.0.0.1:8000';
  // Android emulator: http://10.0.2.2:8000
  // static const String _backendBaseUrl = 'http://10.0.2.2:8080';

  static Future<
    void
  >
  refreshGoldOnBackend({
    int samples = 60,
  }) async {
    final uri = Uri.parse(
      '$_backendBaseUrl/gold/refresh?samples=$samples',
    );

    final res = await http.post(
      uri,
    );

    if (res.statusCode >=
        400) {
      throw Exception(
        'Backend refresh failed ${res.statusCode}: ${res.body}',
      );
    }
  }

  ///  Get latest gold prices from DB (18/21/24) + interval (lo/hi)
  static Future<
    Map<
      String,
      dynamic
    >?
  >
  getLatestGoldFromDb() async {
    final rows = await _sb
        .from(
          'Gold',
        )
        .select(
          'karat, past_price, current_price, predicted_price, predicted_low, predicted_high, confidence_level, created_at',
        )
        .order(
          'created_at',
          ascending: false,
        )
        .limit(
          200,
        );

    double _num(
      dynamic v,
    ) {
      if (v ==
          null)
        return 0.0;
      if (v
          is num)
        return v.toDouble();
      return double.tryParse(
            '$v',
          ) ??
          0.0;
    }

    final Map<
      int,
      Map<
        String,
        dynamic
      >
    >
    latestByKarat = {};

    for (final r
        in (rows
            as List)) {
      final map =
          Map<
            String,
            dynamic
          >.from(
            r
                as Map,
          );
      final karatInt =
          (map['karat']
                  as num)
              .toInt();

      if (!latestByKarat.containsKey(
        karatInt,
      )) {
        latestByKarat[karatInt] = map;
      }
      if (latestByKarat.length ==
          3)
        break; // 18/21/24
    }

    if (latestByKarat.isEmpty) return null;

    return {
      'unit': 'SAR_per_gram',
      'prices': {
        for (final e in latestByKarat.entries)
          '${e.key}': {
            'past': _num(
              e.value['past_price'],
            ),
            'current': _num(
              e.value['current_price'],
            ),
            'predicted_price': _num(
              e.value['predicted_price'],
            ),
            'predicted_tplus7_interval': {
              'lo': _num(
                e.value['predicted_low'],
              ),
              'hi': _num(
                e.value['predicted_high'],
              ),
            },
            'confidence': {
              'level':
                  (e.value['confidence_level'] ??
                          'low')
                      .toString()
                      .toLowerCase(),
            },
            'created_at': e.value['created_at'],
          },
      },
    };
  }
}
