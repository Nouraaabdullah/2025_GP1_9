// lib/pages/goals/savings_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/auth_helpers.dart';
import 'create_goal_page.dart';
import 'edit_goal_page.dart';
import '/../widgets/child_bottom_nav_bar.dart';
import '../../dashboard/dashboard_page.dart';
import '../../profile/profile_main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum GoalType { active, completed, incompleted, achieved }

GoalType _goalTypeFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'achieved':
      return GoalType.achieved;
    case 'completed':
      return GoalType.completed;
    case 'incompleted':
    case 'incomplete':
    case 'failed':
      return GoalType.incompleted;
    default:
      return GoalType.active;
  }
}

class SavingGoal {
  final String id;
  String       title;
  double       targetAmount;
  double       savedAmount;
  DateTime?    targetDate;
  GoalType     type;

  SavingGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    required this.type,
  });

  double get progress =>
      targetAmount == 0 ? 0.0 : (savedAmount / targetAmount).clamp(0.0, 1.0);
  double get remaining =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});
  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage>
    with TickerProviderStateMixin {
  // ── Supabase ──────────────────────────────────────────────────────────────
  final _supabase = Supabase.instance.client;
  String? _childProfileId;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<SavingGoal> _goals       = [];
  double _totalSaving           = 0; // internal — used for auto-adjust logic
  double _assignedBalance       = 0; // DISPLAY: sum of past MFR monthly_saving
  double _unassignedBalance     = 0; // DISPLAY: current_balance from User_Profile
  bool   _loading               = true;

  // ── UI state ──────────────────────────────────────────────────────────────
  GoalType? _activeFilter;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatY;
  late final AnimationController _spinCtrl;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _floatY = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();

    _init();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _spinCtrl.dispose();
    _supabase.removeAllChannels();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT & REALTIME
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    _childProfileId = await getOwnChildProfileId(context);
    if (_childProfileId == null) return;
    await _generateMonthlySavings();
    await _fetchGoals();
    _recalculateBalances();
    await _autoAdjustOverAssigned();
    await _refreshCurrentSavingFromRecord();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final id = _childProfileId!;

    _supabase
        .channel('savings_txn')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Transaction',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: id),
          callback: (_) async {
            await _generateMonthlySavings();
            _recalculateBalances();
            await _autoAdjustOverAssigned();
            await _refreshCurrentSavingFromRecord();
          },
        )
        .subscribe();

    _supabase
        .channel('savings_mfr')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Monthly_Financial_Record',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: id),
          callback: (_) async {
            await _generateMonthlySavings();
            _recalculateBalances();
            await _autoAdjustOverAssigned();
            await _refreshCurrentSavingFromRecord();
          },
        )
        .subscribe();

    _supabase
        .channel('savings_transfer')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Goal_Transfer',
          callback: (_) async {
            await _fetchGoals();
            await _generateMonthlySavings();
            _recalculateBalances();
          },
        )
        .subscribe();

    _supabase
        .channel('savings_goal')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Goal',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: id),
          callback: (_) async {
            await _fetchGoals();
          },
        )
        .subscribe();

    _supabase
        .channel('savings_cat')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Category',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: id),
          callback: (_) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA FETCHING
  // ─────────────────────────────────────────────────────────────────────────

  /// CHANGE 1: _assignedBalance = sum of past MFR monthly_saving (Monthly Saved pill)
  /// CHANGE 2: _unassignedBalance = current_balance from User_Profile (Free to Use pill)
  /// _totalSaving stays as internal value for auto-adjust logic (unchanged)
  Future<void> _generateMonthlySavings() async {
    try {
      final now        = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final rows = await _supabase
          .from('Monthly_Financial_Record')
          .select('period_start, monthly_saving')
          .eq('profile_id', _childProfileId!)
          .order('period_start', ascending: true);

      double total = 0;
      for (final row in rows) {
        final ps = _parseDate(row['period_start']);
        if (ps != null && ps.isBefore(monthStart)) {
          final v = (row['monthly_saving'] as num?)?.toDouble() ?? 0;
          total += v;
        }
      }
      _totalSaving = total.clamp(0, double.infinity);

      // CHANGE 1: Monthly Saved pill = sum of past MFR monthly_saving
      final double monthlySaved = _totalSaving;

      // CHANGE 2: Free to Use pill = current_balance from User_Profile
      final profileRow = await _supabase
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', _childProfileId!)
          .maybeSingle();
      final double freeToUse =
          (profileRow?['current_balance'] as num?)?.toDouble() ?? 0;

      if (mounted) {
        setState(() {
          _assignedBalance   = monthlySaved;
          _unassignedBalance = freeToUse.clamp(0, double.infinity);
        });
      }
    } catch (e) {
      debugPrint('_generateMonthlySavings error: $e');
    }
  }

  Future<void> _refreshCurrentSavingFromRecord() async {
    try {
      final now        = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth  = DateTime(now.year, now.month + 1, 1);
      await _supabase
          .from('Monthly_Financial_Record')
          .select('monthly_saving')
          .eq('profile_id', _childProfileId!)
          .gte('period_start', monthStart.toIso8601String())
          .lt('period_end', nextMonth.toIso8601String())
          .maybeSingle();
    } catch (e) {
      debugPrint('_refreshCurrentSavingFromRecord error: $e');
    }
  }

  Future<void> _fetchGoals() async {
    try {
      final goalRows = await _supabase
          .from('Goal')
          .select()
          .eq('profile_id', _childProfileId!);

      final goalIds = goalRows.map((r) => r['goal_id'] as String).toList();

      Map<String, List<Map<String, dynamic>>> transferMap = {};
      if (goalIds.isNotEmpty) {
        final tRows = await _supabase
            .from('Goal_Transfer')
            .select('goal_id, amount, direction, created_at')
            .inFilter('goal_id', goalIds)
            .order('created_at', ascending: true);
        for (final t in tRows) {
          final gid = t['goal_id'] as String;
          transferMap.putIfAbsent(gid, () => []).add(t);
        }
      }

      final now = DateTime.now();
      final List<SavingGoal> built = [];
      for (final row in goalRows) {
        final gid      = row['goal_id'] as String;
        final tList    = transferMap[gid] ?? [];
        final saved    = _computeSaved(tList);
        final target   = (row['target_amount'] as num?)?.toDouble() ?? 0;
        final tdRaw    = row['target_date'];
        final td       = _parseDate(tdRaw);
        final dbStatus = (row['status'] as String?) ?? 'Active';
        final type     = _goalTypeFromString(dbStatus);

        built.add(SavingGoal(
          id:           gid,
          title:        (row['name'] as String?) ?? '',
          targetAmount: target,
          savedAmount:  saved,
          targetDate:   td,
          type:         type,
        ));
      }

      if (mounted) setState(() { _goals = built; _loading = false; });

      for (final g in built) {
        if (g.type != GoalType.achieved) {
          await _checkAndUpdateGoalStatus(g, now);
        }
      }
    } catch (e) {
      debugPrint('_fetchGoals error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _computeSaved(List<Map<String, dynamic>> transfers) {
    double saved = 0;
    for (final t in transfers) {
      final dir = (t['direction'] as String? ?? '').toLowerCase();
      final amt = (t['amount'] as num?)?.toDouble() ?? 0;
      if (dir == 'assign')   saved += amt;
      if (dir == 'unassign') saved -= amt;
      saved = math.max(0, saved);
    }
    return saved;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BALANCE CALCULATIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _recalculateBalances() {
    // _assignedBalance and _unassignedBalance are now set directly by
    // _generateMonthlySavings. This method is kept for auto-adjust logic.
    final activeAssigned = _goals
        .where((g) => g.type == GoalType.active ||
                      g.type == GoalType.completed ||
                      g.type == GoalType.incompleted)
        .fold(0.0, (s, g) => s + g.savedAmount);

    final achievedTotal = _goals
        .where((g) => g.type == GoalType.achieved)
        .fold(0.0, (s, g) => s + g.savedAmount);

    final effectiveTotal = math.max(0.0, _totalSaving - achievedTotal);

    // Only auto-adjust if over-assigned; display values come from DB directly.
    if (activeAssigned > effectiveTotal && effectiveTotal > 0) {
      // Will be handled by _autoAdjustOverAssigned
    }
  }

  Future<void> _autoAdjustOverAssigned() async {
    final totalAssigned = _goals
        .where((g) => g.type == GoalType.active ||
                      g.type == GoalType.completed ||
                      g.type == GoalType.incompleted)
        .fold(0.0, (s, g) => s + g.savedAmount);

    final achievedTotal = _goals
        .where((g) => g.type == GoalType.achieved)
        .fold(0.0, (s, g) => s + g.savedAmount);

    final effectiveTotal = math.max(0.0, _totalSaving - achievedTotal);

    if (totalAssigned <= effectiveTotal) return;
    final excess = totalAssigned - effectiveTotal;

    final active = _goals
        .where((g) => g.type == GoalType.active ||
                      g.type == GoalType.completed ||
                      g.type == GoalType.incompleted)
        .toList();

    for (final g in active) {
      if (totalAssigned == 0) break;
      final deduct = (g.savedAmount / totalAssigned) * excess;
      if (deduct <= 0) continue;
      final newAmt = math.max(0.0, g.savedAmount - deduct);
      try {
        await _supabase.from('Goal_Transfer').insert({
          'goal_id':    g.id,
          'amount':     deduct,
          'direction':  'Unassign',
          'created_at': DateTime.now().toIso8601String(),
        });
        g.savedAmount = newAmt;
      } catch (e) {
        debugPrint('_autoAdjustOverAssigned error: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  bool _isExpired(DateTime? targetDate) {
    if (targetDate == null) return false;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return today.isAfter(d);
  }

  String _computeNewStatus(SavingGoal g) {
    if (g.savedAmount >= g.targetAmount && g.targetAmount > 0) {
      return 'Completed';
    }
    if (_isExpired(g.targetDate)) return 'Incompleted';
    return 'Active';
  }

  Future<void> _checkAndUpdateGoalStatus(SavingGoal g, DateTime now) async {
    final current   = _goalTypeToString(g.type);
    final newStatus = _computeNewStatus(g);
    if (newStatus == current) return;

    try {
      await _supabase
          .from('Goal')
          .update({'status': newStatus})
          .eq('goal_id', g.id);
      if (mounted && newStatus == 'Completed') {
        _showStatusDialog(g, newStatus);
      }
    } catch (e) {
      debugPrint('_checkAndUpdateGoalStatus error: $e');
    }
  }

  String _goalTypeToString(GoalType t) {
    switch (t) {
      case GoalType.achieved:    return 'Achieved';
      case GoalType.completed:   return 'Completed';
      case GoalType.incompleted: return 'Incompleted';
      case GoalType.active:      return 'Active';
    }
  }

  void _showStatusDialog(SavingGoal g, String newStatus) {
    final icon  = newStatus == 'Completed' ? '🏁' : '⏰';
    final title = newStatus == 'Completed' ? 'Goal Reached!' : 'Goal Missed';
    final msg   = newStatus == 'Completed'
        ? '"${g.title}" is fully saved and ready to buy!'
        : '"${g.title}" passed its deadline without reaching the target.';

    showDialog(
      context:            context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: AppColors.kText)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: AppColors.kTextSoft, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPurple, elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12)),
              child: const Text('Got it',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ASSIGN / UNASSIGN
  // ─────────────────────────────────────────────────────────────────────────

  void _openAssignSheet(SavingGoal goal) {
    if (_unassignedBalance <= 0) {
      _showInfoDialog('Nothing to Assign',
          'There is no unassigned balance available. '
          'Wait for more savings or unassign from another goal.', '💰');
      return;
    }
    if (goal.remaining <= 0) {
      _showInfoDialog('Goal Complete',
          'This goal is already fully saved!', '🏁');
      return;
    }

    bool   adding = true;
    double amount = 0;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, s) {
        final maxAdd    = math.min(_unassignedBalance, goal.remaining)
            .clamp(0.0, double.infinity);
        final maxRemove = goal.savedAmount;
        final max       = adding ? maxAdd : maxRemove;
        if (amount > max) amount = max;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(36))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.kPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.kPurple.withOpacity(0.2))),
                child: Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(goal.title,
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.kText)),
                    Text('${_fmtSar(goal.savedAmount)} / '
                        '${_fmtSar(goal.targetAmount)} SAR',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.kPurple,
                            fontWeight: FontWeight.w700)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: AppColors.kPurple.withOpacity(0.15),
                            blurRadius: 8)]),
                    child: Column(children: [
                      const Text('Free',
                          style: TextStyle(fontSize: 10,
                              color: Color(0xFFAAAAAA))),
                      Text(_fmtSar(_unassignedBalance),
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.kPurple)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _toggleBtn(
                    '➕  Assign', adding, AppColors.kPurple,
                    () => s(() { adding = true; amount = 0; }))),
                const SizedBox(width: 10),
                Expanded(child: _toggleBtn(
                    '➖  Unassign', !adding, AppColors.kPink,
                    () => s(() { adding = false; amount = 0; }))),
              ]),
              const SizedBox(height: 16),
              Text('${amount.toStringAsFixed(0)} SAR',
                  style: TextStyle(fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: adding ? AppColors.kPurple : AppColors.kPink)),
              Text(max <= 0
                  ? 'Nothing to ${adding ? "assign" : "unassign"}'
                  : 'Max  ${_fmtSar(max)} SAR',
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFFBBBBBB))),
              const SizedBox(height: 8),
              if (max > 0) ...[
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 10,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 14),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 24),
                    activeTrackColor:
                        adding ? AppColors.kPurple : AppColors.kPink,
                    inactiveTrackColor: Colors.grey.shade100,
                    thumbColor:
                        adding ? AppColors.kPurple : AppColors.kPink,
                  ),
                  child: Slider(
                    value: amount, min: 0, max: max,
                    onChanged: (v) => s(() => amount = v.roundToDouble()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [25, 50, 75, 100].map((p) {
                    final v  = (max * p / 100).roundToDouble();
                    final ia = amount == v;
                    final c  = adding ? AppColors.kPurple : AppColors.kPink;
                    return GestureDetector(
                      onTap: () => s(() => amount = v),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                            color: ia ? c : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(17)),
                        child: Text(p == 100 ? 'Max' : '$p%',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ia
                                    ? Colors.white
                                    : Colors.grey.shade500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: amount <= 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _submitTransfer(
                              goal, amount, adding ? 'Assign' : 'Unassign');
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          adding ? AppColors.kPurple : AppColors.kPink,
                      disabledBackgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0),
                  child: Text(
                    adding
                        ? 'Assign ${amount.toStringAsFixed(0)} SAR ✅'
                        : 'Unassign ${amount.toStringAsFixed(0)} SAR',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _submitTransfer(
      SavingGoal goal, double amount, String direction) async {
    try {
      await _supabase.from('Goal_Transfer').insert({
        'goal_id':    goal.id,
        'amount':     amount,
        'direction':  direction,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _fetchGoals();
      await _generateMonthlySavings();
      _recalculateBalances();
      await _checkAndUpdateGoalStatus(
          _goals.firstWhere((g) => g.id == goal.id),
          DateTime.now());
    } catch (e) {
      debugPrint('_submitTransfer error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transfer failed: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOG GOAL AS EXPENSE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _logExpense(SavingGoal goal) async {
    List<Map<String, dynamic>> categories = [];
    try {
      categories = List<Map<String, dynamic>>.from(
          await _supabase
              .from('Category')
              .select('category_id, name, type, monthly_limit')
              .eq('profile_id', _childProfileId!)
              .eq('is_archived', false)
              .order('name', ascending: true));
    } catch (e) {
      debugPrint('fetch categories error: $e');
    }

    if (!mounted) return;

    String? selectedCatId;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, s) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛍️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            const Text('Log as Expense',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.kText)),
            const SizedBox(height: 6),
            Text('${goal.title} — ${_fmtSar(goal.targetAmount)} SAR',
                style: const TextStyle(fontSize: 13,
                    color: AppColors.kTextSoft)),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              const Text('No categories found.',
                  style: TextStyle(color: AppColors.kTextSoft))
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final cat   = categories[i];
                    final catId = cat['category_id'] as String;
                    final sel   = selectedCatId == catId;
                    return GestureDetector(
                      onTap: () => s(() => selectedCatId = catId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.kPurple.withOpacity(0.1)
                              : const Color(0xFFF8F8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel
                                  ? AppColors.kPurple
                                  : Colors.transparent,
                              width: 1.5),
                        ),
                        child: Row(children: [
                          Expanded(child: Text(
                              cat['name'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel
                                      ? AppColors.kPurple
                                      : AppColors.kText))),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.kPurple, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFEEEEEE)))),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFFAAAAAA),
                        fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: selectedCatId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _confirmLogExpense(goal, selectedCatId!);
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kGreen,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Confirm 🛒',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800)),
              )),
            ]),
          ]),
        ),
      )),
    );
  }

  Future<void> _confirmLogExpense(
      SavingGoal goal, String categoryId) async {
    try {
      final now        = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonth  = DateTime(now.year, now.month + 1, 1);

      final catRow = await _supabase
          .from('Category')
          .select('monthly_limit')
          .eq('category_id', categoryId)
          .maybeSingle();
      final limit = (catRow?['monthly_limit'] as num?)?.toDouble();

      if (limit != null) {
        final summaryRows = await _supabase
            .from('Category_Summary')
            .select('total_expense, record_id')
            .eq('category_id', categoryId);

        double currentExpense = 0;
        for (final sr in summaryRows) {
          final recId  = sr['record_id'];
          final mfrRow = await _supabase
              .from('Monthly_Financial_Record')
              .select('period_start, period_end')
              .eq('record_id', recId)
              .maybeSingle();
          if (mfrRow != null) {
            final ps = _parseDate(mfrRow['period_start']);
            final pe = _parseDate(mfrRow['period_end']);
            if (ps != null && pe != null &&
                !ps.isBefore(monthStart) &&
                ps.isBefore(nextMonth)) {
              currentExpense +=
                  (sr['total_expense'] as num?)?.toDouble() ?? 0;
            }
          }
        }

        if (currentExpense + goal.targetAmount > limit) {
          if (!mounted) return;
          // Show warning with Cancel / Continue options
          final proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28)),
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚠️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Over Category Limit',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.kText)),
                  const SizedBox(height: 10),
                  Text(
                    'Adding ${_fmtSar(goal.targetAmount)} SAR exceeds '
                    'the monthly limit of ${_fmtSar(limit)} SAR for this category.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.kTextSoft, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                  color: Color(0xFFEEEEEE)))),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFFAAAAAA),
                              fontWeight: FontWeight.w700)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPurple,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text('Continue',
                          style: TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w800)),
                    )),
                  ]),
                ]),
              ),
            ),
          );
          if (proceed != true) return;
        }
      }

      final profileRow = await _supabase
          .from('User_Profile')
          .select('current_balance')
          .eq('profile_id', _childProfileId!)
          .maybeSingle();
      final currentBalance =
          (profileRow?['current_balance'] as num?)?.toDouble() ?? 0;
      final newBalance = currentBalance - goal.targetAmount;

      await _supabase.from('Transaction').insert({
        'profile_id':  _childProfileId,
        'category_id': categoryId,
        'amount':      goal.targetAmount,
        'type':        'Expense',
        'date':        DateTime.now().toIso8601String(),
      });

      await _supabase
          .from('User_Profile')
          .update({'current_balance': newBalance})
          .eq('profile_id', _childProfileId!);

      await _supabase
          .from('Goal')
          .update({'status': 'Achieved'})
          .eq('goal_id', goal.id);

      await _fetchGoals();
      await _generateMonthlySavings();
      _recalculateBalances();

      if (mounted) setState(() => _activeFilter = GoalType.achieved);
      if (mounted) _showTrophyDialog(goal);
    } catch (e) {
      debugPrint('_confirmLogExpense error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging expense: $e')));
      }
    }
  }

  void _showTrophyDialog(SavingGoal g) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏆', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text('Goal Achieved!',
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.kText)),
            const SizedBox(height: 8),
            Text('"${g.title}" has been logged as an expense.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: AppColors.kTextSoft, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                  color: AppColors.kYellowSoft,
                  borderRadius: BorderRadius.circular(14)),
              child: Text('🎉  ${_fmtSar(g.targetAmount)} SAR spent',
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.kYellow)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kYellow,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12)),
              child: const Text('Woohoo! 🎊',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _openCreatePage() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateGoalPage()));
    await _fetchGoals();
    _recalculateBalances();
    await _autoAdjustOverAssigned();
    await _refreshCurrentSavingFromRecord();
  }

  void _openEditPage(SavingGoal g) async {
    await Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => EditGoalPage(
              id:                  g.id,
              initialTitle:        g.title,
              initialTargetAmount: g.targetAmount,
              initialTargetDate:   g.targetDate,
              initialStatus:       _goalTypeToString(g.type),
            )));
    await _fetchGoals();
    _recalculateBalances();
    await _autoAdjustOverAssigned();
    await _refreshCurrentSavingFromRecord();
  }

  Future<void> _rescheduleGoal(SavingGoal g) async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: (g.targetDate?.isAfter(DateTime.now()) ?? false)
          ? g.targetDate!
          : DateTime.now().add(const Duration(days: 30)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary:   AppColors.kPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.kText),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    try {
      await _supabase
          .from('Goal')
          .update({'target_date': picked.toIso8601String(),
                   'status':      'Active'})
          .eq('goal_id', g.id);
      await _fetchGoals();
    } catch (e) {
      debugPrint('_rescheduleGoal error: $e');
    }
  }

  Future<void> _deleteGoal(SavingGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text('Delete "${goal.title}"?',
            style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.kText)),
        content: const Text(
            'Budget assigned to this goal will be freed up.',
            style: TextStyle(color: Color(0xFF888888), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPink,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabase
          .from('Goal')
          .delete()
          .eq('goal_id', goal.id);
      await _fetchGoals();
      _recalculateBalances();
    } catch (e) {
      debugPrint('_deleteGoal error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    try { return DateTime.parse(raw.toString()); } catch (_) { return null; }
  }

  String _fmtSar(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _showInfoDialog(String title, String msg, String emoji) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.kText)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13,
                    color: AppColors.kTextSoft, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPurple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 11)),
              child: const Text('OK',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  List<SavingGoal> get _filtered => _activeFilter == null
      ? _goals
      : _goals.where((g) => g.type == _activeFilter).toList();

  static const _statusCfg = [
    (type: null,                 label: '✨ All',     color: AppColors.kPurple),
    (type: GoalType.active,      label: '⚡ Active',  color: AppColors.kBlue),
    (type: GoalType.completed,   label: '🏁 Done',    color: AppColors.kGreen),
    (type: GoalType.incompleted, label: '⏰ Missed',  color: AppColors.kPink),
    (type: GoalType.achieved,    label: '🏆 Got it!', color: AppColors.kYellow),
  ];

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF0EBFF), // matches bar painter colour
      extendBody: true,
      bottomNavigationBar: ChildBottomBar(
        selectedIndex:  1, // Savings tab
        onTapSavings:   () {},
        onTapDashboard: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        ),
        onTapProfile: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileMainPage()),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.kidBg),
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    SizedBox(
                        height: screenH * 0.28,
                        child: _buildHeroSection()),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        child: _buildGoalsCard(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle),
              child: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.kText, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          const Text('🐷', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('My Savings',
                style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.kText)),
          ),
        ]),
      );

  Widget _buildHeroSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_floatCtrl, _spinCtrl]),
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _floatY.value),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(2 * math.pi * _spinCtrl.value),
                child: Image.asset('assets/images/coin.png',
                    width: 165, height: 165, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(children: [
            Expanded(child: _statPill(
              emoji:    '🪙',
              label:    'Monthly Saved',
              value:    _fmtSar(_assignedBalance),
              color:    AppColors.kPurpleDark,
              barValue: _assignedBalance > 0 ? 1.0 : 0.0,
              barColor: AppColors.kPurple,
            )),
            const SizedBox(width: 10),
            Expanded(child: _statPill(
              emoji:    '✨',
              label:    'Free to Use',
              value:    _fmtSar(_unassignedBalance),
              color:    AppColors.kBlue,
              barValue: 1.0,
              barColor: AppColors.kBlue,
            )),
          ]),
        ),
      ],
    );
  }

  Widget _statPill({
    required String emoji,
    required String label,
    required String value,
    required Color  color,
    required double barValue,
    required Color  barColor,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withOpacity(0.7), width: 1.2),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kText.withOpacity(0.5))),
              const SizedBox(height: 2),
              RichText(text: TextSpan(children: [
                TextSpan(text: value,
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color, height: 1.1)),
                const TextSpan(text: ' SAR',
                    style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextSoft)),
              ])),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:           barValue,
                  minHeight:       3,
                  backgroundColor: barColor.withOpacity(0.12),
                  valueColor:      AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ]),
          ),
        ]),
      );

  Widget _buildGoalsCard() {
    final filtered = _filtered;
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(
            color:      AppColors.kPurple.withOpacity(0.13),
            blurRadius: 28, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
          child: Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 19)),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('My Goals',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.kText))),
            GestureDetector(
              onTap: _openCreatePage,
              child: Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(
                    color: AppColors.kPurple, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _statusCfg.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cfg      = _statusCfg[i];
                final isActive = _activeFilter == cfg.type;
                final count    = cfg.type == null
                    ? _goals.length
                    : _goals.where((g) => g.type == cfg.type).length;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = cfg.type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isActive ? cfg.color : const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isActive
                          ? [BoxShadow(color: cfg.color.withOpacity(0.35),
                              blurRadius: 6, offset: const Offset(0, 2))]
                          : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(cfg.label.split(' ')[0],
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(cfg.label.split(' ').skip(1).join(' '),
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isActive ? Colors.white : AppColors.kTextSoft)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.9)
                              : cfg.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$count',
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isActive ? cfg.color : cfg.color)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
          child: Text('${filtered.length} goals',
              style: const TextStyle(fontSize: 11,
                  color: AppColors.kTextSoft, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _goalTile(filtered[i]),
                ),
        ),
      ]),
    );
  }

  Widget _emptyState() => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🎯', style: TextStyle(fontSize: 36)),
            SizedBox(height: 6),
            Text('No goals here!',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w900, color: AppColors.kText)),
            SizedBox(height: 2),
            Text('Tap + to add one 🚀',
                style: TextStyle(fontSize: 11, color: AppColors.kTextSoft)),
          ]),
        ),
      );

  Widget _goalTile(SavingGoal goal) {
    final type     = goal.type;
    final daysLeft = goal.targetDate != null
        ? goal.targetDate!.difference(DateTime.now()).inDays
        : 0;

    final Color  sColor;
    final String sText;
    switch (type) {
      case GoalType.active:
        sColor = AppColors.kBlue;  sText = '$daysLeft d left'; break;
      case GoalType.completed:
        sColor = AppColors.kGreen; sText = '🏁 Ready!';        break;
      case GoalType.incompleted:
        sColor = AppColors.kPink;  sText = '⏰ Missed';         break;
      case GoalType.achieved:
        sColor = AppColors.kYellow; sText = '🏆 Got it!';       break;
    }

    final barColor = type == GoalType.incompleted ? AppColors.kPink
        : type == GoalType.achieved ? AppColors.kYellow
        : sColor;

    return SizedBox(
      height: 72,
      child: Container(
        decoration: BoxDecoration(
          color:        sColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sColor.withOpacity(0.15), width: 1.5),
        ),
        padding: const EdgeInsets.only(left: 10, right: 2),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color:        sColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(
                goal.title.isNotEmpty ? goal.title[0].toUpperCase() : '🎯',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900, color: sColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(goal.title, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.kText)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: sColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(sText,
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w800, color: sColor)),
                  ),
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value:           goal.progress,
                        minHeight:       5,
                        backgroundColor: sColor.withOpacity(0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${(goal.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: sColor)),
                ]),
              ],
            ),
          ),
          if (type == GoalType.achieved)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: AppColors.kYellowSoft,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.verified_rounded,
                    color: AppColors.kYellow, size: 18),
              ),
            )
          else
            PopupMenuButton<String>(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.kTextSoft.withOpacity(0.6), size: 20),
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) async {
                if (v == 'assign')     _openAssignSheet(goal);
                if (v == 'buy')       _logExpense(goal);
                if (v == 'edit')      _openEditPage(goal);
                if (v == 'delete')    _deleteGoal(goal);
                if (v == 'reschedule') _rescheduleGoal(goal);
              },
              itemBuilder: (_) {
                final items = <PopupMenuEntry<String>>[];
                if (type == GoalType.active) {
                  items.add(_menuItem('assign', Icons.savings_rounded,
                      AppColors.kPurple, AppColors.kPurpleSoft, 'Assign money'));
                } else if (type == GoalType.completed) {
                  items.add(_menuItem('buy', Icons.shopping_bag_rounded,
                      AppColors.kGreen, AppColors.kGreenSoft, 'Mark as bought'));
                } else if (type == GoalType.incompleted) {
                  items.add(_menuItem('reschedule', Icons.calendar_month_rounded,
                      AppColors.kPink, AppColors.kPinkSoft, 'New deadline'));
                }
                items.add(const PopupMenuDivider(height: 1));
                items.add(_menuItem('edit', Icons.edit_rounded,
                    AppColors.kBlue, AppColors.kBlueSoft, 'Edit goal'));
                items.add(const PopupMenuDivider(height: 1));
                items.add(_menuItem('delete', Icons.delete_outline_rounded,
                    AppColors.kPink, AppColors.kPinkSoft, 'Delete'));
                return items;
              },
            ),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon,
          Color iconColor, Color bgColor, String label) =>
      PopupMenuItem<String>(
        value: value,
        height: 42,
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: value == 'delete' ? AppColors.kPink : AppColors.kText)),
        ]),
      );

  Widget _toggleBtn(String label, bool active,
          Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: active
                ? [BoxShadow(color: color.withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : Colors.grey.shade400))),
        ),
      );
}