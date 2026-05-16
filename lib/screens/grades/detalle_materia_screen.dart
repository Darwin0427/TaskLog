import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grade_item.dart';
import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../forms/crear_grade_item_screen.dart';
import '../forms/crear_nota_screen.dart';
import '../forms/crear_tarea_screen.dart';
import '../tasks/detalle_tarea_screen.dart';

class DetalleMateriaScreen extends StatelessWidget {
  final Subject subject;
  const DetalleMateriaScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(subject.icon, color: subject.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.nombre,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: subject.color,
            labelColor: subject.color,
            tabs: const [
              Tab(text: 'Notas'),
              Tab(text: 'Tareas'),
              Tab(text: 'Notas del curso'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotasTab(subject: subject),
            _TareasTab(subject: subject),
            _GradeItemsTab(subject: subject),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Tab Notas
// ──────────────────────────────────────────────────────────────────
class _NotasTab extends StatelessWidget {
  final Subject subject;
  const _NotasTab({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<Note>>(
          stream: FirestoreService.instance.watchNotesBySubject(subject.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = snap.data ?? const <Note>[];
            if (notes.isEmpty) {
              return const EmptyState(
                icon: Icons.note_outlined,
                title: 'No hay notas en esta materia',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = notes[i];
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
                                n.titulo,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            PriorityBadge(
                              importancia: n.importancia,
                              small: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          n.contenido,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_notas_${subject.id}',
            backgroundColor: subject.color,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CrearNotaScreen(defaultSubjectId: subject.id),
              ),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Tab Tareas
// ──────────────────────────────────────────────────────────────────
class _TareasTab extends StatelessWidget {
  final Subject subject;
  const _TareasTab({required this.subject});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM', 'es');
    return Stack(
      children: [
        StreamBuilder<List<TaskItem>>(
          stream:
              FirestoreService.instance.watchTasksBySubject(subject.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final tasks = snap.data ?? const <TaskItem>[];
            if (tasks.isEmpty) {
              return const EmptyState(
                icon: Icons.task_alt_outlined,
                title: 'No hay tareas en esta materia',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = tasks[i];
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      t.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          PriorityBadge(
                            importancia: t.importancia,
                            small: true,
                          ),
                          const SizedBox(width: 8),
                          Text(df.format(t.fechaLimite)),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetalleTareaScreen(taskId: t.id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_tareas_${subject.id}',
            backgroundColor: subject.color,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CrearTareaScreen(defaultSubjectId: subject.id),
              ),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Tab Notas del curso (gradeItems)
// ──────────────────────────────────────────────────────────────────
class _GradeItemsTab extends StatelessWidget {
  final Subject subject;
  const _GradeItemsTab({required this.subject});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GradeItem>>(
      stream:
          FirestoreService.instance.watchGradeItemsBySubject(subject.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <GradeItem>[];
        final acumulado = items
            .where((e) => e.nota != null)
            .fold<double>(
                0, (a, e) => a + (e.nota! * e.porcentaje / 100.0));
        final evaluados = items.where((e) => e.nota != null).toList();
        final promedio = evaluados.isEmpty
            ? 0.0
            : evaluados.fold<double>(0, (a, e) => a + e.nota!) /
                evaluados.length;

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: items.isEmpty
                      ? const EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No hay ítems evaluativos',
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final it = items[i];
                            return Card(
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                title: Text(
                                  it.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${it.porcentaje.toStringAsFixed(0)}% del curso',
                                ),
                                trailing: Text(
                                  it.nota == null
                                      ? '—'
                                      : it.nota!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: it.nota == null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : subject.color,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: subject.color.withValues(alpha: 0.08),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 76),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Acumulado',
                          value: acumulado.toStringAsFixed(2),
                          color: subject.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Promedio actual',
                          value:
                              '${promedio.toStringAsFixed(1)} / 5.0',
                          color: subject.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_grade_${subject.id}',
                backgroundColor: subject.color,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CrearGradeItemScreen(subject: subject),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Ítem',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
