import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/auth_helpers.dart'; // getProfileId(context)

class UpdateMonthlyRecordService {
  static final _supabase = Supabase.instance.client;

  static RealtimeChannel? _categoryListener;
  static RealtimeChannel? _transactionListener;
  static RealtimeChannel? _fixedIncomeListener;
  static RealtimeChannel? _fixedExpenseListener;
  static Timer? _monthCheckTimer;

  /// Start live updates for the logged-in user
  static Future<void> start(BuildContext context) async {
    final profileId = await getProfileId(context);
    if (profileId == null) {
      debugPrint('[MonthlyRecord]  No profile found — updater not started.');
      return;
    }

    debugPrint('[MonthlyRecord] Starting realtime service for profile $profileId');
    await _generateOrUpdateRecord(profileId);

    // Realtime listeners
    _categoryListener = _supabase
        .channel('public:Category_Summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Category_Summary',
          callback: (_) async => await _generateOrUpdateRecord(profileId),
        )
        .subscribe();

_transactionListener = _supabase
    .channel('public:Transaction')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Transaction',
      callback: (payload) async {
     
        final newRow = payload.newRecord;
        if (newRow != null && newRow['profile_id'] == profileId) {
          await Future.delayed(const Duration(milliseconds: 800));
          await _generateOrUpdateRecord(profileId);
        }
      },
    )
    .subscribe();


        
_fixedIncomeListener = _supabase
    .channel('public:Fixed_Income')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'Fixed_Income',
      callback: (_) async {
        //  small delay ensures new payday/start_time are committed
        await Future.delayed(const Duration(milliseconds: 800));
        await _generateOrUpdateRecord(profileId);
      },
    )
    .subscribe();


    _fixedExpenseListener = _supabase
        .channel('public:Fixed_Expense')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Fixed_Expense',
          callback: (_) async => await _generateOrUpdateRecord(profileId),
        )
        .subscribe();

    // Periodic check (safety net)
    _monthCheckTimer?.cancel();
    _monthCheckTimer = Timer.periodic(const Duration(hours: 12), (_) async {
      debugPrint('[MonthlyRecord]  Periodic recheck triggered');
      await _generateOrUpdateRecord(profileId);
    });

    debugPrint('[MonthlyRecord]  Live updates started');
  }

  static void stop() {
    _categoryListener?.unsubscribe();
    _transactionListener?.unsubscribe();
    _fixedIncomeListener?.unsubscribe();
    _fixedExpenseListener?.unsubscribe();
    _monthCheckTimer?.cancel();
    debugPrint('[MonthlyRecord]  Service stopped');
  }

  /// Insert or update the record for the current month
  static Future<void> _generateOrUpdateRecord(String profileId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth = (now.month == 12)
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);
      final monthEnd = nextMonth.subtract(const Duration(days: 1));

      // Ensure record exists
      final existing = await _supabase
          .from('Monthly_Financial_Record')
          .select()
          .eq('profile_id', profileId)
          .eq('period_start', monthStart.toIso8601String())
          .maybeSingle();

      String recordId;
      if (existing == null) {
        final res = await _supabase.from('Monthly_Financial_Record').insert({
          'profile_id': profileId,
          'period_start': monthStart.toIso8601String(),
          'period_end': monthEnd.toIso8601String(),
          'total_expense': 0,
          'total_income': 0,
          'total_earning': 0,
          'monthly_saving': 0,
        }).select('record_id').maybeSingle();
        recordId = res?['record_id'];
        debugPrint('[MonthlyRecord]  Created new record for $monthStart');
      } else {
        recordId = existing['record_id'];
      }

      if (recordId.isEmpty) {
        debugPrint('[MonthlyRecord]  Missing record_id — abort update.');
        return;
      }

      // ---------- EXPENSE ----------
      final catSum = await _supabase
          .from('Category_Summary')
          .select('total_expense')
          .eq('record_id', recordId);
      final totalExpense = (catSum as List? ?? [])
          .fold<double>(0, (sum, e) => sum + (e['total_expense'] ?? 0).toDouble());

        // ---------- INCOME ----------
        final fi = await _supabase
            .from('Fixed_Income')
            .select('monthly_income, payday, start_time, end_time')
            .eq('profile_id', profileId);

        double totalIncome = 0;
        final today = _dateOnly(DateTime.now());
        final lastDay = DateTime(today.year, today.month + 1, 0).day;

        for (final i in (fi as List? ?? [])) {
          final monthlyIncome = (i['monthly_income'] ?? 0).toDouble();
          final payday = (i['payday'] ?? 1) as int;
          final paydayDate = _dateOnly(DateTime(today.year, today.month, payday.clamp(1, lastDay)));

          final rawStart = i['start_time'] != null
              ? DateTime.parse(i['start_time']).toLocal()
              : DateTime(1900);
          final rawEnd = i['end_time'] != null
              ? DateTime.parse(i['end_time']).toLocal()
              : DateTime(9999);

          final start = _dateOnly(rawStart);
          final end = _dateOnly(rawEnd);

          if (end.isBefore(start)) continue;
          if (_isSameDay(end, today)) continue;

          // Active if payday within valid range
          final active = !paydayDate.isBefore(start) && !paydayDate.isAfter(end);
          if (!active) continue;

          // Count if payday reached
          if (!today.isBefore(paydayDate)) {
            totalIncome += monthlyIncome;
          }
        }



      // ---------- EARNING ----------
      final tx = await _supabase
          .from('Transaction')
          .select('amount, type, date')
          .eq('profile_id', profileId);
      double totalEarning = 0;
      for (final t in (tx as List? ?? [])) {
        final date = DateTime.tryParse(t['date'] ?? '');
        if (date == null) continue;
        if (date.year == now.year && date.month == now.month) {
          final type = (t['type'] ?? '').toString().toLowerCase();
          if (type == 'earning') {
            totalEarning += (t['amount'] ?? 0).toDouble();
          }
        }
      }

      // ---------- SAVING ----------
      final monthlySaving = totalIncome + totalEarning - totalExpense;

      // ---------- UPDATE RECORD ----------
      await _supabase.from('Monthly_Financial_Record').update({
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'total_earning': totalEarning,
        'monthly_saving': monthlySaving,
      }).eq('record_id', recordId);

      debugPrint(
          '[MonthlyRecord]  Updated → Income: $totalIncome | Earning: $totalEarning | Expense: $totalExpense | Saving: $monthlySaving');
    } catch (e, st) {
      debugPrint('[MonthlyRecord]  Error: $e\n$st');
    }
  }

  
static Future<void> startWithoutContext(String profileId) async {
  try {
    await _generateOrUpdateRecord(profileId);
  } catch (e) {
    debugPrint(' startWithoutContext failed: $e');
  }
}

static DateTime _dateOnly(DateTime d) =>
    DateTime(d.year, d.month, d.day);

static bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

}



