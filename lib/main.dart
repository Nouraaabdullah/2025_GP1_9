import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
<<<<<<< HEAD

// ✅ Screens
import 'screens/Registeration/welcome_screen.dart';
import 'screens/Registeration/login_screen.dart';
import 'screens/Registeration/signup_screen.dart';
=======
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
>>>>>>> 1509e563cb9e74c27a33295ee02fe1181c0dccff
import 'screens/profile_main.dart';
import 'screens/edit_profile.dart';
<<<<<<< HEAD
import 'screens/Savings/savings_page.dart';
import 'screens/Dashboard/dashboard_page.dart';
import 'screens/Registeration/profile_setup/setup_name_screen.dart';
import 'screens/Registeration/profile_setup/setup_income_screen.dart';
import 'screens/Registeration/profile_setup/setup_expenses_screen.dart';
import 'screens/Registeration/profile_setup/setup_categories_screen.dart';
import 'screens/Registeration/profile_setup/setup_balance_screen.dart';
import 'screens/Registeration/profile_setup/setup_complete_screen.dart';
=======
import 'screens/profile_setup/setup_name_screen.dart';
import 'screens/profile_setup/setup_income_screen.dart';
import 'screens/profile_setup/setup_expenses_screen.dart';
import 'screens/profile_setup/setup_balance_screen.dart';
import 'screens/Dashboard/dashboard_page.dart';
import 'screens/Savings/savings_page.dart';

// Supabase credentials
const supabaseUrl = 'https://xvnkuqqzlstzwgeecijn.supabase.co';
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
>>>>>>> 1509e563cb9e74c27a33295ee02fe1181c0dccff

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

<<<<<<< HEAD
  await Supabase.initialize(
    url: 'https://xvnkuqqzlstzwgeecijn.supabase.co', // Replace this
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh2bmt1cXF6bHN0endnZWVjaWpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2ODI2NzYsImV4cCI6MjA3NjI1ODY3Nn0.o9qiOIa4WWNMxvF92uyojCPtDS4NGz5qyMBhwki8MDQ', // Replace this
=======
  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
>>>>>>> 1509e563cb9e74c27a33295ee02fe1181c0dccff
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
<<<<<<< HEAD
=======
        '/profile': (context) => const ProfileMainPage(),
        '/dashboard': (context) => const DashboardPage(),
>>>>>>> 1509e563cb9e74c27a33295ee02fe1181c0dccff
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfileMainPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/savings': (context) => const SavingsPage(),
        '/setupName': (context) => const SetupNameScreen(),
        '/setupIncome': (context) => const SetupIncomeScreen(),
        '/setupExpenses': (context) => const SetupExpensesScreen(),
        '/setupCategories': (context) =>  SetupCategoriesScreen(),
        '/setupBalance': (context) => const SetupBalanceScreen(),
        '/setupComplete': (context) => const SetupCompleteScreen(),
      },
    );
  }
}