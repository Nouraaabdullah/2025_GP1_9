import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Screens
import 'screens/Registeration/welcome_screen.dart';
import 'screens/Registeration/login_screen.dart';
import 'screens/Registeration/signup_screen.dart';
import 'screens/profile_main.dart';
import 'screens/edit_profile.dart';
import 'screens/Savings/savings_page.dart';
import 'screens/Dashboard/dashboard_page.dart';
import 'screens/Registeration/profile_setup/setup_name_screen.dart';
import 'screens/Registeration/profile_setup/setup_income_screen.dart';
import 'screens/Registeration/profile_setup/setup_expenses_screen.dart';
import 'screens/Registeration/profile_setup/setup_balance_screen.dart';
import 'screens/Registeration/profile_setup/setup_complete_screen.dart';
import 'screens/Registeration/profile_setup/fixed_categories.dart';
import 'screens/Registeration/profile_setup/custom_categories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xvnkuqqzlstzwgeecijn.supabase.co', // Replace this
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh2bmt1cXF6bHN0endnZWVjaWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2ODI2NzYsImV4cCI6MjA3NjI1ODY3Nn0.o9qiOIa4WWNMxvF92uyojCPtDS4NGz5qyMBhwki8MDQ', // Replace this
  );

  runApp(const SurraApp());
}

class SurraApp extends StatelessWidget {
  const SurraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7959F5)),
        scaffoldBackgroundColor: const Color(0xFF1D1B32),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfileMainPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/savings': (context) => const SavingsPage(),
        '/setupName': (context) => const SetupNameScreen(),
        '/setupIncome': (context) => const SetupIncomeScreen(),
        '/setupExpenses': (context) => const SetupExpensesScreen(),
        '/setupBalance': (context) => const SetupBalanceScreen(),
        '/setupComplete': (context) => const SetupCompleteScreen(),
        '/setupFixedCategory': (context) => const SetupFixedCategoryScreen(),
        '/setupCustomCategory': (context) => const SetupCustomCategoryScreen(),
      },
    );
  }
}
