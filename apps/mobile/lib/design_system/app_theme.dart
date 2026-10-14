import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light({bool highReadability = false}) => _theme(
    brightness: Brightness.light,
    seed: AppColors.teal,
    surface: AppColors.surfaceLight,
    highReadability: highReadability,
  );

  static ThemeData dark({bool highReadability = false}) => _theme(
    brightness: Brightness.dark,
    seed: AppColors.tealDark,
    surface: AppColors.surfaceDark,
    highReadability: highReadability,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required bool highReadability,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      contrastLevel: highReadability ? 1 : 0.35,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.6,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.48),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    // Make presses visible while keeping each button's existing colors.
    final pressedOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.onSurface.withValues(
          alpha: brightness == Brightness.light ? 0.16 : 0.22,
        );
      }
      return null;
    });
    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom().copyWith(
          overlayColor: pressedOverlay,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom().copyWith(
          overlayColor: pressedOverlay,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom().copyWith(
          overlayColor: pressedOverlay,
        ),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        color: colorScheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppDimensions.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ).copyWith(overlayColor: pressedOverlay),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppDimensions.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ).copyWith(overlayColor: pressedOverlay),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.secondaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}
