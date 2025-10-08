import 'package:flutter/material.dart';
import 'dashboard_page.dart';

void main() {
  runApp(const SurraTestApp());
}

class SurraTestApp extends StatelessWidget {
  const SurraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // hide the red “Debug/Demo” tag
      title: 'Surra Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

