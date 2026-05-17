import 'package:flutter/material.dart';

import '../models/grade_item.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';

/// Permite vincular opcionalmente una tarea a un grade item (calificación)
/// de su misma materia. Un grade item solo admite UNA tarea vinculada,
/// así que los items ya ocupados aparecen deshabilitados.
class GradeItemChipsSelector extends StatelessWidget {
  final String? subjectId;
  final String? selectedGradeItemId;
  final ValueChanged<String?> onChanged;

  /// ID de la tarea actual (en modo edición) para no contarse a sí misma
  /// como "ocupando" un grade item.
  final String? currentTaskId;

  const GradeItemChipsSelector({
    super.key,
    required this.subjectId,
    required this.selectedGradeItemId,
    required this.onChanged,
    this.currentTaskId,
  });

  @override
  Widget build(BuildContext context) {
    if (subjectId == null) {
      return Text(
        'Selecciona primero una materia.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return StreamBuilder<List<GradeItem>>(
      stream: FirestoreService.instance.watchGradeItemsBySubject(subjectId!),
      builder: (context, gradeSnap) {
        if (gradeSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 20,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final items = gradeSnap.data ?? const <GradeItem>[];
        if (items.isEmpty) {
          return Text(
            'Esta materia no tiene calificaciones aún. Créalas desde el tab "Notas del curso".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        }
        // Necesitamos saber qué grade items ya tienen una tarea vinculada
        // (que no sea la tarea actual en modo edición).
        return StreamBuilder<List<TaskItem>>(
          stream: FirestoreService.instance.watchTasksBySubject(subjectId!),
          builder: (context, tasksSnap) {
            final tasks = tasksSnap.data ?? const <TaskItem>[];
            // Map: gradeItemId -> tarea vinculada (excluyendo la actual).
            final ocupados = <String, TaskItem>{};
            for (final t in tasks) {
              if (t.gradeItemId == null) continue;
              if (currentTaskId != null && t.id == currentTaskId) continue;
              ocupados[t.gradeItemId!] = t;
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No vincular'),
                  selected: selectedGradeItemId == null,
                  onSelected: (_) => onChanged(null),
                ),
                ...items.map((it) {
                  final ocupadaPor = ocupados[it.id];
                  final estaOcupada =
                      ocupadaPor != null && selectedGradeItemId != it.id;
                  return Tooltip(
                    message: estaOcupada
                        ? 'Ya vinculada a: ${ocupadaPor.titulo}'
                        : '',
                    child: ChoiceChip(
                      label: Text(
                        estaOcupada
                            ? '${it.nombre} · ocupada'
                            : '${it.nombre} · ${it.porcentaje.toStringAsFixed(0)}%',
                      ),
                      selected: selectedGradeItemId == it.id,
                      onSelected:
                          estaOcupada ? null : (_) => onChanged(it.id),
                      disabledColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
