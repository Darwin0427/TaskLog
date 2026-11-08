import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema elegido por el usuario: según el sistema, claro u oscuro.
///
/// Se guarda en el teléfono (no en Firestore): es una preferencia del
/// dispositivo, no de la cuenta.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();

  static const String _key = 'tema_app';

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _desdeTexto(prefs.getString(_key));
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    value = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, modo.name);
    } catch (_) {
      // Si no se puede guardar, el cambio igual aplica en esta sesión.
    }
  }

  static String nombre(ThemeMode modo) => switch (modo) {
        ThemeMode.system => 'Automático',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
      };

  static ThemeMode _desdeTexto(String? texto) => switch (texto) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

/// Hoja para elegir el tema. Temporal hasta que exista la pantalla de
/// Perfil y ajustes (fase 5 del rediseño).
Future<void> mostrarSelectorTema(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, actual, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apariencia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final modo in ThemeMode.values) ...[
                      ListTile(
                        title: Text(ThemeController.nombre(modo)),
                        subtitle: modo == ThemeMode.system
                            ? const Text('Igual que el iPhone')
                            : null,
                        trailing: actual == modo
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => ThemeController.instance.cambiar(modo),
                      ),
                      if (modo != ThemeMode.values.last)
                        const Divider(indent: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
