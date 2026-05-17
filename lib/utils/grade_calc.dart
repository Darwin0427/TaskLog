import '../models/grade_item.dart';
import '../models/task_item.dart';

/// Resultado de calcular la nota efectiva de un grade item.
class GradeItemResult {
  /// Nota efectiva (0-5) del grade item — null si no se ha evaluado.
  final double? nota;

  /// True si la nota viene de una tarea vinculada (no editable manual).
  final bool isAutoCalculada;

  /// La tarea vinculada (si existe).
  final TaskItem? tareaVinculada;

  const GradeItemResult({
    required this.nota,
    required this.isAutoCalculada,
    this.tareaVinculada,
  });
}

/// Calcula la nota efectiva de un grade item.
///
/// Regla: una tarea = una calificación.
/// - Si NO tiene tarea vinculada → la nota es `item.nota` (manual).
/// - Si SÍ tiene tarea vinculada → la nota es la nota de esa tarea.
GradeItemResult computeGradeItemNota({
  required GradeItem item,
  required List<TaskItem> subTareas,
}) {
  if (subTareas.isEmpty) {
    return GradeItemResult(
      nota: item.nota,
      isAutoCalculada: false,
    );
  }
  // Una sola tarea por calificación; si hay varias (datos antiguos),
  // tomamos la primera.
  final tarea = subTareas.first;
  return GradeItemResult(
    nota: tarea.nota,
    isAutoCalculada: true,
    tareaVinculada: tarea,
  );
}
