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
        callback: (_) async {
          // small delay ensures new data is committed before recalculation
          await Future.delayed(const Duration(milliseconds: 300));
          _debouncedUpdate();
        },
      )
      ..subscribe();

    debugPrint('✅ Category summary realtime channels subscribed.');
  }

  static void _debouncedUpdate() {
    _debounce?.cancel();
    // longer debounce gives Supabase a safe commit window
    _debounce = Timer(const Duration(seconds: 1), _updateAll);
  }

  /// Compute totals and upsert Category_Summary per category
  static Future<void> _updateAll() async {
    try {
      if (_profileId == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth = (now.month == 12)
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);
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

      final catIds =
          (categories as List).map((c) => c['category_id'] as String).toList();

      // Prepare map for totals
      final totals = <String, double>{};

      void add(String? cid, double amt) {
        if (cid == null || !catIds.contains(cid)) return;
        totals[cid] = (totals[cid] ?? 0) + amt;
      }

      void subtract(String? cid, double amt) {
        if (cid == null || !catIds.contains(cid)) return;
        totals[cid] = (totals[cid] ?? 0) - amt;
      }

      // 🧾 A) Add dynamic Transaction-based expenses
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

      // 💰 B) Handle Fixed Expenses dynamically (archive-aware)
final fx = await _supabase
    .from('Fixed_Expense')
    .select('expense_id, category_id, amount, start_time, end_time, due_date')
    .eq('profile_id', _profileId!);

final lastDay = DateTime(now.year, now.month + 1, 0).day;

for (final f in (fx as List? ?? [])) {
  final cid = f['category_id'] as String?;
  final amount = (f['amount'] ?? 0).toDouble();
  final dueDay = (f['due_date'] ?? 1) as int;

  final start = f['start_time'] != null
      ? DateTime.parse(f['start_time'])
      : DateTime(1900);
  final end = f['end_time'] != null
      ? DateTime.parse(f['end_time'])
      : DateTime(9999);

  final dueDate = DateTime(now.year, now.month, dueDay.clamp(1, lastDay));

  // Skip invalid or archived ranges
  if (end.isBefore(start)) continue;

  // 🧩 Ignore records that ended today (archived same day)
  if (_isSameDay(end, now)) continue;

  // Active if current date is between start and end
  final isActive = (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
      (now.isBefore(end.add(const Duration(days: 1))) ||
          now.isAtSameMomentAs(end));

  if (!isActive) continue;

  // Only count if due date has passed this month
  final dueReached = !now.isBefore(dueDate);

  if (dueReached) {
    add(cid, amount);
  } else {
    // 🔹 If the expense was previously counted but now moved backward, remove it
    final existing = await _supabase
        .from('Category_Summary')
        .select('summary_id, total_expense')
        .eq('record_id', recordId)
        .eq('category_id', cid!)
        .maybeSingle();

    final oldTotal = (existing?['total_expense'] ?? 0).toDouble();

    if (oldTotal > 0 && oldTotal >= amount) {
      subtract(cid, amount);
      debugPrint('🔸 Removed outdated expense $amount for category $cid');
    }
  }
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

      // 🔁 Trigger main monthly record recalculation
      await UpdateMonthlyRecordService.startWithoutContext(_profileId!);

      debugPrint(
          '✅ Category_Summary updated and linked to Monthly_Record $recordId');
    } catch (e, st) {
      debugPrint('❌ Error updating Category_Summary: $e\n$st');
    }
  }

static bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
