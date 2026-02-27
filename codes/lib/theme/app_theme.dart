import 'package:flutter/material.dart';

class AppColors {
  // ── Adult / Dark Theme ──
  static const darkBg = Color(0xFF0E0C1A);
  static const darkSurface = Color(0xFF1A1730);
  static const darkPurple = Color(0xFF7C5CFC);
  static const darkPurpleLight = Color(0xFF9B7FFE);
  static const darkTextMuted = Color(0xFF8B88A8);

  // ── Kid / Pastel Theme ──
  static const kPurple = Color(0xFF8B5CF6);
  static const kPurpleDark = Color(0xFF6D28D9);
  static const kPurpleSoft = Color(0xFFC4A8FF);
  static const kBlue = Color(0xFF60A5FA);
  static const kBlueSoft = Color(0xFFBFDBFE);
  static const kPink = Color(0xFFF472B6);
  static const kPinkSoft = Color(0xFFFCE7F3);
  static const kGreen = Color(0xFF34D399);
  static const kGreenSoft = Color(0xFFD1FAE5);
  static const kYellow = Color(0xFFFBBF24);
  static const kYellowSoft = Color(0xFFFEF3C7);
  static const kOrange = Color(0xFFFB923C);

  static const kText = Color(0xFF2D1B69);
  static const kTextSoft = Color(0xFF7C6FA0);
  static const kCard = Color(0xD0FFFFFF); // 82% white
  static const kBorder = Color(0x99FFFFFF); // 60% white
  static const kInputBg = Color(0xC5FFFFFF);

  static const kErrorText = Color(0xFF9D1461);
  static const kErrorBg = Color(0x30F472B6);
  static const kErrorBorder = Color(0x66F472B6);
}

class AppGradients {
  static const kidBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.45, 1.0],
    colors: [Color(0xFFD4B3F5), Color(0xFFB8D4F8), Color(0xFFF7B8D4)],
  );

  static const darkBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D1B69), Color(0xFF0E0C1A)],
    stops: [0.0, 0.55],
  );

  static const purpleBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  static const purpleCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );
}

class AppTextStyles {
  static const fredoka = 'Fredoka One';
  static const nunito = 'Nunito';

  static TextStyle fredokaStyle({
    double size = 16,
    Color color = AppColors.kText,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(fontFamily: fredoka, fontSize: size, color: color, fontWeight: weight);

  static TextStyle nunitoStyle({
    double size = 14,
    Color color = AppColors.kText,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(fontFamily: nunito, fontSize: size, color: color, fontWeight: weight);
}
