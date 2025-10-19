import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// ---------------- Domain ----------------
enum GoalType { active, completed, uncompleted }

class Goal {
  final String id;
  final String title;
  final GoalType type;
  final double targetAmount;
  final DateTime createdAt;
  final double savedAmount;
  final DateTime? targetDate; // persist a real target date

  const Goal({
    required this.id,
    required this.title,
    required this.type,
    required this.targetAmount,
    required this.createdAt,
    this.savedAmount = 0.0,
    this.targetDate,
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
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
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

  //Created a Supabase client to interact with the database
  final supabase = Supabase.instance.client;

  GoalType _selected = GoalType.active;

  // Monthly savings (dummy data for now)
  final Map<String, double> _monthlySavings = {};

  // Derived balances for assigning
  double _unassignedBalance = 0;

  double _totalSaving = 0.0;


  final List<Goal> _goals = [];


@override
void initState() {
  super.initState();

  _generateMonthlySavings(); // initial load
  _fetchGoals(); // keep your existing fetch

  //  Realtime listener for Transaction table
  supabase
      .channel('public:Transaction')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Transaction',
        callback: (payload) async {
          debugPrint(' Transaction updated: ${payload.eventType}');
          await _generateMonthlySavings();
        },
      )
      .subscribe();

  //  Realtime listener for Fixed_Income table
  supabase
      .channel('public:Fixed_Income')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Fixed_Income',
        callback: (payload) async {
          debugPrint(' Fixed_Income updated: ${payload.eventType}');
          await _generateMonthlySavings();
        },
      )
      .subscribe();

  //  Realtime listener for Fixed_Expense table
  supabase
      .channel('public:Fixed_Expense')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Fixed_Expense',
        callback: (payload) async {
          debugPrint(' Fixed_Expense updated: ${payload.eventType}');
          await _generateMonthlySavings();
        },
      )
      .subscribe();

  //  also listen for changes in Monthly_Financial_Record
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


      // Realtime listener for Goal_Transfer
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

}



void _subscribeToMonthlyChanges() {
  supabase
      .channel('public:Monthly_Financial_Record')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Monthly_Financial_Record',
        callback: (payload) async {
          debugPrint('Monthly record changed: ${payload.eventType}');
          await _generateMonthlySavings();

        },
      )
      .subscribe();
}


Future<void> _fetchGoals() async {
  try {
    const profileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';

    // 1Fetch all goals
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

    // Fetch all transfer records for these goals
    final transferResponse = await supabase
        .from('Goal_Transfer')
        .select('goal_id, amount, direction')
        .inFilter('goal_id', data.map((g) => g['goal_id']).whereType<String>().toList());

    final Map<String, double> goalSaved = {};

    for (final t in transferResponse) {
      final id = t['goal_id'];
      final amt = (t['amount'] ?? 0).toDouble();
      final dir = t['direction']?.toString().toLowerCase();

      goalSaved[id] = (goalSaved[id] ?? 0) +
          (dir == 'assign' ? amt : dir == 'unassign' ? -amt : 0);
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
        targetDate: g['target_date'] != null
            ? DateTime.parse(g['target_date'])
            : null,
        type: _statusToType(g['status']),
      );
    }).toList();

    setState(() {
      _goals
        ..clear()
        ..addAll(fetchedGoals);
    });
  _recalculateBalances();
    debugPrint(' Goals fetched successfully: ${_goals.length}');
  } catch (e) {
    debugPrint('Error fetching goals: $e');
  }

  
}

// ------------------------------------------------------
// CHECK & UPDATE GOAL STATUS (after assign/unassign)
// ------------------------------------------------------
// This function recalculates the total assigned amount for a given goal.
// If assigned ≥ target, it marks the goal as 'Completed'.
// If assigned < target, it ensures status is 'Active'.
Future<void> _checkAndUpdateGoalStatus(String goalId) async {
  try {
    //  Sum all assigned and unassigned transfers for this goal
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

    //  Get the target amount of the goal
    final goal = await supabase
        .from('Goal')
        .select('target_amount')
        .eq('goal_id', goalId)
        .single();

    final target = (goal['target_amount'] ?? 0).toDouble();

    //  Determine new status
    final newStatus = totalAssigned >= target ? 'Completed' : 'Active';

    //  Update the goal in database if needed
    await supabase
        .from('Goal')
        .update({'status': newStatus})
        .eq('goal_id', goalId);

    debugPrint(' Goal $goalId status updated to $newStatus');
    await _fetchGoals(); // refresh UI
  } catch (e) {
    debugPrint(' Error updating goal status: $e');
  }
}

// ------------------------------------------------------
// FETCH A SINGLE GOAL BY ID (for editing)
// ------------------------------------------------------
Future<Goal?> _fetchGoalById(String goalId) async {
  try {
    final res = await supabase
        .from('Goal')
        .select()
        .eq('goal_id', goalId)
        .single();

    if (res == null) return null;

    // Map DB fields into Goal object
    return Goal(
      id: res['goal_id'],
      title: res['name'] ?? '',
      targetAmount: (res['target_amount'] ?? 0).toDouble(),
      savedAmount: (res['saved_amount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(res['created_at']),
      targetDate: res['target_date'] != null
          ? DateTime.parse(res['target_date'])
          : null,
      type: _statusToType(res['status']),
    );
  } catch (e) {
    debugPrint('❌ Error fetching goal by ID: $e');
    return null;
  }
}

// ------------------------------------------------------
// UPDATE GOAL INFO AFTER EDIT (handles status + balance)
// ------------------------------------------------------
Future<void> _updateGoal(Goal updated) async {
  try {
    //  Fetch total assigned amount from Goal_Transfer
    final transfers = await supabase
        .from('Goal_Transfer')
        .select('amount, direction')
        .eq('goal_id', updated.id);

    double totalAssigned = 0.0;
    for (final t in (transfers as List? ?? [])) {
      final amt = (t['amount'] ?? 0).toDouble();
      final dir = (t['direction'] ?? '').toString().toLowerCase();
      if (dir == 'assign') totalAssigned += amt;
      if (dir == 'unassign') totalAssigned -= amt;
    }

    // Determine new status based on savedAmount vs target
    final newStatus =
        totalAssigned >= updated.targetAmount ? 'Completed' : 'Active';

    //  Update in database
    await supabase.from('Goal').update({
      'name': updated.title,
      'target_amount': updated.targetAmount,
      'target_date': updated.targetDate?.toIso8601String(),
      'status': newStatus,
     
    }).eq('goal_id', updated.id);

    //  Refresh local state — update this goal in the list
    setState(() {
      final i = _goals.indexWhere((g) => g.id == updated.id);
      if (i != -1) {
        _goals[i] = updated.copyWith(
          savedAmount: totalAssigned,
          type: _statusToType(newStatus),
        );
      }
    });

   
    _recalculateBalances();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Goal updated: ${updated.title} ($newStatus)')),
    );
  } catch (e) {
    debugPrint(' Error updating goal: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating goal: $e')),
    );
  }
}


void _recalculateBalances() {
  final assigned = _goals.fold(0.0, (sum, g) => sum + g.savedAmount);
  setState(() {
    _unassignedBalance = _totalSaving - assigned;
  });
}


Future<void> _generateMonthlySavings() async {
  try {
    const profileId = 'e33f0c91-26fd-436a-baa3-6ad1df3a8152';
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    //  Fetch all monthly records
    final mfr = await supabase
        .from('Monthly_Financial_Record')
        .select('period_start, monthly_saving')
        .eq('profile_id', profileId)
        .order('period_start', ascending: true);

    final Map<int, double> monthlyData = {};
    for (final r in (mfr as List? ?? const [])) {
      final d = DateTime.parse(r['period_start']);
      if (d.year == currentYear) {
        monthlyData[d.month] = (r['monthly_saving'] ?? 0).toDouble();
      }
    }

    //  Fetch current month Transactions
    final monthStart = DateTime(currentYear, currentMonth, 1);
    final nextMonthStart = DateTime(
      currentMonth == 12 ? currentYear + 1 : currentYear,
      currentMonth == 12 ? 1 : currentMonth + 1,
      1,
    );

    final tx = await supabase
        .from('Transaction')
        .select('type, amount, date')
        .eq('profile_id', profileId)
        .gte('date', monthStart.toIso8601String())
        .lt('date', nextMonthStart.toIso8601String());

    double transactionEarning = 0;
    double transactionExpense = 0;

    for (final t in (tx as List? ?? const [])) {
      final amt = (t['amount'] ?? 0).toDouble();
      final typ = (t['type'] ?? '').toString().toLowerCase();
      if (typ == 'earning') transactionEarning += amt;
      if (typ == 'expense') transactionExpense += amt;
    }

    //  Fetch Fixed Income (active this month)
    final fixedIncome = await supabase
        .from('Fixed_Income')
        .select('monthly_income, start_time, end_time')
        .eq('profile_id', profileId);

    double activeIncome = 0;
    for (final i in (fixedIncome as List? ?? const [])) {
      final start = DateTime.parse(i['start_time']);
      final end = DateTime.parse(i['end_time']);
      if (now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
        activeIncome += (i['monthly_income'] ?? 0).toDouble();
      }
    }

    // 4️⃣ Fetch Fixed Expense (active this month)
    final fixedExpense = await supabase
        .from('Fixed_Expense')
        .select('amount, start_time')
        .eq('profile_id', profileId);

    double activeExpense = 0;
    for (final e in (fixedExpense as List? ?? const [])) {
      final start = DateTime.parse(e['start_time']);
      if (start.year == currentYear && start.month == currentMonth) {
        activeExpense += (e['amount'] ?? 0).toDouble();
      }
    }

    // 5️⃣ Calculate live current-month saving
    final currentMonthLive = (transactionEarning + activeIncome) -
        (transactionExpense + activeExpense);

    // 6️⃣ Ensure all months up to current exist
    for (int m = 1; m <= currentMonth; m++) {
      monthlyData.putIfAbsent(m, () => 0.0);
    }

    // 7️⃣ Replace current month value
    monthlyData[currentMonth] = currentMonthLive;

    // 8️⃣ Sort (current month first)
    final sorted = monthlyData.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // 9️⃣ Total saving = all previous months (before current)
    double totalSaving = 0;
    monthlyData.forEach((m, v) {
      if (m < currentMonth) totalSaving += v;
    });

    // 🔟 Update UI
    setState(() {
      _monthlySavings
        ..clear()
        ..addEntries(sorted.map((e) => MapEntry(
              '${_monthName(e.key)} $currentYear',
              e.value,
            )));
      _totalSaving = totalSaving;
      final assigned = _goals.fold(0.0, (sum, g) => sum + g.savedAmount);
      _unassignedBalance = totalSaving - assigned;

    });

    debugPrint(
        '✅ Monthly data: $_monthlySavings | Total before current: $totalSaving | Current live: $currentMonthLive | Earn=$transactionEarning+$activeIncome | Exp=$transactionExpense+$activeExpense');
        _recalculateBalances();
  } catch (e) {
    debugPrint('❌ Error in _generateMonthlySavings: $e');
  }
}






GoalType _statusToType(dynamic status) {
  if (status == null) return GoalType.active;
  final s = status.toString().toLowerCase();
  if (s == 'completed') return GoalType.completed;
  if (s == 'uncompleted' || s == 'failed') return GoalType.uncompleted;
  return GoalType.active;
}




  String _monthName(int month) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[month - 1];
  }

  
  double get _assignedBalance =>
      _goals.fold(0.0, (sum, g) => sum + g.savedAmount);

double get totalSavings {
  final now = DateTime.now();
  double total = 0.0;

  _monthlySavings.forEach((label, value) {
    final parts = label.split(' ');
    final month = _monthIndex(parts[0]);
    final year = int.tryParse(parts[1]) ?? 0;
    if (year == now.year && month < now.month) {
      total += value; // Only months before current
    }
  });
  return total;
}


int _monthIndex(String name) {
  const months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  return months.indexOf(name) + 1;
}

  String _fmt(double value) {
    final s = value.round().toString();
    return s.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        _goals.where((g) => g.type == _selected).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
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
                          colors: [AppColors.accent.withValues(alpha:0.30), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Savings',
                    style: TextStyle(
                      color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                      shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Monthly Saving header
              Row(
                children: [
                  Container(
                    width: 4, height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.withValues(alpha:0.30)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Monthly Saving',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ],
              ),
              const SizedBox(height: 18),

              // Months list
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 6, right: 8),
                  itemCount: _monthlySavings.length,
                  itemBuilder: (context, index) {
                    final entry = _monthlySavings.entries.elementAt(index);
                    final parts = entry.key.split(' ');
                    final month = parts[0];
                    final year = parts[1];
                    final amount = entry.value;

                    final now = DateTime.now();
                    final isCurrent =
                        month == _monthName(now.month) && year == now.year.toString();

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

              // Total Savings
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.card.withValues(alpha:0.40), AppColors.card.withValues(alpha:0.20)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.12), width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha:0.15), blurRadius: 24, offset: Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Savings',
                          style: TextStyle(color: AppColors.textGrey.withValues(alpha:0.80), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('${_fmt(totalSavings)} SAR',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                            shadows: [Shadow(color: Color(0x44000000), offset: Offset(0, 2), blurRadius: 4)],
                          )),
                    ]),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha:0.20),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withValues(alpha:0.40), width: 2),
                      ),
                      child: Icon(Icons.trending_up, color: AppColors.accent, size: 28),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Assigned to Goals',
                      amount: '${_fmt(_assignedBalance)} SAR',
                      buttonText: 'Unassign',
                      icon: Icons.flag_rounded,
                      onPressed: _openUnassignPicker,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Unassigned Balance',
                      amount: '${_fmt(_unassignedBalance)} SAR',
                      buttonText: 'Assign',
                      icon: Icons.account_balance_wallet_rounded,
                      onPressed: _openAssignSheet,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Goals header + add
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 4, height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accent.withValues(alpha:0.30)],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Savings Goals',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ]),
                  AddGoalFab(onPressed: _openAddGoalSheet),
                ],
              ),
              const SizedBox(height: 14),

              // Filter
              _GoalTypeSelector(
                selected: _selected,
                onChanged: (t) => setState(() => _selected = t),
              ),
              const SizedBox(height: 12),

              // Goals list
              ListView.separated(
                key: ValueKey(_selected),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _GoalTile(goal: filtered[i]),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),

      bottomNavigationBar: SurraBottomBar(
        onTapDashboard: () =>
            Navigator.pushReplacementNamed(context, '/dashboard'),
        onTapSavings: () {},
        onTapProfile: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        onTapAdd: () {},
      ),
    );
  }

void _openAddGoalSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddGoalSheet(
      onSubmit: (title, amount, targetDate) async {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Creating goal...')),
        );

        try {
          final response = await supabase.from('Goal').insert({
            'name': title.trim(),
            'target_amount': amount,
            'target_date': targetDate.toIso8601String(),
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
            'profile_id': "e33f0c91-26fd-436a-baa3-6ad1df3a8152",
          }).select();

          if (response.isEmpty) throw Exception('Insert failed — no data returned.');
          final data = response.first;

          setState(() {
            _goals.add(Goal(
              id: data['goal_id'], 
              title: data['name'] ?? title,
              type: GoalType.active,
              targetAmount: (data['target_amount'] ?? amount).toDouble(),
              createdAt: DateTime.parse(data['created_at']),
              targetDate: DateTime.parse(data['target_date']),
            ));
            _selected = GoalType.active;
          });

          await _generateMonthlySavings(); 

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal created successfully!')),
          );
        } catch (e) {
          debugPrint('Cannot create goal: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating goal: $e')),
          );
        }
      },
    ),
  );
}



void _openAssignSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssignAmountSheet(
      goals: _goals
          .where((g) => g.type == GoalType.active && g.remaining > 0)
          .toList(),
      unassignedBalance: _unassignedBalance,
onAssign: (goal, amount) async {
  try {
    //  Insert assignment record into Goal_Transfer
    await supabase.from('Goal_Transfer').insert({
      'goal_id': goal.id,
      'amount': amount,
      'direction': 'Assign',
      'created_at': DateTime.now().toIso8601String(),
    });

    await _checkAndUpdateGoalStatus(goal.id);
    await _fetchGoals();  
    await _generateMonthlySavings();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigned ${_fmt(amount)} SAR to ${goal.title}')),
    );
  } catch (e) {
    debugPrint('Error assigning: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error assigning: $e')),
    );
  }
},

    ),
  );
}




 Future<void> _openUnassignPicker() async{
    await _generateMonthlySavings();
    final canUnassign = _goals.where((g) => g.savedAmount > 0).toList();
    if (canUnassign.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned amounts to unassign')),
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
        // Insert unassignment record
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unassigned ${_fmt(amount)} SAR from ${goal.title}')),
        );
      } catch (e) {
        debugPrint('Error unassigning: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unassigning: $e')),
        );
      }
    },

      ),
    );
  }

  /// -------- Delete Goal  --------
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
            child: const Text('Cancel',style: TextStyle(color: Color.fromARGB(255, 246, 242, 242))),
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
    await supabase.from('Goal').delete().eq('goal_id', goal.id);

    // Remove from UI immediately
    setState(() {
      _goals.removeWhere((g) => g.id == goal.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${goal.title}" successfully!')),
    );
  } catch (e) {
    debugPrint('Error deleting goal: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to delete goal: $e')),
    );
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
            const SizedBox(),
            Text(
              month,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
            Text(
              amount,
              style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                shadows: current ? [Shadow(color: AppColors.accent.withValues(alpha:0.30), blurRadius: 8)] : const [],
              ),
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
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
    Widget pill(String label, GoalType type, Color color) {
      final isSelected = selected == type;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color.withValues(alpha:0.70), color.withValues(alpha:0.40)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF2A2734), Color(0xFF221E2E)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha:0.35), blurRadius: 12, offset: Offset(0, 3))]
                    : [],
                border: Border.all(
                  color: isSelected ? color.withValues(alpha:0.45) : Colors.white.withValues(alpha:0.10),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.65),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('Active', GoalType.active, const Color(0xFF4A37E1)),
        const SizedBox(width: 16),
        pill('Completed', GoalType.completed, const Color(0xFF4CAF50)),
        const SizedBox(width: 16),
        pill('Uncompleted', GoalType.uncompleted, const Color(0xFFEF5350)),
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

    final Color base = isCompleted
        ? const Color(0xFF4CAF50)
        : isUncompleted
            ? const Color(0xFFEF5350)
            : const Color(0xFF4A37E1);
    final Color borderColor = base.withValues(alpha:0.30);

    final Widget statusChip = isActive
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4A37E1).withValues(alpha:0.20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4A37E1).withValues(alpha:0.30), width: 1),
            ),
            child: Text(
              '${(goal.progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          )
        : Icon(isCompleted ? Icons.check_circle : Icons.pause_circle_filled, color: base, size: 22);

      void _openEdit() async {
      final parent = context.findAncestorStateOfType<_SavingsPageState>();
      if (parent == null) return;

      // Fetch the most recent goal data before editing
      final freshGoal = await parent._fetchGoalById(goal.id) ?? goal;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditGoalSheet(
          goal: freshGoal,
          onSave: (updated) async {
            //  Update the goal
            await parent._updateGoal(updated);

            //  Re-fetch to ensure balances, totals, and tiles refresh fully
            await parent._fetchGoals();
            await parent._generateMonthlySavings();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Goal updated successfully!')),
            );
          },
        ),
      );
    }



    void _askDelete() {
      final parent = context.findAncestorStateOfType<_SavingsPageState>();
      if (parent != null) parent._confirmDelete(goal); // call state method
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF373542), Color(0xFF2A2734)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha:0.20), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title + trailing actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GhostIconButton(icon: Icons.delete_outline, onTap: _askDelete),
                    const SizedBox(width: 8),
                    _GhostIconButton(icon: Icons.edit, onTap: _openEdit),
                    const SizedBox(width: 8),
                    statusChip,
                  ],
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(children: [
                  Container(height: 8, color: Colors.white.withValues(alpha:0.10)),
                  FractionallySizedBox(
                    widthFactor: goal.progress.clamp(0.0, 1.0).toDouble(),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF4A37E1), Color(0xFFBA55D6)]),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              _ProgressAmounts(goal: goal),
            ],
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
    final s = v.round().toString();
    return s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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

/// Small ghost icon button
class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GhostIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha:0.14), width: 1),
        ),
        child: Icon(icon, size: 16, color: Colors.white70),
      ),
    );
  }
}

/// Floating add button (nullable callback to avoid analyzer error)
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

/// ---------------- Sheets (Create / Assign / Unassign / Edit) ----------------
class AddGoalSheet extends StatefulWidget {
  final void Function(String title, double amount, DateTime targetDate) onSubmit;
  const AddGoalSheet({super.key, required this.onSubmit});

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // stable controller
  DateTime? _targetDate;
  bool _submitting = false;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      initialDate: _targetDate ?? now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select target date',
      // >>> This removes the text input and the toggle icon inside the dialog
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _targetDate = DateTime(picked.year, picked.month, picked.day));
      _dateCtrl.text = _formatDate(_targetDate!);
    }
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _submitting = true);

    final title = _titleCtrl.text.trim();
    final amount = double.parse(_amountCtrl.text);
    final date = _targetDate!;

    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onSubmit(title, amount, date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha:0.35),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Create Goal',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _fieldDecoration('Goal name', hint: 'e.g., Buy a new phone'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Target amount (SAR)',
                        hint: 'e.g., 2000'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Non-typed date field: readOnly + onTap
                  TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Target date', hint: 'Select date')
                        .copyWith(suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70)),
                    validator: (_) {
                      if (_targetDate == null) return 'Target date is required';
                      final today = DateTime.now();
                      final d = DateTime(_targetDate!.year, _targetDate!.month, _targetDate!.day);
                      final t = DateTime(today.year, today.month, today.day);
                      if (d.isBefore(t)) return 'Target date cannot be in the past';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.accent.withValues(alpha:0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                        shadowColor: AppColors.accent.withValues(alpha:0.4),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Text('Create Goal',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
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
        borderSide:
            BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    value: _selected,
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

class EditGoalSheet extends StatefulWidget {
  final Goal goal;
  final void Function(Goal updatedGoal) onSave;

  const EditGoalSheet({super.key, required this.goal, required this.onSave});

  @override
  State<EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<EditGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  final _dateCtrl = TextEditingController();
  DateTime? _targetDate;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.goal.title);
    _amountCtrl = TextEditingController(text: widget.goal.targetAmount.toStringAsFixed(0));
    _targetDate = widget.goal.targetDate;
    if (_targetDate != null) _dateCtrl.text = _formatDate(_targetDate!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: _targetDate ?? now.add(const Duration(days: 1)),
      // >>> Remove text entry inside dialog
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _targetDate = DateTime(picked.year, picked.month, picked.day));
      _dateCtrl.text = _formatDate(_targetDate!);
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newTitle = _titleCtrl.text.trim();
    final newAmount = double.parse(_amountCtrl.text);

    final updated = widget.goal.copyWith(
      title: newTitle,
      targetAmount: newAmount,
      targetDate: _targetDate ?? widget.goal.targetDate,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Goal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Goal name'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Target amount (SAR)'),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Target date').copyWith(
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                    ),
                    validator: (_) {
                      if (_targetDate == null && widget.goal.targetDate == null) {
                        return 'Target date is required';
                      }
                      final today = DateTime.now();
                      final d = (_targetDate ?? widget.goal.targetDate)!;
                      final dd = DateTime(d.year, d.month, d.day);
                      final t = DateTime(today.year, today.month, today.day);
                      if (dd.isBefore(t)) return 'Target date cannot be in the past';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
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

  InputDecoration _fieldDecoration(String label) => InputDecoration(
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
          borderSide:
              BorderSide(color: AppColors.accent.withValues(alpha:0.8), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
