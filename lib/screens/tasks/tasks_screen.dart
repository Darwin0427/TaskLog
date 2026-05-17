import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/animated_list_item.dart';
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
                return RefreshIndicator(
                  onRefresh: FirestoreService.instance.refreshFromServer,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.task_alt_outlined,
                        title: 'No tienes tareas',
                        subtitle:
                            'Toca el botón + para crear tu primera tarea.',
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: FirestoreService.instance.refreshFromServer,
                child: _GroupedTasksList(
                  tasks: tasks,
                  subjectsById: subjectsById,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupedTasksList extends StatefulWidget {
  final List<TaskItem> tasks;
  final Map<String, Subject> subjectsById;
  const _GroupedTasksList({
    required this.tasks,
    required this.subjectsById,
  });

  @override
  State<_GroupedTasksList> createState() => _GroupedTasksListState();
}

class _GroupedTasksListState extends State<_GroupedTasksList> {
  bool _completadasExpandidas = false;

  @override
  Widget build(BuildContext context) {
    final pendientes = widget.tasks.where((t) => !t.completada).toList();
    final completadas = widget.tasks.where((t) => t.completada).toList();

    final alta = pendientes.where((t) => t.importancia == 'Alta').toList();
    final media =
        pendientes.where((t) => t.importancia == 'Media').toList();
    final baja = pendientes.where((t) => t.importancia == 'Baja').toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (alta.isNotEmpty)
          _section(context, 'Alta prioridad', alta, AppColors.highPriority),
        if (media.isNotEmpty)
          _section(context, 'Media prioridad', media, AppColors.mediumPriority),
        if (baja.isNotEmpty)
          _section(context, 'Baja prioridad', baja, AppColors.lowPriority),
        if (pendientes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '¡Todas las tareas completadas! 🎉',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (completadas.isNotEmpty)
          _completadasSection(context, completadas),
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
              key: ValueKey('task_${t.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedListItem(
                child: TaskCard(
                  task: t,
                  subject: widget.subjectsById[t.subjectId],
                ),
              ),
            )),
      ],
    );
  }

  Widget _completadasSection(
      BuildContext context, List<TaskItem> completadas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(
              () => _completadasExpandidas = !_completadasExpandidas),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  _completadasExpandidas
                      ? Icons.expand_more
                      : Icons.chevron_right,
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  'Completadas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${completadas.length})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (_completadasExpandidas)
          ...completadas.map((t) => Padding(
                key: ValueKey('done_${t.id}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedListItem(
                  child: TaskCard(
                    task: t,
                    subject: widget.subjectsById[t.subjectId],
                  ),
                ),
              )),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final Subject? subject;
  const TaskCard({super.key, required this.task, required this.subject});

  Future<void> _toggleCompletada(BuildContext context) async {
    try {
      await FirestoreService.instance
          .setTaskCompletada(task.id, !task.completada);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM', 'es');
    final card = Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalleTareaScreen(taskId: task.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox circular para marcar completada
              GestureDetector(
                onTap: () => _toggleCompletada(context),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: Icon(
                    task.completada
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.completada
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.titulo,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: task.completada
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.completada
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : null,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          df.format(task.fechaLimite),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
            ],
          ),
        ),
      ),
    );
    // Suaviza visualmente las completadas.
    return Opacity(opacity: task.completada ? 0.6 : 1, child: card);
  }
}
