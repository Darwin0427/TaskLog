import 'package:flutter/material.dart';

/// Paleta global de la app.
class AppColors {
  AppColors._();

  // Acento principal
  static const Color primary = Color(0xFF534AB7);

  // Prioridades
  static const Color highPriority = Color(0xFFE24B4A);
  static const Color mediumPriority = Color(0xFFBA7517);
  static const Color lowPriority = Color(0xFF3B6D11);

  // Paleta para materias
  static const List<Color> subjectPalette = <Color>[
    Color(0xFF534AB7), // morado
    Color(0xFF3B6D11), // verde
    Color(0xFFE24B4A), // coral / rojo
    Color(0xFFD9387B), // rosa
    Color(0xFF1E6FB8), // azul
    Color(0xFFBA7517), // ámbar
  ];

  static Color forImportancia(String importancia) {
    switch (importancia) {
      case 'Alta':
        return highPriority;
      case 'Media':
        return mediumPriority;
      case 'Baja':
        return lowPriority;
      default:
        return Colors.grey;
    }
  }

  /// Convierte un hex tipo "#RRGGBB" o "RRGGBB" a Color.
  static Color fromHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0x534AB7;
    return Color(0xFF000000 | value);
  }

  /// Convierte un Color a "#RRGGBB".
  static String toHex(Color color) {
    final argb = color.toARGB32();
    final r = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}

/// Mapa de íconos disponibles para materias.
class AppIcons {
  AppIcons._();

  static const Map<String, IconData> all = <String, IconData>{
    'code': Icons.code,
    'book': Icons.menu_book,
    'calendar': Icons.calendar_month,
    'database': Icons.storage,
    'map': Icons.map,
    'language': Icons.language,
  };

  static IconData byName(String name) =>
      all[name] ?? Icons.school_outlined;
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}
