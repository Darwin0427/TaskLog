import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import 'detalle_tarea_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
      ),
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, subjSnap) {
          final subjectsById = <String, Subject>{
            for (final s in (subjSnap.data ?? const <Subject>[])) s.id: s,
          };
          return StreamBuilder<List<TaskItem>>(
            stream: FirestoreService.instance.watchTasks(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final tasks = snap.data ?? const <TaskItem>[];
              if (tasks.isEmpty) {
                return const EmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'No tienes tareas',
                  subtitle: 'Toca el botón + para crear tu primera tarea.',
                );
              }
              return _GroupedTasksList(
                tasks: tasks,
                subjectsById: subjectsById,
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupedTasksList extends StatelessWidget {
  final List<TaskItem> tasks;
  final Map<String, Subject> subjectsById;
  const _GroupedTasksList({
    required this.tasks,
    required this.subjectsById,
  });

  @override
  Widget build(BuildContext context) {
    final alta = tasks.where((t) => t.importancia == 'Alta').toList();
    final media = tasks.where((t) => t.importancia == 'Media').toList();
    final baja = tasks.where((t) => t.importancia == 'Baja').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (alta.isNotEmpty)
          _section(context, 'Alta prioridad', alta, AppColors.highPriority),
        if (media.isNotEmpty)
          _section(context, 'Media prioridad', media, AppColors.mediumPriority),
        if (baja.isNotEmpty)
          _section(context, 'Baja prioridad', baja, AppColors.lowPriority),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    List<TaskItem> items,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${items.length})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TaskCard(task: t, subject: subjectsById[t.subjectId]),
            )),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final Subject? subject;
  const TaskCard({super.key, required this.task, required this.subject});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM', 'es');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalleTareaScreen(taskId: task.id),
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
                      task.titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    df.format(task.fechaLimite),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              if (task.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  PriorityBadge(importancia: task.importancia),
                  if (subject != null)
                    SubjectBadge(
                      nombre: subject!.nombre,
                      color: subject!.color,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
