import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../forms/crear_nota_screen.dart';
import '../forms/crear_tarea_screen.dart';
import '../notes/detalle_nota_screen.dart';

class DetalleTareaScreen extends StatelessWidget {
  final String taskId;
  const DetalleTareaScreen({super.key, required this.taskId});

  Future<void> _confirmAndDelete(BuildContext context, TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text(
          'Se eliminará "${task.titulo}" y todas sus notas asociadas. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await FirestoreService.instance.deleteTask(task.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskItem?>(
      stream: FirestoreService.instance.watchTask(taskId),
      builder: (context, snap) {
        final task = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle de tarea'),
            actions: task == null
                ? null
                : [
                    IconButton(
                      tooltip: task.completada
                          ? 'Marcar como pendiente'
                          : 'Marcar como completada',
                      icon: Icon(
                        task.completada
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      onPressed: () async {
                        try {
                          await FirestoreService.instance
                              .setTaskCompletada(task.id, !task.completada);
                        } catch (e) {
                          if (context.mounted) showErrorSnackBar(context, e);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CrearTareaScreen(existing: task),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmAndDelete(context, task),
                    ),
                  ],
          ),
          body: _buildBody(context, snap),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<TaskItem?> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final task = snap.data;
    if (task == null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Tarea no encontrada',
        subtitle: 'Es posible que la hayas eliminado.',
      );
    }
    return _Body(task: task);
  }
}

class _Body extends StatelessWidget {
  final TaskItem task;
  const _Body({required this.task});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("EEEE d 'de' MMMM, yyyy", 'es');
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, subjSnap) {
        Subject? subject;
        for (final s in (subjSnap.data ?? const <Subject>[])) {
          if (s.id == task.subjectId) {
            subject = s;
            break;
          }
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              task.titulo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: task.completada
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completada
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                PriorityBadge(importancia: task.importancia),
                if (subject != null)
                  SubjectBadge(
                    nombre: subject.nombre,
                    color: subject.color,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.event,
              label: 'Fecha límite',
              value: df.format(task.fechaLimite),
            ),
            const SizedBox(height: 16),
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              task.descripcion.isEmpty ? 'Sin descripción' : task.descripcion,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notas asociadas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CrearNotaScreen(
                        defaultSubjectId: task.subjectId,
                        taskId: task.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Note>>(
              stream: FirestoreService.instance.watchNotesByTask(task.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final notes = snap.data ?? const <Note>[];
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Aún no hay notas vinculadas a esta tarea.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return Column(
                  children: notes
                      .map((n) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NoteCard(note: n),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalleNotaScreen(noteId: note.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  PriorityBadge(importancia: note.importancia, small: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.contenido,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
