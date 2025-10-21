import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class MonthlyFinancialService {
  static final _supabase = Supabase.instance.client;

  /// Updates or creates the current month's record with dynamic income & expenses.
  static Future<void> generateMonthlyRecord(String profileId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(
        now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1,
        1,
      );
      final monthEnd = nextMonthStart.subtract(const Duration(days: 1));

      // 🟣 Ensure current month record exists
      final existing = await _supabase
          .from('Monthly_Financial_Record')
          .select()
          .eq('profile_id', profileId)
          .eq('period_start', monthStart.toIso8601String())
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('Monthly_Financial_Record').insert({
          'profile_id': profileId,
          'period_start': monthStart.toIso8601String(),
          'period_end': monthEnd.toIso8601String(),
          'total_income': 0,
          'total_expense': 0,
          'monthly_saving': 0,
        });
        debugPrint('🟢 Created new monthly record for $monthStart');
      }

      // 🟣 Fetch variable (transactional) income and expenses
      final tx = await _supabase
          .from('Transaction')
          .select('type, amount, date')
          .eq('profile_id', profileId)
          .gte('date', monthStart.toIso8601String())
          .lt('date', nextMonthStart.toIso8601String());

      double transactionEarning = 0;
      double transactionExpense = 0;

      for (final t in (tx as List? ?? [])) {
        final amt = (t['amount'] ?? 0).toDouble();
        final typ = (t['type'] ?? '').toString().toLowerCase();
        if (typ == 'earning') transactionEarning += amt;
        if (typ == 'expense') transactionExpense += amt;
      }

      // 🟣 Fetch fixed income
      final fi = await _supabase
          .from('Fixed_Income')
          .select('monthly_income, start_time, end_time')
          .eq('profile_id', profileId);

      double fixedIncome = 0;
      for (final i in (fi as List? ?? [])) {
        final start = DateTime.parse(i['start_time']);
        final end = DateTime.parse(i['end_time']);
        if (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
          fixedIncome += (i['monthly_income'] ?? 0).toDouble();
        }
      }

      // 🟣 Fetch fixed expense
      final fe = await _supabase
          .from('Fixed_Expense')
          .select('amount, start_time, end_time')
          .eq('profile_id', profileId);

      double fixedExpense = 0;
      for (final e in (fe as List? ?? [])) {
        final start = DateTime.parse(e['start_time']);
        final end = DateTime.parse(e['end_time']);
        if (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
          fixedExpense += (e['amount'] ?? 0).toDouble();
        }
      }

      // 🟣 Calculate monthly saving
      final totalIncome = fixedIncome + transactionEarning;
      final totalExpense = fixedExpense + transactionExpense;
      final monthlySaving = totalIncome - totalExpense;

      // 🟣 Update record
      await _supabase
          .from('Monthly_Financial_Record')
          .update({
            'total_income': totalIncome,
            'total_expense': totalExpense,
            'monthly_saving': monthlySaving,
          })
          .eq('profile_id', profileId)
          .eq('period_start', monthStart.toIso8601String());

      debugPrint(
          '✅ Monthly record updated → income=$totalIncome | expense=$totalExpense | saving=$monthlySaving');
    } catch (e) {
      debugPrint('❌ Error in generateMonthlyRecord: $e');
    }
  }
}
