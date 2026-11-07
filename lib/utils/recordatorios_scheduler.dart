import '../models/task_item.dart';
import '../models/task_reminder.dart';

/// Un recordatorio concreto, ya resuelto a fecha absoluta, listo para
/// programarse en el sistema.
class RecordatorioProgramable {
  final TaskItem task;

  /// Posición del recordatorio dentro de `task.recordatorios`. Se usa para
  /// derivar un ID de notificación estable.
  final int indice;

  final TaskReminder recordatorio;
  final DateTime fecha;

  const RecordatorioProgramable({
    required this.task,
    required this.indice,
    required this.recordatorio,
    required this.fecha,
  });
}

/// Elige qué recordatorios programar en el sistema operativo.
///
/// iOS solo conserva 64 notificaciones locales pendientes por app y
/// descarta el resto sin avisar. Por eso no programamos todo: tomamos los
/// [limite] recordatorios futuros más cercanos de las tareas pendientes.
/// Los demás se programan después, cuando la app vuelve a sincronizar
/// (al abrirse o al crear/editar/completar una tarea).
///
/// - Ignora tareas completadas o sin ID.
/// - Ignora recordatorios cuya fecha ya pasó (o es exactamente [ahora]).
/// - Devuelve la lista ordenada del más próximo al más lejano.
List<RecordatorioProgramable> seleccionarProximosRecordatorios(
  Iterable<TaskItem> tareas, {
  required DateTime ahora,
  required int limite,
}) {
  if (limite <= 0) return <RecordatorioProgramable>[];

  final candidatos = <RecordatorioProgramable>[];
  for (final tarea in tareas) {
    if (tarea.completada || tarea.id.isEmpty) continue;
    for (var i = 0; i < tarea.recordatorios.length; i++) {
      final r = tarea.recordatorios[i];
      final fecha = r.resolverFecha(tarea.fechaLimite);
      if (!fecha.isAfter(ahora)) continue;
      candidatos.add(RecordatorioProgramable(
        task: tarea,
        indice: i,
        recordatorio: r,
        fecha: fecha,
      ));
    }
  }

  candidatos.sort((a, b) => a.fecha.compareTo(b.fecha));
  if (candidatos.length <= limite) return candidatos;
  return candidatos.sublist(0, limite);
}
