import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/auth_helpers.dart';
import 'update_monthly_record_service.dart';

/// ---------------------------------------------------------------------------
/// 🔹 UpdateCategorySummaryService
/// ---------------------------------------------------------------------------
/// Keeps Category_Summary table up-to-date for the logged-in user.
/// - Calculates total expenses per category each month.
/// - Aggregates from Transaction (type='Expense') + Fixed_Expense.
/// - Creates/updates Category_Summary rows linked to the active
///   Monthly_Financial_Record (record_id).
/// - Triggers MonthlyRecord recalculation after updates.
/// ---------------------------------------------------------------------------
class UpdateCategorySummaryService {
  static final _supabase = Supabase.instance.client;

  static RealtimeChannel? _transactionListener;
  static RealtimeChannel? _fixedExpenseListener;
  static Timer? _debounce;
  static String? _profileId;

  /// Start live updates when user logs in
  static Future<void> start(BuildContext context) async {
    try {
      final profileId = await getProfileId(context);
      if (profileId == null) {
        debugPrint('⚠️ No profile found — CategorySummaryService cannot start.');
        return;
      }
      _profileId = profileId;

      await _updateAll(); // Initial computation
      _setupRealtime();

      debugPrint('📊 UpdateCategorySummaryService started for $profileId');
    } catch (e) {
      debugPrint('❌ Error starting CategorySummaryService: $e');
    }
  }

  /// Stop realtime listeners
  static void stop() {
    _debounce?.cancel();
    _debounce = null;
    _transactionListener?.unsubscribe();
    _fixedExpenseListener?.unsubscribe();
    _profileId = null;
    debugPrint('🛑 UpdateCategorySummaryService stopped.');
  }

  /// Set up realtime table watchers
  static void _setupRealtime() {
    _transactionListener = _supabase.channel('public:Transaction')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Transaction',
        callback: (_) => _debouncedUpdate(),
      )
      ..subscribe();

    _fixedExpenseListener = _supabase.channel('public:Fixed_Expense')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Fixed_Expense',
        callback: (_) => _debouncedUpdate(),
      )
      ..subscribe();

    debugPrint('✅ Category summary realtime channels subscribed.');
  }

  static void _debouncedUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _updateAll);
  }

  /// Compute totals and upsert Category_Summary per category
  static Future<void> _updateAll() async {
    try {
      if (_profileId == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth =
          (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
      final monthStartStr = _ymd(monthStart);
      final nextMonthStr = _ymd(nextMonth);

      // Ensure monthly record exists
      await UpdateMonthlyRecordService.start;
      final record = await _supabase
          .from('Monthly_Financial_Record')
          .select('record_id')
          .eq('profile_id', _profileId!)
          .eq('period_start', monthStartStr)
          .maybeSingle();

      if (record == null) {
        debugPrint('⚠️ No monthly record found for current month.');
        return;
      }

      final recordId = record['record_id'] as String;

      // Get active (non-archived) categories
      final categories = await _supabase
          .from('Category')
          .select('category_id')
          .eq('profile_id', _profileId!)
          .eq('is_archived', false);

      final catIds = (categories as List).map((c) => c['category_id'] as String).toList();

      // Map totals per category
      final totals = <String, double>{};

      void add(String? cid, double amt) {
        if (cid == null || !catIds.contains(cid) || amt <= 0) return;
        totals[cid] = (totals[cid] ?? 0) + amt;
      }

      // 🧾 A) Sum from Transaction (Expense type only)
      final txs = await _supabase
          .from('Transaction')
          .select('category_id, amount, type, date')
          .eq('profile_id', _profileId!)
          .eq('type', 'Expense')
          .gte('date', monthStartStr)
          .lt('date', nextMonthStr);

      for (final t in (txs as List? ?? [])) {
        add(t['category_id'] as String?, (t['amount'] ?? 0).toDouble());
      }

      // 💰 B) Add active Fixed_Expense
      final fx = await _supabase
          .from('Fixed_Expense')
          .select('category_id, amount, start_time, end_time, due_date')
          .eq('profile_id', _profileId!);

      final monthEnd = DateTime(now.year, now.month + 1, 0);
      final lastDay = monthEnd.day;

      for (final f in (fx as List? ?? [])) {
        final cid = f['category_id'] as String?;
        final amt = (f['amount'] ?? 0).toDouble();
        final due = (f['due_date'] ?? 1).clamp(1, lastDay);
        final dueDate = DateTime(now.year, now.month, due);

        final start = f['start_time'] != null ? DateTime.parse(f['start_time']) : null;
        final end = f['end_time'] != null ? DateTime.parse(f['end_time']) : null;

        final active = (start == null || !dueDate.isBefore(start)) &&
            (end == null || !dueDate.isAfter(end));

        if (active) add(cid, amt);
      }

      // 🟣 Upsert Category_Summary
      for (final entry in totals.entries) {
        final cid = entry.key;
        final total = entry.value;

        final existing = await _supabase
            .from('Category_Summary')
            .select('summary_id')
            .eq('record_id', recordId)
            .eq('category_id', cid)
            .maybeSingle();

        if (existing != null) {
          await _supabase
              .from('Category_Summary')
              .update({'total_expense': total})
              .eq('summary_id', existing['summary_id']);
        } else {
          await _supabase.from('Category_Summary').insert({
            'record_id': recordId,
            'category_id': cid,
            'total_expense': total,
          });
        }
      }

      // 🔁 Trigger MFR recalculation
      await UpdateMonthlyRecordService.startWithoutContext(_profileId!);

      debugPrint('✅ Category_Summary updated and linked to Monthly_Record $recordId');
    } catch (e, st) {
      debugPrint('❌ Error updating Category_Summary: $e\n$st');
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
