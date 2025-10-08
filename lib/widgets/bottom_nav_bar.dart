import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SurraBottomBar extends StatelessWidget {
  final VoidCallback onTapDashboard;
  final VoidCallback? onTapProfile; // optional
  const SurraBottomBar({
    super.key,
    required this.onTapDashboard,
    this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.card,
      height: 88, // extra height avoids overflow
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item('AI assistant', Icons.android, () {}),
          _item('Dashboard', Icons.pie_chart, onTapDashboard),
          const SizedBox(width: 56), // wider notch spacing for FAB
          _item('Savings', Icons.savings, () {}),
          _item('Profile', Icons.person, onTapProfile ?? () {}),
        ],
      ),
    );
  }

  Widget _item(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.textGrey),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 10, // small & safe for all phones
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
