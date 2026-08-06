import 'package:flutter/material.dart';

/// The fleet's visual identity.
///
/// Every app themes from here so a brand change is one commit in this package
/// rather than 200 edits. An app that needs to differ passes a [seedColor] —
/// that is the supported escape hatch. Forking the whole ThemeData in an app is
/// not: it silently opts that app out of every future brand fix.
class ShellTheme {
  const ShellTheme._();

  /// Fleet default brand colour. Overridable per app via [light]/[dark].
  static const Color brandSeed = Color(0xFF3B5BDB);

  static ThemeData light({Color seedColor = brandSeed}) =>
      _build(Brightness.light, seedColor);

  static ThemeData dark({Color seedColor = brandSeed}) =>
      _build(Brightness.dark, seedColor);

  static ThemeData _build(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Mobile-first: these are handset-tuned and adapt upward. See the
      // five-platform scaffold rule in app-shell-template.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48), // thumb-sized by default
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }

  /// Width at which layouts switch from handset to large-screen. One number,
  /// fleet-wide, so "tablet" means the same thing in every app.
  static const double largeScreenBreakpoint = 720;

  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= largeScreenBreakpoint;
}
