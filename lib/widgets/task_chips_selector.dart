import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task_item.dart';
import '../services/firestore_service.dart';

/// Permite vincular opcionalmente una nota a una tarea. Muestra:
/// - Si no hay materia seleccionada: mensaje pidiendo elegir materia primero.
/// - Si la materia no tiene tareas: estado vacío.
/// - Si hay tareas: chips de cada una. Hay un chip "Sin tarea" al inicio
///   para desvincular.
class TaskChipsSelector extends StatelessWidget {
  final String? subjectId;
  final String? selectedTaskId;
  final ValueChanged<String?> onChanged;

  const TaskChipsSelector({
    super.key,
    required this.subjectId,
    required this.selectedTaskId,
    required this.onChanged,
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
    return StreamBuilder<List<TaskItem>>(
      stream: FirestoreService.instance.watchTasksBySubject(subjectId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 20,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final tasks = snap.data ?? const <TaskItem>[];
        if (tasks.isEmpty) {
          return Text(
            'No hay tareas en esta materia. Crea una primero o deja la nota sin vincular.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        }
        final df = DateFormat('dd MMM', 'es');
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sin tarea'),
              selected: selectedTaskId == null,
              onSelected: (_) => onChanged(null),
            ),
            ...tasks.map((t) {
              final selected = selectedTaskId == t.id;
              return ChoiceChip(
                label: Text('${t.titulo} · ${df.format(t.fechaLimite)}'),
                selected: selected,
                onSelected: (_) => onChanged(t.id),
              );
            }),
          ],
        );
      },
    );
  }
}
