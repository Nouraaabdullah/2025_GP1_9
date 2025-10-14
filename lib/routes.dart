import 'package:flutter/material.dart';
import 'screens/Dashboard/dashboard_page.dart';
import 'screens/profile_main.dart';
import 'screens/edit_profile.dart';
import 'screens/spending_insight.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const DashboardPage(),
  '/profile': (context) => const ProfileMainPage(),
  '/editProfile': (context) => const EditProfilePage(),
  '/spendingInsight': (context) => const SpendingInsightPage(),
};
