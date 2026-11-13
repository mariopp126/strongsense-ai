import 'package:flutter/material.dart';

import 'ss_colors.dart';

/// Material 3 themes that keep the reference design's slate/emerald identity.
abstract final class SsTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: SsColors.emerald600,
      onPrimary: Colors.white,
      primaryContainer: SsColors.emerald100,
      onPrimaryContainer: SsColors.emerald800,
      secondary: SsColors.slate800,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: SsColors.slate800,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: SsColors.slate50,
      surfaceContainer: SsColors.slate100,
      surfaceContainerHigh: SsColors.slate200,
      surfaceContainerHighest: SsColors.slate300,
      onSurfaceVariant: SsColors.slate500,
      outline: SsColors.slate300,
      outlineVariant: SsColors.slate200,
      error: SsColors.red500,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: SsColors.slate50,
      fontFamily: null,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, SsColors.slate900),
      appBarTheme: const AppBarTheme(
        backgroundColor: SsColors.slate900,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: SsColors.slate300),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SsColors.emerald100,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? SsColors.emerald700 : SsColors.slate500,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SsColors.emerald600 : SsColors.slate400,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: SsColors.emerald100,
        selectedIconTheme: IconThemeData(color: SsColors.emerald600),
        unselectedIconTheme: IconThemeData(color: SsColors.slate400),
        selectedLabelTextStyle: TextStyle(
          color: SsColors.emerald700,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: SsColors.slate500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SsColors.emerald600,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: SsSpacing.lg),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SsColors.slate800,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: SsColors.slate200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SsColors.emerald700,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.lg,
          vertical: SsSpacing.md,
        ),
        hintStyle: const TextStyle(color: SsColors.slate400),
        border: _border(SsColors.slate200),
        enabledBorder: _border(SsColors.slate200),
        focusedBorder: _border(SsColors.emerald500, width: 2),
        errorBorder: _border(SsColors.red500),
        focusedErrorBorder: _border(SsColors.red500, width: 2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: SsColors.emerald500,
        inactiveTrackColor: SsColors.slate200,
        thumbColor: SsColors.emerald600,
        overlayColor: SsColors.emerald500.withValues(alpha: 0.15),
        trackHeight: 5,
        valueIndicatorColor: SsColors.slate900,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : SsColors.slate400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SsColors.emerald500
              : SsColors.slate200,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: SsColors.emerald100,
        side: const BorderSide(color: SsColors.slate200),
        labelStyle: const TextStyle(
          color: SsColors.slate700,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsSpacing.radiusFull),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SsColors.slate900,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SsColors.slate200,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SsColors.emerald500,
        linearTrackColor: SsColors.slate200,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsSpacing.radiusLg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SsSpacing.radiusXl),
          ),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: SsColors.emerald400,
      onPrimary: SsColors.slate900,
      primaryContainer: SsColors.emerald800,
      onPrimaryContainer: SsColors.emerald50,
      secondary: SsColors.slate200,
      onSecondary: SsColors.slate900,
      surface: SsColors.slate800,
      onSurface: SsColors.slate100,
      surfaceContainerLowest: SsColors.slate900,
      surfaceContainerLow: SsColors.slate900,
      surfaceContainer: SsColors.slate800,
      surfaceContainerHigh: SsColors.slate700,
      surfaceContainerHighest: SsColors.slate600,
      onSurfaceVariant: SsColors.slate400,
      outline: SsColors.slate600,
      outlineVariant: SsColors.slate700,
      error: SsColors.red500,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SsColors.slate900,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, SsColors.slate50),
      appBarTheme: const AppBarTheme(
        backgroundColor: SsColors.slate900,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SsColors.slate800,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SsColors.emerald800,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? SsColors.emerald300 : SsColors.slate400,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SsColors.slate800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.lg,
          vertical: SsSpacing.md,
        ),
        border: _border(SsColors.slate700),
        enabledBorder: _border(SsColors.slate700),
        focusedBorder: _border(SsColors.emerald400, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SsColors.emerald500,
          foregroundColor: SsColors.slate900,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SsColors.slate700,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base, Color color) {
    return base.copyWith(
      displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: color, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: color, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: color, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }
}
