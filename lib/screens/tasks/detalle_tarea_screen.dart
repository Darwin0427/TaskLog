import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../forms/crear_nota_screen.dart';

class DetalleTareaScreen extends StatelessWidget {
  final String taskId;
  const DetalleTareaScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de tarea')),
      body: FutureBuilder<TaskItem?>(
        future: FirestoreService.instance.getTask(taskId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = snap.data;
          if (task == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Tarea no encontrada',
            );
          }
          return _Body(task: task);
        },
      ),
    );
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
    );
  }
}
