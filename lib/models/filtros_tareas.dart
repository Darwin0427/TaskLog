import 'task_item.dart';

enum OrdenTareas { fecha, prioridad, materia }

/// Filtros que se eligen en la hoja «Filtros» (Tareas, Calendario,
/// Apuntes). Viven en memoria mientras la app está abierta.
class FiltrosTareas {
  /// Materias elegidas. Vacío = todas.
  final Set<String> materias;

  /// 'Alta' | 'Media' | 'Baja', o null = todas.
  final String? prioridad;

  final OrdenTareas orden;
  final bool mostrarCompletadas;

  const FiltrosTareas({
    this.materias = const <String>{},
    this.prioridad,
    this.orden = OrdenTareas.fecha,
    this.mostrarCompletadas = false,
  });

  static const ninguno = FiltrosTareas();

  /// True si hay algo distinto a lo de fábrica (para el punto en el botón).
  bool get activos =>
      materias.isNotEmpty ||
      prioridad != null ||
      orden != OrdenTareas.fecha ||
      mostrarCompletadas;

  /// Aplica materia y prioridad (no completadas: eso lo decide cada
  /// pantalla).
  bool acepta(TaskItem t) =>
      (materias.isEmpty || materias.contains(t.subjectId)) &&
      (prioridad == null || t.importancia == prioridad);

  bool aceptaMateria(String subjectId) =>
      materias.isEmpty || materias.contains(subjectId);

  FiltrosTareas copyWith({
    Set<String>? materias,
    String? prioridad,
    bool borrarPrioridad = false,
    OrdenTareas? orden,
    bool? mostrarCompletadas,
  }) {
    return FiltrosTareas(
      materias: materias ?? this.materias,
      prioridad: borrarPrioridad ? null : (prioridad ?? this.prioridad),
      orden: orden ?? this.orden,
      mostrarCompletadas: mostrarCompletadas ?? this.mostrarCompletadas,
    );
  }

  static int pesoPrioridad(String importancia) => switch (importancia) {
        'Alta' => 0,
        'Media' => 1,
        'Baja' => 2,
        _ => 3,
      };
}
