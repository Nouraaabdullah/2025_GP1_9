import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_goal_page.dart';
import 'edit_goal_page.dart';
import 'dart:math'; 
import '../../utils/auth_helpers.dart'; 




/// ---------------- Domain ----------------
enum GoalType { active, completed, uncompleted, achieved }
class Goal {
  final String id;
  final String title;
  final GoalType type;
  final double targetAmount;
  final DateTime createdAt;
  final double savedAmount;
  final DateTime? targetDate;
  final String? status;

  const Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.targetAmount,
    required this.createdAt,
    this.savedAmount = 0.0,
    this.targetDate,
    this.status,
  });
  double get remaining =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);
  double get progress =>
      targetAmount == 0 ? 0.0 : (savedAmount / targetAmount).clamp(0.0, 1.0);
  Goal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    GoalType? type,
    DateTime? createdAt,
    DateTime? targetDate,
    String? status,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
    );
  }
}

/// ---------------- Page ----------------
class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});
  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final supabase = Supabase.instance.client;
  GoalType _selected = GoalType.active;
  final Map<String, double> _monthlySavings = {};
  double _unassignedBalance = 0;
  double _totalSaving = 0.0;
  final List<Goal> _goals = [];
  double _assignedBalanceCached = 0.0;   // stores adjusted value
  double get _assignedBalance => _assignedBalanceCached;
  


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
    _setupRealtimeListeners();
  }

  Future<void> _initData() async {
    await _generateMonthlySavings();
    await _fetchGoals();
  }

  void _setupRealtimeListeners() {
    final supabase = Supabase.instance.client;
    supabase
        .channel('public:Transaction')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Transaction',
          callback: (payload) async {
            debugPrint('Transaction updated: ${payload.eventType}');
            await _generateMonthlySavings();
          },
        )
        .subscribe();
    supabase
        .channel('public:Fixed_Income')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Fixed_Income',
          callback: (payload) async {
            debugPrint('Fixed_Income updated: ${payload.eventType}');
            await _generateMonthlySavings();
          },
        )
        .subscribe();
    supabase
        .channel('public:Fixed_Expense')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Fixed_Expense',
          callback: (payload) async {
            debugPrint('Fixed_Expense updated: ${payload.eventType}');
            await _generateMonthlySavings();
          },
        )
        .subscribe();
    supabase
        .channel('public:Monthly_Financial_Record')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Monthly_Financial_Record',
          callback: (payload) async {
            debugPrint('MFR updated: ${payload.eventType}');
            await _generateMonthlySavings();
          },
        )
        .subscribe();
    supabase
        .channel('public:Goal_Transfer')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Goal_Transfer',
          callback: (payload) async {
            debugPrint('Goal_Transfer updated: ${payload.eventType}');
            await _fetchGoals();
            await _generateMonthlySavings();
          },
        )
        .subscribe();
    supabase
        .channel('public:Goal')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Goal',
          callback: (payload) async {
            debugPrint('Goal table changed: ${payload.eventType}');
            await _fetchGoals();
            await _markExpiredGoalsAsUncompleted();
          },
        )
        .subscribe();

        supabase
      .channel('public:Category')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Category',
        callback: (payload) async {
          debugPrint('🟣 Category table changed: ${payload.eventType}');
          // refresh category list dynamically if dialog is open
          if (mounted) setState(() {});
        },
      )
      .subscribe();

  }

 Future<void> _logCompletedGoalExpense(Goal goal) async {
  try {
    final profileId = await getProfileId(context);
  if (profileId == null) return; // not logged in

    final supabase = Supabase.instance.client;
    final amount = goal.targetAmount;

    // Step 1️⃣ — Check available balance
    final user = await supabase
        .from('User_Profile')
        .select('current_balance')
        .eq('profile_id', profileId)
        .maybeSingle();

    final double currentBalance = (user?['current_balance'] ?? 0).toDouble();
    if (currentBalance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance to log this goal as an expense.')),
      );
      return;
    }

    // Step 2️⃣ — Fetch user-specific, active categories (fixed + custom)
    final categories = await supabase
        .from('Category')
        .select('category_id, name, type')
        .eq('profile_id', profileId)
        .eq('is_archived', false)
        .order('name', ascending: true);

    if (categories == null || categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active categories available for this user.')),
      );
      return;
    }


    String? selectedCategory;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Confirm Goal Expense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You’re about to log "${goal.title}" as an expense of ${amount.toStringAsFixed(2)} SAR.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: AppColors.card,
              decoration: InputDecoration(
                labelText: 'Select Category',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c['category_id'],
                    child: Text(c['name'], style: const TextStyle(color: Colors.white)),
                  ),
              ],
              onChanged: (v) => selectedCategory = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              if (selectedCategory != null) Navigator.pop(ctx, true);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );

    if (confirm != true || selectedCategory == null) return;

    // Step 3️⃣ — Start safe DB sequence
    try {
      // 1. Insert expense transaction
      await supabase.from('Transaction').insert({
        'profile_id': profileId,
        'category_id': selectedCategory,
        'amount': amount,
        'type': 'Expense',
        'date': DateTime.now().toIso8601String(),
      });

      // 2. Deduct from balance
      final newBalance = (currentBalance - amount).clamp(0, double.infinity);
      await supabase
          .from('User_Profile')
          .update({'current_balance': newBalance})
          .eq('profile_id', profileId);

  // 3️⃣ Keep assigned amount as historical
  // Optionally, add a special marker in the goal for clarity
  await supabase
      .from('Goal')
      .update({'status': 'Achieved'})
      .eq('goal_id', goal.id);


      // 4. Mark goal as achieved
      await supabase
          .from('Goal')
          .update({'status': 'Achieved'})
          .eq('goal_id', goal.id);

      // 5. Update total saving and assigned balance
      await _generateMonthlySavings(); // updates _totalSaving from DB
      await _fetchGoals();              // refreshes goal list
      _recalculateBalances();           // recompute assigned/unassigned

      // 6. Show success & move to achieved tab
      setState(() => _selected = GoalType.achieved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal "${goal.title}" logged successfully as expense!')),
      );
    } catch (dbError) {
      // Rollback if failed
      await supabase
          .from('User_Profile')
          .update({'current_balance': currentBalance})
          .eq('profile_id', profileId);
      debugPrint('❌ Rolled back due to: $dbError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging expense: $dbError')),
      );
    }
  } catch (e) {
    debugPrint('❌ Unexpected error logging goal as expense: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error logging expense: $e')),
    );
  }
}


  Future<void> _markExpiredGoalsAsUncompleted() async {
    try {
      final now = DateTime.now(); // 02:00 AM +03, October 21, 2025
      for (final goal in _goals) {
        if (goal.type == GoalType.active && goal.targetDate != null) {
          if (now.isAfter(goal.targetDate!)) {
            await supabase
                .from('Goal')
                .update({'status': 'Uncompleted'})
                .eq('goal_id', goal.id);
            debugPrint('⚠️ Goal "${goal.title}" marked as Uncompleted');
          }
        }
      }
      await _fetchGoals();
    } catch (e) {
      debugPrint('❌ Error marking expired goals: $e');
    }
  }

Future<void> _fetchGoals() async {
  try {
    final profileId = await getProfileId(context);
    if (profileId == null) return; // not logged in

    final response = await supabase
        .from('Goal')
        .select()
        .eq('profile_id', profileId);

    if (response == null || response.isEmpty) {
      debugPrint('No goals found.');
      setState(() => _goals.clear());
      return;
    }

    final data = response as List;

    // 🕒 Give time for last insert (important after Unassign)
    await Future.delayed(const Duration(milliseconds: 250));

    final transferResponse = await supabase
        .from('Goal_Transfer')
        .select('goal_id, amount, direction, created_at')
        .inFilter(
          'goal_id',
          data.map((g) => g['goal_id']).whereType<String>().toList(),
        )
        // ✅ process oldest → newest
        .order('created_at', ascending: true);

    final Map<String, double> goalSaved = {};
    final Map<String, DateTime?> latestAssignDate = {};

    for (final t in transferResponse) {
      final id = t['goal_id'];
      final amt = (t['amount'] ?? 0).toDouble();
      final dir = (t['direction'] ?? '').toString().toLowerCase();
      final createdAt =
          t['created_at'] != null ? DateTime.parse(t['created_at']) : null;

      if (dir == 'assign') {
        goalSaved[id] = (goalSaved[id] ?? 0) + amt;
        if (createdAt != null) {
          if (latestAssignDate[id] == null ||
              createdAt.isAfter(latestAssignDate[id]!)) {
            latestAssignDate[id] = createdAt;
          }
        }
      } else if (dir == 'unassign') {
        goalSaved[id] = (goalSaved[id] ?? 0) - amt;
      }

      goalSaved[id] = max(0, goalSaved[id]!);
    }

    final fetchedGoals = data.map((g) {
      final id = g['goal_id'] ?? '';
      final saved = goalSaved[id] ?? 0.0;
      return Goal(
        id: id,
        title: g['name'] ?? '',
        targetAmount: (g['target_amount'] ?? 0).toDouble(),
        savedAmount: saved,
        createdAt: DateTime.parse(g['created_at']),
        targetDate: latestAssignDate[g['goal_id']] ??
            (g['target_date'] != null
                ? DateTime.parse(g['target_date'])
                : null),
        type: _statusToType(g['status']),
        status: g['status'],
      );
    }).toList();

    setState(() {
      _goals
        ..clear()
        ..addAll(fetchedGoals);
    });

    // ✅ recalc after short pause to allow state to sync
    await Future.delayed(const Duration(milliseconds: 100));
    _recalculateBalances();

    await _markExpiredGoalsAsUncompleted();
    debugPrint('✅ Goals fetched successfully: ${_goals.length}');
  } catch (e) {
    debugPrint('Error fetching goals: $e');
  }
}


  Future<void> _checkAndUpdateGoalStatus(String goalId) async {
    try {
      final transfers = await supabase
          .from('Goal_Transfer')
          .select('amount, direction')
          .eq('goal_id', goalId);
      double totalAssigned = 0.0;
      for (final t in (transfers as List? ?? [])) {
        final amt = (t['amount'] ?? 0).toDouble();
        final dir = (t['direction'] ?? '').toString().toLowerCase();
        if (dir == 'assign') totalAssigned += amt;
        if (dir == 'unassign') totalAssigned -= amt;
      }
      totalAssigned = max(0, totalAssigned);
      final goal = await supabase
          .from('Goal')
          .select('target_amount')
          .eq('goal_id', goalId)
          .single();
      final target = (goal['target_amount'] ?? 0).toDouble();
      final newStatus = totalAssigned >= target ? 'Completed' : 'Active';
      await supabase
          .from('Goal')
          .update({'status': newStatus})
          .eq('goal_id', goalId);
      debugPrint('Goal $goalId status updated to $newStatus');
      await _fetchGoals();
    } catch (e) {
      debugPrint('Error updating goal status: $e');
    }
  }

  Future<Goal?> _fetchGoalById(String goalId) async {
    try {
      final res = await supabase
          .from('Goal')
          .select()
          .eq('goal_id', goalId)
          .single();
      if (res == null) return null;
      return Goal(
        id: res['goal_id'],
        title: res['name'] ?? '',
        targetAmount: (res['target_amount'] ?? 0).toDouble(),
        savedAmount: (res['saved_amount'] ?? 0).toDouble(),
        createdAt: DateTime.parse(res['created_at']),
        targetDate: res['target_date'] != null ? DateTime.parse(res['target_date']) : null,
        type: _statusToType(res['status']),
        status: res['status'],
      );
    } catch (e) {
      debugPrint('❌ Error fetching goal by ID: $e');
      return null;
    }
  }
Future<void> _autoAdjustOverAssignedGoals() async {
  try {
    // 🧮 Get total assigned amount across all goals
    final transfers = await supabase.from('Goal_Transfer').select('amount, direction');

    double totalAssigned = 0;
    for (final t in (transfers as List? ?? [])) {
      final amount = (t['amount'] ?? 0).toDouble();
      final dir = (t['direction'] ?? '').toLowerCase();
      if (dir == 'assign') totalAssigned += amount;
      if (dir == 'unassign') totalAssigned -= amount;
    }

    if (totalAssigned <= _totalSaving) return;

    final difference = totalAssigned - _totalSaving;
    debugPrint('⚠️ Assigned exceeds total by $difference SAR. Adjusting goals...');

    final goals = await supabase
        .from('Goal')
        .select('goal_id, name, status, target_amount')
        .inFilter('status', ['Active', 'Completed']);

    if (goals == null || (goals as List).isEmpty) {
      debugPrint('No goals to adjust.');
      return;
    }

    final goalList = goals as List;
    final count = goalList.length;
    final double deductPerGoal = difference / count;

    for (final goal in goalList) {
      final id = goal['goal_id'];
      final name = goal['name'];
      final target = (goal['target_amount'] ?? 0).toDouble();
      final newTarget = (target - deductPerGoal).clamp(0, double.infinity);

      await supabase.from('Goal').update({
        'target_amount': newTarget,
        if (newTarget > 0) 'status': 'Active',
      }).eq('goal_id', id);

      debugPrint('🔻 Deducted $deductPerGoal from "$name" (new target: $newTarget)');
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _recalculateBalances();
    setState(() {});
  } catch (e) {
    debugPrint('❌ Error in _autoAdjustOverAssignedGoals: $e');
  }
}

void _recalculateBalances() {
  // 1️⃣ Compute total assigned from all goals (Active + Achieved)
  final rawAssigned = _goals.fold(0.0, (sum, g) => sum + g.savedAmount);

  // 2️⃣ Make sure total saving is never negative
  _totalSaving = _totalSaving.clamp(0.0, double.infinity);

  // 3️⃣ If total < assigned, cap assigned to total
  // (so that it never exceeds available savings)
  final effectiveAssigned = min(rawAssigned, _totalSaving);

  // 4️⃣ Unassigned = whatever remains, never negative
  final unassigned = (_totalSaving - effectiveAssigned).clamp(0.0, double.infinity);

  // 5️⃣ Update state (cache adjusted assigned + set unassigned)
  setState(() {
    _assignedBalanceCached = effectiveAssigned;
    _unassignedBalance = unassigned;
  });

  // 6️⃣ Optional debug check
  debugPrint(
    '🧮 Balances recalculated → '
    'Total: $_totalSaving | Assigned: $_assignedBalanceCached | '
    'Unassigned: $_unassignedBalance | '
    'Sum: ${_assignedBalanceCached + _unassignedBalance}',
  );
}



Future<void> _generateMonthlySavings() async {
  try {
    final profileId = await getProfileId(context);
    if (profileId == null) return; // not logged in

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 🧾 Fetch all past monthly records (previous months only)
    final monthlyRecords = await supabase
        .from('Monthly_Financial_Record')
        .select('period_start, monthly_saving')
        .eq('profile_id', profileId)
        .order('period_start', ascending: true);

    double totalSaving = 0;
    final Map<String, double> monthMap = {};

    for (final record in (monthlyRecords as List? ?? [])) {
      final start = DateTime.parse(record['period_start']);
      final label = '${start.year}-${start.month.toString().padLeft(2, '0')}';
      final saving = (record['monthly_saving'] ?? 0).toDouble();
      monthMap[label] = saving;

      // ✅ Only include months before current one
      if (start.isBefore(monthStart)) {
        totalSaving += saving;
      }
    }

    // 🧮 Compute current month dynamic saving
    double currentFixedIncome = 0;
    double currentFixedExpense = 0;
    double currentDynamicIncome = 0;
    double currentDynamicExpense = 0;

    // 💰 Fixed Income (respect payday)
    final fixedIncomes = await supabase
        .from('Fixed_Income')
        .select('monthly_income, payday, start_time, end_time')
        .eq('profile_id', profileId);

    for (final fi in (fixedIncomes as List? ?? [])) {
      final start = fi['start_time'] != null ? DateTime.parse(fi['start_time']) : null;
      final end = fi['end_time'] != null ? DateTime.parse(fi['end_time']) : null;
      final payday = (fi['payday'] ?? 1).toInt();

      final bool isActive = (start == null || !now.isBefore(start)) &&
          (end == null || now.isBefore(end));

      // only count if we passed or are on payday this month
      if (isActive && now.day >= payday) {
        currentFixedIncome += (fi['monthly_income'] ?? 0).toDouble();
      }
    }

    // 💸 Fixed Expense (respect due_date)
    final fixedExpenses = await supabase
        .from('Fixed_Expense')
        .select('amount, due_date, start_time, end_time')
        .eq('profile_id', profileId);

    for (final fe in (fixedExpenses as List? ?? [])) {
      final start = fe['start_time'] != null ? DateTime.parse(fe['start_time']) : null;
      final end = fe['end_time'] != null ? DateTime.parse(fe['end_time']) : null;
      final dueDate = (fe['due_date'] ?? 1).toInt();

      final bool isActive = (start == null || !now.isBefore(start)) &&
          (end == null || now.isBefore(end));

      // only count if the due date has arrived or passed
      if (isActive && now.day >= dueDate) {
        currentFixedExpense += (fe['amount'] ?? 0).toDouble();
      }
    }

    // 📊 Transaction (Earning/Income/Expense) for current month
    final transactions = await supabase
        .from('Transaction')
        .select('amount, type, date')
        .eq('profile_id', profileId);

    for (final tx in (transactions as List? ?? [])) {
      final date = DateTime.tryParse(tx['date'] ?? '');
      if (date == null) continue;
      if (date.year == now.year && date.month == now.month) {
        final type = (tx['type'] ?? '').toString().toLowerCase();
        if (type == 'earning' || type == 'income') {
          currentDynamicIncome += (tx['amount'] ?? 0).toDouble();
        } else if (type == 'expense') {
          currentDynamicExpense += (tx['amount'] ?? 0).toDouble();
        }
      }
    }

    // 🧾 Compute current month total saving
    final currentMonthSaving =
        (currentFixedIncome + currentDynamicIncome) -
        (currentFixedExpense + currentDynamicExpense);

    final currentLabel =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    monthMap[currentLabel] = currentMonthSaving;

    // 🔄 Reverse order so current month is on the LEFT
    final reversedMonthMap = Map.fromEntries(
      monthMap.entries.toList().reversed,
    );

    debugPrint('📊 Fixed Income: $currentFixedIncome');
    debugPrint('📉 Fixed Expense: $currentFixedExpense');
    debugPrint('💰 Transaction Income: $currentDynamicIncome');
    debugPrint('💸 Transaction Expense: $currentDynamicExpense');
    debugPrint('🟣 Current Month Saving: $currentMonthSaving');
    debugPrint('🟢 Total Saving (previous only): $totalSaving');

    if (!mounted) return;
    setState(() {
      _totalSaving = totalSaving < 0 ? 0 : totalSaving;

      _monthlySavings
        ..clear()
        ..addAll(reversedMonthMap);
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _recalculateBalances();
    await _autoAdjustOverAssignedGoals();
  } catch (e) {
    debugPrint('❌ Error in _generateMonthlySavings: $e');
  }
}



  GoalType _statusToType(dynamic status) {
    if (status == null) return GoalType.active;
    if (status is int) {
      switch (status) {
        case 1:
          return GoalType.active;
        case 2:
          return GoalType.completed;
        case 3:
          return GoalType.uncompleted;
        case 4:
          return GoalType.achieved;
        default:
          return GoalType.active;
      }
    }
    final s = status.toString().toLowerCase();
    if (s == 'achieved') return GoalType.achieved;
    if (s == 'completed') return GoalType.completed;
    if (s == 'uncompleted' || s == 'failed') return GoalType.uncompleted;
    return GoalType.active;
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }



  String _fmt(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }

@override
Widget build(BuildContext context) {
  // Filter goals based on _selected directly in build
  final filteredGoals = _selected == 'All'
      ? List.from(_goals) // Copy all goals if 'All' is selected
      : _goals.where((goal) => goal.type == _selected).toList();

  return Scaffold(
    body: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Positioned(
                left: 0,
                top: 5,
                child: Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [AppColors.accent.withValues(alpha: 0.30), Colors.transparent],
                    ),
                  ),
                ),
              ),
              const Text(
                'Savings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 4)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.accent.withValues(alpha:0.3),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up_rounded, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Monthly Saving',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: _monthlySavings.isEmpty
                ? const Center(
                    child: Text(
                      'No monthly data yet',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 6, right: 8),
                    itemCount: _monthlySavings.length,
                    itemBuilder: (context, index) {
                      if (index < 0 || index >= _monthlySavings.length) {
                        return const SizedBox.shrink();
                      }
                      final entry = _monthlySavings.entries.elementAt(index);
                      final label = entry.key;
                      final amount = entry.value;
                      final parts = label.split('-');
                      final year = parts.isNotEmpty ? parts[0] : '';
                      final monthNum = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
                      final month = monthNum > 0 && monthNum <= 12
                          ? _monthName(monthNum)
                          : 'Unknown';
                      final now = DateTime.now();
                      final isCurrent = now.year.toString() == year && now.month == monthNum;
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _MonthCard(
                          year: year,
                          month: month,
                          amount: '${_fmt(amount)} SAR',
                          current: isCurrent,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.card.withValues(alpha:0.40),
                  AppColors.card.withValues(alpha:0.20)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha:0.12), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha:0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total Savings',
                          style: TextStyle(
                            color: AppColors.textGrey.withValues(alpha:0.80),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text(
                                  'What is Total Savings?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                content: const Text(
                                  'Total Savings includes all the money you’ve saved across previous months, showing your overall accumulated savings.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.4,
                                    fontSize: 13,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      'Got it',
                                      style: TextStyle(color: AppColors.accent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.textGrey,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt(_totalSaving)} SAR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Color(0x44000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha:0.20),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withValues(alpha:0.40), width: 2),
                  ),
                  child: Icon(Icons.trending_up, color: AppColors.accent.withValues(alpha:0.9), size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Assigned Savings',
                  amount: '${_fmt(_assignedBalance)} SAR',
                  buttonText: 'Unassign',
                  icon: Icons.flag_rounded,
                  onPressed: _openUnassignPicker,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryCard(
                  title: 'Unassigned Savings',
                  amount: '${_fmt(_unassignedBalance)} SAR',
                  buttonText: 'Assign',
                  icon: Icons.account_balance_wallet_rounded,
                  onPressed: _openAssignSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.accent.withValues(alpha:0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.flag_rounded, color: AppColors.accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Savings Goals',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accent.withValues(alpha:0.80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha:0.40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateGoalPage()),
                            );
                            await _fetchGoals();
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GoalTypeSelector(
                selected: _selected,
                onChanged: (t) => setState(() => _selected = t),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: filteredGoals.map((goal) => _GoalTile(goal: goal)).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    ),
          bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        onTapSavings: () {},
        onTapProfile: () => Navigator.pushReplacementNamed(context, '/profile'),
       
      ),
    
  );
}
void _openAssignSheet() {
  // 🧮 1️⃣ Check if there’s any unassigned balance
  if ((_unassignedBalance ?? 0) <= 0) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nothing to Assign',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You currently don’t have any unassigned savings to allocate.\n\n'
          'Once you have unassigned money available, you can assign it to your goals.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
    return; // 🔚 Stop here — no funds to assign
  }

  // 🧩 2️⃣ Check if there are any active goals
  final availableGoals = _goals
      .where((g) => g.type == GoalType.active && g.remaining > 0)
      .toList();

  if (availableGoals.isEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'No Active Goals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You don’t have any active goals to assign savings to.\n\n'
          'Create a new goal first, then you can assign money to it.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGoalPage()),
              );
              await _fetchGoals(); // refresh goals after creating
            },
            child: const Text('Create Goal',style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
    return; // 🔚 Stop here — no goals to assign to
  }

  // ✅ 3️⃣ Open normal assign sheet
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssignAmountSheet(
      goals: availableGoals,
      unassignedBalance: _unassignedBalance,
     onAssign: (goal, amount) async {
      // ✅ Immediately close the sheet to prevent double tap
      Navigator.pop(context);

      // ✅ Show loading feedback right away
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.black87,
          content: Row(
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
              const SizedBox(width: 14),
              Text('Assigning ${_fmt(amount)} SAR to ${goal.title}...'),
            ],
          ),
        ),
      );

      try {
        await supabase.from('Goal_Transfer').insert({
          'goal_id': goal.id,
          'amount': amount,
          'direction': 'Assign',
          'created_at': DateTime.now().toIso8601String(),
        });

        await _checkAndUpdateGoalStatus(goal.id);
        await _fetchGoals();
        await _generateMonthlySavings();

        // ✅ Replace the loading snackbar with success message
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: Colors.green.shade700,
                content: Text(
                  '✅ Assigned ${_fmt(amount)} SAR to ${goal.title}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
        }
      } catch (e) {
        debugPrint('❌ Error assigning: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade700,
                content: Text('Error assigning: $e'),
              ),
            );
        }
      }
    },

    ),
  );
}

  Future<void> _openUnassignPicker() async {
  await _generateMonthlySavings();
  // Check for active goals with savedAmount > 0
  final canUnassign = _goals
      .where((g) => g.type == GoalType.active && g.savedAmount > 0)
      .toList();
  if (canUnassign.isEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cannot Unassign Saving',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'There are no active goals with assigned funds to unassign.\n\n'
          'Please assign funds to an active goal first.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            itemBuilder: (c, idx) {
              final g = canUnassign[idx];
              return ListTile(
                title: Text(g.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text('Assigned: ${_fmt(g.savedAmount)} SAR',
                    style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                onTap: () {
                  Navigator.pop(context);
                  _openUnassignSheet(g);
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(color: Colors.white24),
            itemCount: canUnassign.length,
          ),
        ),
      ),
    ),
  );
}

  void _openUnassignSheet(Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnassignAmountSheet(
        goal: goal,
        onUnassign: (amount) async {
          try {
            await supabase.from('Goal_Transfer').insert({
              'goal_id': goal.id,
              'amount': amount,
              'direction': 'Unassign',
              'created_at': DateTime.now().toIso8601String(),
            });
            await _checkAndUpdateGoalStatus(goal.id);
            await _fetchGoals();
            await _generateMonthlySavings();
            Navigator.pop(context);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unassigned ${_fmt(amount)} SAR from ${goal.title}')),
              );
            }
          } catch (e) {
            debugPrint('Error unassigning: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error unassigning: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Goal goal) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete goal', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${goal.title}" goal?\n\n',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color.fromARGB(255, 246, 242, 242))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color.fromARGB(255, 246, 242, 242))),
          ),
        ],
      ),
    );
    if (ok == true) _deleteGoal(goal);
  }

  Future<void> _deleteGoal(Goal goal) async {
    try {
      final profileId = await getProfileId(context);
      if (profileId == null) return; // not logged in

      final transfers = await supabase
          .from('Goal_Transfer')
          .select('amount, direction')
          .eq('goal_id', goal.id);
      double assignedAmount = 0.0;
      for (final t in (transfers as List? ?? [])) {
        final amt = (t['amount'] ?? 0).toDouble();
        final dir = (t['direction'] ?? '').toString().toLowerCase();
        if (dir == 'assign') assignedAmount += amt;
        if (dir == 'unassign') assignedAmount -= amt;
      }
      if (assignedAmount > 0) {
        await supabase.from('Goal_Transfer').insert({
          'goal_id': goal.id,
          'amount': assignedAmount,
          'direction': 'Unassign',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('💸 Returned $assignedAmount SAR to unassigned balance');
      }
      await supabase.from('Goal').delete().eq('goal_id', goal.id);
      await _fetchGoals();
      await _generateMonthlySavings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${goal.title}" successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete goal: $e')),
        );
      }
    }
  }
}

/// ---------------- Widgets ----------------
class _MonthCard extends StatelessWidget {
  final String year, month, amount;
  final bool current;
  const _MonthCard({
    required this.year,
    required this.month,
    required this.amount,
    this.current = false,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: current
                ? [AppColors.card.withValues(alpha:0.45), AppColors.card.withValues(alpha:0.25)]
                : [AppColors.card.withValues(alpha:0.30), AppColors.card.withValues(alpha:0.16)],
          ),
          border: Border.all(
            color: current ? AppColors.accent.withValues(alpha:0.22) : Colors.white.withValues(alpha:0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha:current ? 0.20 : 0.10),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                year,
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha:0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha:0.20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha:0.40), width: 1),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            Text(
              month,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
            Text(
              amount,
              style: TextStyle(
                color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                shadows: current ? [Shadow(color: AppColors.accent.withValues(alpha:0.30), blurRadius: 8)] : const [],
              ),
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, amount, buttonText;
  final IconData icon;
  final VoidCallback? onPressed;
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.buttonText,
    required this.icon,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF373542), Color(0xFF4A375E), Color(0xFF3B3548)],
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha:0.10), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.30), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppColors.textGrey.withValues(alpha:0.90), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.accent.withValues(alpha:0.80), size: 20),
          ),
        ]),
        const SizedBox(height: 14),
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          softWrap: true,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              shadowColor: AppColors.accent.withValues(alpha:0.4),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ),
        )
      ]),
    );
  }
}

class _GoalTypeSelector extends StatelessWidget {
  final GoalType selected;
  final ValueChanged<GoalType> onChanged;
  const _GoalTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget fancyTab(String label, IconData icon, GoalType type, Color color) {
      final bool isSelected = selected == type;
      return GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color.withValues(alpha:0.8), color.withValues(alpha:0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF23202E), Color(0xFF1C1924)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha:0.6)
                  : Colors.white.withValues(alpha:0.08),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha:0.4),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha:0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha:0.65),
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 13.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.03),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const SizedBox(width: 4),
            fancyTab('Active', Icons.flash_on_rounded, GoalType.active,
                const Color(0xFF6C63FF)),
            fancyTab('Completed', Icons.check_circle_rounded,
                GoalType.completed, const Color(0xFF4CAF50)),
            fancyTab('Uncompleted', Icons.error_rounded,
                GoalType.uncompleted, const Color(0xFFFF5252)),
            fancyTab('Achieved', Icons.emoji_events_rounded,
                GoalType.achieved, const Color(0xFFFFD54F)),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}


class _ProgressAmounts extends StatelessWidget {
  final Goal goal;
  const _ProgressAmounts({required this.goal});
  String _fmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }
  @override
  Widget build(BuildContext context) {
    final double progress = goal.progress.clamp(0.0, 1.0).toDouble();
    final double remaining =
        (goal.targetAmount * (1 - progress)).clamp(0.0, double.infinity).toDouble();
    return Row(
      children: [
        Text(
          '${_fmt(remaining)} SAR left',
          style: TextStyle(color: Colors.white.withValues(alpha:0.85), fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          '${_fmt(goal.targetAmount)} SAR total',
          style: TextStyle(color: Colors.white.withValues(alpha:0.55), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}



class _GoalTile extends StatelessWidget {
  final Goal goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final isActive = goal.type == GoalType.active;
    final isCompleted = goal.type == GoalType.completed;
    final isUncompleted = goal.type == GoalType.uncompleted;
    final isAchieved = goal.type == GoalType.achieved;

    // Color scheme matching the page theme (darker, more muted)
    final Color accentColor = isCompleted
        ? const Color(0xFF059669) // Darker emerald green for completed
        : isUncompleted
            ? const Color(0xFFEF4444) // Red
            : isAchieved
                ? const Color(0xFFFBBF24) // Gold accent
                : const Color(0xFF8B5CF6); // Purple (matches page accent)
    
    final Color bgColor = isCompleted
        ? const Color(0xFF064E3B).withValues(alpha:0.15) // Dark emerald tint
        : isUncompleted
            ? const Color(0xFF7F1D1D).withValues(alpha:0.15) // Dark red tint
            : isAchieved
                ? const Color(0xFF78350F).withValues(alpha:0.15) // Dark gold tint
                : const Color(0xFF4C1D95).withValues(alpha:0.15); // Dark purple tint

    final parent = context.findAncestorStateOfType<_SavingsPageState>();

    // Enhanced status chip with better positioning
    final Widget statusChip;
    if (isActive) {
      statusChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Increased padding for readability
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.withValues(alpha:0.25), accentColor.withValues(alpha:0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha:0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha:0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up_rounded, color: accentColor, size: 14),
            const SizedBox(width: 4),
            Text(
              '${(goal.progress * 100).toInt()}%',
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    } else if (isCompleted) {
      statusChip = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha:0.15),
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withValues(alpha:0.3), width: 1.5),
        ),
        child: Icon(Icons.check_circle_rounded, color: accentColor, size: 20),
      );
    } else if (isUncompleted) {
      statusChip = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha:0.15),
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withValues(alpha:0.3), width: 1.5),
        ),
        child: Icon(Icons.pause_circle_filled_rounded, color: accentColor, size: 20),
      );
    } else if (isAchieved) {
      statusChip = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.withValues(alpha:0.3), accentColor.withValues(alpha:0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: accentColor.withValues(alpha:0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha:0.3),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.emoji_events_rounded, color: accentColor, size: 20),
      );
    } else {
      statusChip = const Icon(Icons.help_outline, color: Colors.white54, size: 22);
    }

    void _openEdit() async {
      final parent = context.findAncestorStateOfType<_SavingsPageState>();
      if (parent == null) return;

      final updated = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditGoalPage(
            id: goal.id,
            initialTitle: goal.title,
            initialTargetAmount: goal.targetAmount,
            initialTargetDate: goal.targetDate,
          ),
        ),
      );

      if (updated == true) {
        await parent._fetchGoals();
        await parent._generateMonthlySavings();
        await parent._checkAndUpdateGoalStatus(goal.id);
        parent._recalculateBalances();

        if (parent.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Goal updated & balances refreshed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }

    void _askDelete() {
      final parent = context.findAncestorStateOfType<_SavingsPageState>();
      if (parent != null) parent._confirmDelete(goal);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Added bottom margin for space between tiles
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F1B2E).withValues(alpha:0.8),
            const Color(0xFF2A2537).withValues(alpha:0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha:0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor,
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha:0.1),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Subtle gradient overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha:0.08),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isActive
                                  ? 'In Progress'
                                  : isCompleted
                                      ? 'Goal Reached'
                                      : isUncompleted
                                          ? 'Not Completed'
                                          : 'Achieved',
                              style: TextStyle(
                                color: accentColor.withValues(alpha:0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (goal.type == GoalType.active ||
                              goal.type == GoalType.uncompleted ||
                              goal.type == GoalType.completed) ...[
                            _EnhancedIconButton(
                              icon: Icons.edit_rounded,
                              color: const Color(0xFF6366F1), // Consistent indigo for edit
                              onTap: _openEdit,
                            ),
                            const SizedBox(width: 8),
                            _EnhancedIconButton(
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFDC2626), // Softer red for delete
                              onTap: _askDelete,
                            ),
                            const SizedBox(width: 12),
                          ],
                          statusChip,
                        ],
                      ),
                    ],
                  ),

                  // Amount Display for Achieved Goals
                  if (isAchieved) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Date section
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accentColor.withValues(alpha:0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: accentColor.withValues(alpha:0.8),
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha:0.4),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        goal.targetDate != null
                                            ? '${goal.targetDate!.day} ${_monthName(goal.targetDate!.month).substring(0, 3)} ${goal.targetDate!.year}'
                                            : 'N/A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Amount section
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accentColor.withValues(alpha:0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payments_rounded,
                                  color: accentColor.withValues(alpha:0.8),
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha:0.4),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_fmt(goal.targetAmount)} SAR',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Progress Section for Active Goals
                  if (isActive) ...[
                    const SizedBox(height: 16),
                    // Progress Bar
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: goal.progress.clamp(0.0, 1.0).toDouble(),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha:0.7),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha:0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Remaining and Target Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_fmt(goal.remaining)} SAR left',
                          style: TextStyle(
                            color: accentColor.withValues(alpha:0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'Target: ${_fmt(goal.targetAmount)} SAR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Log as Expense Button for Completed Goals
                  if (isCompleted && goal.status == 'Completed') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () async {
                          final parent = context.findAncestorStateOfType<_SavingsPageState>();
                          if (parent != null) await parent._logCompletedGoalExpense(goal);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: accentColor.withValues(alpha:0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Log Goal as Expense',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$integerPart.${parts[1]}' : integerPart;
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class _EnhancedIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EnhancedIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha:0.3), width: 1),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}





class AddGoalFab extends StatelessWidget {
  final VoidCallback? onPressed;
  const AddGoalFab({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha:0.80)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha:0.50), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class AssignAmountSheet extends StatefulWidget {
  final List<Goal> goals;
  final double unassignedBalance;
  final void Function(Goal goal, double amount) onAssign;
  const AssignAmountSheet({
    super.key,
    required this.goals,
    required this.unassignedBalance,
    required this.onAssign,
  });
  @override
  State<AssignAmountSheet> createState() => _AssignAmountSheetState();
}

class _AssignAmountSheetState extends State<AssignAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  Goal? _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.goals.isNotEmpty ? widget.goals.first : null;
  }
  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Amount must be greater than 0';
    if (_selected == null) return 'Select a goal';
    final maxAllowed = _maxAllowed();
    if (n > maxAllowed) return 'Max allowed is ${maxAllowed.round()} SAR';
    return null;
  }
  double _maxAllowed() {
    if (_selected == null) return 0;
    return [
      widget.unassignedBalance,
      _selected!.remaining,
    ].reduce((a, b) => a < b ? a : b);
  }
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign to goal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Goal>(
                    initialValue: _selected,
                    dropdownColor: AppColors.card,
                    decoration: _ddDecoration('Goal'),
                    items: widget.goals.map((g) {
                      return DropdownMenuItem(
                        value: g,
                        child: Text(
                          '${g.title} • remaining ${g.remaining.round()} SAR',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (g) => setState(() => _selected = g),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Amount (SAR)', hint: 'e.g., 500'),
                    validator: _validateAmount,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          widget.onAssign(_selected!, double.parse(_amountCtrl.text));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                      ),
                      child: const Text('Assign'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _fieldDecoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha:0.06),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha:0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
  InputDecoration _ddDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withValues(alpha:0.06),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha:0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class UnassignAmountSheet extends StatefulWidget {
  final Goal goal;
  final void Function(double amount) onUnassign;
  const UnassignAmountSheet({super.key, required this.goal, required this.onUnassign});
  @override
  State<UnassignAmountSheet> createState() => _UnassignAmountSheetState();
}

class _UnassignAmountSheetState extends State<UnassignAmountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
  String? _validate(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Amount must be greater than 0';
    if (n > widget.goal.savedAmount) {
      return 'Max you can unassign is ${widget.goal.savedAmount.round()} SAR';
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unassign from "${widget.goal.title}"',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Currently assigned: ${widget.goal.savedAmount.round()} SAR',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Amount (SAR)', hint: 'e.g., 300'),
                    validator: _validate,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          widget.onUnassign(double.parse(_amountCtrl.text));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 6,
                      ),
                      child: const Text('Unassign'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _fieldDecoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withValues(alpha:0.06),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha:0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}