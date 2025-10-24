import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// 🟣 Handles automatic creation & live updating of the user's monthly financial record.
class UpdateMonthlyRecord {
  static final _supabase = Supabase.instance.client;

  static RealtimeChannel? _txListener;
  static RealtimeChannel? _fixedIncomeListener;
  static RealtimeChannel? _fixedExpenseListener;
  static Timer? _monthCheckTimer;

  /// 🚀 Starts live tracking and monthly updates
  static Future<void> start() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ UpdateMonthlyRecord.start(): No user logged in');
      return;
    }

    final profileId = await _getProfileId();
    if (profileId == null) {
      debugPrint('⚠️ No profile found for logged-in user');
      return;
    }

    // Immediate update once at startup
    await _generateMonthlyRecord(profileId);

    // Subscribe to live table updates
    _txListener = _supabase.channel('transaction_listener')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Transaction',
        callback: (_) => _generateMonthlyRecord(profileId),
      )
      ..subscribe();

    _fixedIncomeListener = _supabase.channel('fixed_income_listener')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Fixed_Income',
        callback: (_) => _generateMonthlyRecord(profileId),
      )
      ..subscribe();

    _fixedExpenseListener = _supabase.channel('fixed_expense_listener')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Fixed_Expense',
        callback: (_) => _generateMonthlyRecord(profileId),
      )
      ..subscribe();

    // Monthly auto-check → if new month starts, insert record
    _monthCheckTimer?.cancel();
    _monthCheckTimer = Timer.periodic(const Duration(hours: 12), (_) async {
      await _generateMonthlyRecord(profileId);
    });

    debugPrint('✅ UpdateMonthlyRecord live tracking started');
  }

  /// 🛑 Stops all realtime listeners
  static void stop() {
    _txListener?.unsubscribe();
    _fixedIncomeListener?.unsubscribe();
    _fixedExpenseListener?.unsubscribe();
    _monthCheckTimer?.cancel();
    debugPrint('🛑 UpdateMonthlyRecord stopped');
  }

  /// 🧩 Internal method — generate or update monthly record
  static Future<void> _generateMonthlyRecord(String profileId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(
        now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1,
        1,
      );
      final monthEnd = nextMonthStart.subtract(const Duration(days: 1));

      // 🟣 Ensure record exists
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

      // 🟣 Gather transactions (earnings/expenses)
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

      // 🟣 Fixed income
      final fi = await _supabase
          .from('Fixed_Income')
          .select('monthly_income, start_time, end_time')
          .eq('profile_id', profileId);

      double fixedIncome = 0;
      for (final i in (fi as List? ?? [])) {
        final start = i['start_time'] != null ? DateTime.parse(i['start_time']) : DateTime(1900);
        final end = i['end_time'] != null ? DateTime.parse(i['end_time']) : DateTime(9999);
        if (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
          fixedIncome += (i['monthly_income'] ?? 0).toDouble();
        }
      }

      // 🟣 Fixed expense
      final fe = await _supabase
          .from('Fixed_Expense')
          .select('amount, start_time, end_time')
          .eq('profile_id', profileId);

      double fixedExpense = 0;
      for (final e in (fe as List? ?? [])) {
        final start = e['start_time'] != null ? DateTime.parse(e['start_time']) : DateTime(1900);
        final end = e['end_time'] != null ? DateTime.parse(e['end_time']) : DateTime(9999);
        if (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
          fixedExpense += (e['amount'] ?? 0).toDouble();
        }
      }

      // 🟣 Compute totals
      final totalIncome = fixedIncome + transactionEarning;
      final totalExpense = fixedExpense + transactionExpense;
      final monthlySaving = totalIncome - totalExpense; // can be negative

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

      debugPrint('🔄 Updated monthly record: income=$totalIncome | expense=$totalExpense | saving=$monthlySaving');
    } catch (e) {
      debugPrint('❌ Error in _generateMonthlyRecord: $e');
    }
  }

  static Future<String?> _getProfileId() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _supabase
        .from('User_Profile')
        .select('profile_id')
        .eq('user_id', uid)
        .maybeSingle();
    return row?['profile_id'] as String?;
  }
}
