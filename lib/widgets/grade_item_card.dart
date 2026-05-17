import 'package:flutter/material.dart';

import '../models/grade_item.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../services/firestore_service.dart';
import '../utils/grade_calc.dart';
import '../screens/forms/crear_grade_item_screen.dart';
import '../screens/tasks/detalle_tarea_screen.dart';
import 'edit_grade_nota_dialog.dart';

/// Tarjeta de un grade item dentro del tab "Notas del curso".
/// Si tiene una tarea vinculada, se muestra el vínculo y la nota se
/// considera derivada de esa tarea.
class GradeItemCard extends StatelessWidget {
  final GradeItem item;
  final Subject subject;
  const GradeItemCard({
    super.key,
    required this.item,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskItem>>(
      stream: FirestoreService.instance.watchTasksByGradeItem(item.id),
      builder: (context, snap) {
        final subTareas = snap.data ?? const <TaskItem>[];
        final result = computeGradeItemNota(item: item, subTareas: subTareas);
        final color = subject.color;
        final tareaVinculada = result.tareaVinculada;
        final autoCalculada = result.isAutoCalculada;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: autoCalculada
                ? () => EditGradeNotaDialog.show(
                      context,
                      item: item,
                      subject: subject,
                      autoCalculada: true,
                    )
                : () => EditGradeNotaDialog.show(
                      context,
                      item: item,
                      subject: subject,
                      autoCalculada: false,
                    ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.porcentaje.toStringAsFixed(0)}% del curso',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (tareaVinculada != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetalleTareaScreen(
                                  taskId: tareaVinculada.id,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link, size: 14, color: color),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Vinculada a: ${tareaVinculada.titulo}',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 14, color: color),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.nota == null
                            ? '—'
                            : result.nota!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: result.nota == null
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                              : color,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar ítem completo',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CrearGradeItemScreen(
                              subject: subject,
                              existing: item,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
