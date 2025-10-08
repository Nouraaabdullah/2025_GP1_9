import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'screens/profile_main.dart';
import 'screens/edit_profile.dart';
import 'screens/spending_insight.dart';

void main() => runApp(const SurraTestApp());

class SurraTestApp extends StatelessWidget {
  const SurraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surra Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ProfileMainPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/editProfile': (context) => const EditProfilePage(),
        '/spendingInsight': (context) => const SpendingInsightPage(),
      },
    );
  }
}
