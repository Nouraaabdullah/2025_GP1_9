import 'package:flutter/material.dart';
import 'screens/dashboard/dashboard_page.dart';
import 'screens/profile/profile_main.dart';
import 'screens/profile/edit_profile/edit_profile.dart';
import 'screens/profile/spending_insight.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const DashboardPage(),
  '/profile': (context) => const ProfileMainPage(),
  '/editProfile': (context) => const EditProfilePage(),
  '/spendingInsight': (context) => const SpendingInsightPage(),
};
