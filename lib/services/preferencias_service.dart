import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del dispositivo que no son de la cuenta (semestre actual).
class PreferenciasService {
  PreferenciasService._();
  static final PreferenciasService instance = PreferenciasService._();

  static const String _kSemestre = 'semestre_actual';

  /// Semestre que se muestra en Materias (ej. «2026-2»).
  final ValueNotifier<String> semestre =
      ValueNotifier<String>(semestrePorDefecto(DateTime.now()));

  /// Enero–junio = 1, julio–diciembre = 2.
  static String semestrePorDefecto(DateTime d) =>
      '${d.year}-${d.month <= 6 ? 1 : 2}';

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kSemestre);
      if (s != null && s.isNotEmpty) semestre.value = s;
    } catch (_) {}
  }

  Future<void> cambiarSemestre(String valor) async {
    semestre.value = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSemestre, valor);
    } catch (_) {}
  }
}
