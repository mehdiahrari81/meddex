import 'package:flutter/material.dart';

abstract final class AppColors {
  static const teal = Color(0xFF176B64);
  static const tealDark = Color(0xFF75D8CE);
  static const blue = Color(0xFF2962A8);
  static const warning = Color(0xFF9A6700);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF26734D);
  static const info = Color(0xFF285D8F);
  static const surfaceLight = Color(0xFFF7FAF9);
  static const surfaceDark = Color(0xFF101414);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadii {
  static const small = 8.0;
  static const medium = 14.0;
  static const large = 22.0;
  static const pill = 100.0;
}

abstract final class AppDimensions {
  static const minTouchTarget = 48.0;
  static const largeTouchTarget = 56.0;
  static const phoneBreakpoint = 700.0;
  static const contentMaxWidth = 1120.0;
  static const formMaxWidth = 520.0;
  static const navigationRailWidth = 88.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
}

abstract final class AppElevation {
  static const none = 0.0;
  static const low = 1.0;
  static const medium = 4.0;
}

abstract final class AppIcons {
  static const home = Icons.home_outlined;
  static const homeSelected = Icons.home_rounded;
  static const scan = Icons.document_scanner_outlined;
  static const scanSelected = Icons.document_scanner_rounded;
  static const learn = Icons.school_outlined;
  static const learnSelected = Icons.school_rounded;
  static const saved = Icons.bookmark_outline_rounded;
  static const savedSelected = Icons.bookmark_rounded;
  static const profile = Icons.person_outline_rounded;
  static const profileSelected = Icons.person_rounded;
  static const shield = Icons.health_and_safety_outlined;
  static const source = Icons.verified_outlined;
}
