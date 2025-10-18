import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared_profile_data.dart';

class SetupCompleteScreen extends StatelessWidget {
  const SetupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: const Color(0xFF1D1B32),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF7959F5), size: 90),
              const SizedBox(height: 24),
              const Text(
                "Setup Complete!",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your financial profile will now be saved securely to Surra’s database.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB0AFC5), fontSize: 16),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7959F5),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(color: Color(0xFF7959F5)),
    ),
  );

  try {
  // ✅ Get currently authenticated Supabase user
  final user = Supabase.instance.client.auth.currentUser;
  debugPrint("Current user id: ${user?.id}");

  if (user == null) {
    throw Exception("No logged-in user found!");
  }

  // ✅ Step 1: Create User_Profile (linked to user_id)
  final userResponse = await supabase.from('User_Profile').insert({
    'user_id': user.id, // 👈 this fixes the null error
    'full_name': ProfileData.userName ?? '',
    'current_balance': ProfileData.currentBalance ?? 0.0,
    'email': user.email ?? 'no-email',
  }).select();

  final profileId = userResponse[0]['profile_id'];

  // ✅ Step 2: Insert Fixed Income
  await supabase.from('Fixed_Income').insert({
    'name': 'Main Income',
    'monthly_income': ProfileData.monthlyIncome ?? 0.0,
    'payday': ProfileData.payday?.toString() ?? '',
    'profile_id': profileId,
  });

  // ✅ Step 3: Insert Fixed Expenses
  for (var exp in ProfileData.fixedExpenses) {
    await supabase.from('Fixed_Expense').insert({
      'name': exp['name'] ?? '',
      'amount': exp['amount'] ?? 0.0,
      'due_date': exp['dueDate'] ?? '',
      'profile_id': profileId,
    });
  }

  // ✅ Step 4: Insert Categories
  for (var cat in ProfileData.categories) {
    await supabase.from('Category').insert({
      'name': cat['name'] ?? '',
      'monthly_limit': cat['limit'] ?? 0.0,
      'icon': cat['icon'] ?? '',
      'icon_color': cat['color'].toString(),
      'profile_id': profileId,
    });
  }

  // ✅ Success message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('✅ All profile data saved successfully!'),
      backgroundColor: Colors.green,
    ),
  );

  // Clear local ProfileData cache
  ProfileData.reset();

  // Redirect to dashboard
  Navigator.pushReplacementNamed(context, '/dashboard');
} catch (e) {
  debugPrint('Supabase Error: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('❌ Error saving data: $e'),
      backgroundColor: Colors.redAccent,
    ),
  );
}

},

                child: const Text(
                  "Finish & Go to Dashboard",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
