import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_main.dart';
import 'screens/spending_insight.dart';
import 'screens/signup_screen.dart';
import 'screens/edit_profile.dart';
import 'screens/profile_setup/setup_name_screen.dart';
import 'screens/profile_setup/setup_income_screen.dart';
import 'screens/profile_setup/setup_expenses_screen.dart';
import 'screens/profile_setup/setup_balance_screen.dart';

void main() => runApp(const SurraApp());

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
        '/profile': (context) => const ProfileMainPage(),
        '/dashboard': (context) =>
            const SpendingInsightPage(), // 👈 this is now your dashboard
        '/signup': (context) => const SignUpScreen(),
        '/editProfile': (context) => const EditProfilePage(),
        '/setupName': (context) => const SetupNameScreen(),
        '/setupIncome': (context) => const SetupIncomeScreen(),
        '/setupExpenses': (context) => const SetupExpensesScreen(),
        '/setupBalance': (context) => const SetupBalanceScreen(),
      },
    );
  }
}
