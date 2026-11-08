import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Paleta global de la app.
class AppColors {
  AppColors._();

  // Acento principal (morado TaskLog). Con texto blanco encima.
  static const Color primary = Color(0xFF6E62E5);

  // Prioridades: colores del sistema de iOS (rojo, naranja, verde).
  static const Color highPriority = Color(0xFFFF453A);
  static const Color mediumPriority = Color(0xFFFF9F0A);
  static const Color lowPriority = Color(0xFF30D158);

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

/// Colores base estilo iOS para cada modo.
///
/// - `fondo`: fondo de pantalla (negro puro en oscuro, gris en claro).
/// - `grupo`: tarjetas y listas agrupadas.
/// - `grupo2` / `grupo3`: superficies elevadas (campos, segmentados).
/// - `texto2`: texto secundario.
/// - `separador`: líneas entre filas.
class TaskLogPalette {
  final Color fondo;
  final Color grupo;
  final Color grupo2;
  final Color grupo3;
  final Color texto;
  final Color texto2;
  final Color separador;
  final Color acento;

  const TaskLogPalette({
    required this.fondo,
    required this.grupo,
    required this.grupo2,
    required this.grupo3,
    required this.texto,
    required this.texto2,
    required this.separador,
    required this.acento,
  });

  static const oscuro = TaskLogPalette(
    fondo: Color(0xFF000000),
    grupo: Color(0xFF1C1C1E),
    grupo2: Color(0xFF2C2C2E),
    grupo3: Color(0xFF3A3A3C),
    texto: Color(0xFFFFFFFF),
    texto2: Color(0xFF8E8E93),
    separador: Color(0xFF38383A),
    // Más claro que `AppColors.primary` para que se lea sobre negro.
    acento: Color(0xFF9D95FF),
  );

  static const claro = TaskLogPalette(
    fondo: Color(0xFFF2F2F7),
    grupo: Color(0xFFFFFFFF),
    grupo2: Color(0xFFE9E9EE),
    grupo3: Color(0xFFD9D9DE),
    texto: Color(0xFF000000),
    texto2: Color(0xFF6C6C70),
    separador: Color(0xFFC6C6C8),
    // Más oscuro que `AppColors.primary` para que se lea sobre blanco.
    acento: Color(0xFF5548D9),
  );

  static TaskLogPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oscuro : claro;
}

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? TaskLogPalette.oscuro : TaskLogPalette.claro;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.acento,
    onPrimary: dark ? Colors.black : Colors.white,
    primaryContainer: AppColors.primary,
    onPrimaryContainer: Colors.white,
    secondary: p.acento,
    onSecondary: dark ? Colors.black : Colors.white,
    tertiary: AppColors.lowPriority,
    onTertiary: Colors.black,
    error: dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
    onError: Colors.white,
    surface: p.fondo,
    onSurface: p.texto,
    onSurfaceVariant: p.texto2,
    surfaceContainerLowest: p.fondo,
    surfaceContainerLow: p.grupo,
    surfaceContainer: p.grupo,
    surfaceContainerHigh: p.grupo2,
    surfaceContainerHighest: p.grupo3,
    outline: p.separador,
    outlineVariant: p.separador,
    inverseSurface: p.texto,
    onInverseSurface: p.fondo,
    inversePrimary: AppColors.primary,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  const radioGrupo = 16.0;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.fondo,
    canvasColor: p.fondo,
    // iOS no usa la "onda" de Material al tocar.
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.texto.withValues(alpha: 0.06),
    // Transiciones de iOS (incluye deslizar desde el borde para volver).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: p.texto,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: p.acento),
      actionsIconTheme: IconThemeData(color: p.acento),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.grupo,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioGrupo),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.acento,
      textColor: p.texto,
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: DividerThemeData(
      color: p.separador,
      thickness: 0.5,
      space: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.grupo,
      hintStyle: TextStyle(color: p.texto2),
      labelStyle: TextStyle(color: p.texto2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.acento, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.acento,
        textStyle: const TextStyle(fontSize: 17),
      ),
    ),
    switchTheme: SwitchThemeData(
      // Verde de iOS cuando está activo.
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF34C759)
            : p.grupo3,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.grupo2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? p.grupo : p.fondo,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.grupo3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radioGrupo)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.grupo2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.grupo3,
      contentTextStyle: TextStyle(color: p.texto),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.acento),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}
