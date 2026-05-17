import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grade_item.dart';
import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/grade_calc.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/grade_item_card.dart';
import '../../widgets/nota_necesaria_card.dart';
import '../../widgets/priority_badge.dart';
import '../forms/crear_grade_item_screen.dart';
import '../forms/crear_materia_screen.dart';
import '../forms/crear_nota_screen.dart';
import '../forms/crear_tarea_screen.dart';
import '../notes/detalle_nota_screen.dart';
import '../tasks/detalle_tarea_screen.dart';

class DetalleMateriaScreen extends StatelessWidget {
  /// Recibimos la materia inicial pero la "viva" la obtenemos del stream
  /// para que la pantalla refleje ediciones inmediatamente.
  final Subject subject;
  const DetalleMateriaScreen({super.key, required this.subject});

  Future<void> _confirmAndDelete(BuildContext context, Subject sub) async {
    // Mostramos un loading mientras contamos los hijos.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final SubjectChildrenCount count;
    try {
      count =
          await FirestoreService.instance.countSubjectChildren(sub.id);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // cierra el loader
      if (context.mounted) showErrorSnackBar(context, e);
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cierra el loader

    if (!count.isEmpty) {
      // Hay hijos — bloquear el borrado.
      final partes = <String>[];
      if (count.tasks > 0) {
        partes.add('${count.tasks} tarea${count.tasks == 1 ? '' : 's'}');
      }
      if (count.notes > 0) {
        partes.add('${count.notes} nota${count.notes == 1 ? '' : 's'}');
      }
      if (count.gradeItems > 0) {
        partes.add(
          '${count.gradeItems} ítem${count.gradeItems == 1 ? '' : 's'} evaluativo${count.gradeItems == 1 ? '' : 's'}',
        );
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'Esta materia todavía tiene ${partes.join(', ')}. '
            'Elimínalos primero o muévelos a otra materia antes de borrar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Vacía — confirmar y borrar.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar materia?'),
        content: Text(
          'Se eliminará "${sub.nombre}". Esta acción no se puede deshacer.',
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
      await FirestoreService.instance.deleteSubject(sub.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, snap) {
        // Obtener versión actualizada de la materia (o fallback al inicial).
        Subject current = subject;
        bool stillExists = true;
        if (snap.hasData) {
          stillExists = false;
          for (final s in snap.data!) {
            if (s.id == subject.id) {
              current = s;
              stillExists = true;
              break;
            }
          }
        }

        if (snap.hasData && !stillExists) {
          // La materia fue borrada — salir.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(current.icon, color: current.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current.nombre,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Editar materia',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CrearMateriaScreen(existing: current),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar materia',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmAndDelete(context, current),
                ),
              ],
              bottom: TabBar(
                indicatorColor: current.color,
                labelColor: current.color,
                tabs: const [
                  Tab(text: 'Notas'),
                  Tab(text: 'Tareas'),
                  Tab(text: 'Notas del curso'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (current.hasExtraInfo) _SubjectInfoHeader(subject: current),
                Expanded(
                  child: TabBarView(
                    children: [
                      _NotasTab(subject: current),
                      _TareasTab(subject: current),
                      _GradeItemsTab(subject: current),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                return AnimatedListItem(
                  key: ValueKey('note_${n.id}'),
                  child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetalleNotaScreen(noteId: n.id),
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
                return AnimatedListItem(
                  key: ValueKey('mtask_${t.id}'),
                  child: Opacity(
                  opacity: t.completada ? 0.6 : 1,
                  child: Card(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: IconButton(
                        tooltip: t.completada
                            ? 'Marcar pendiente'
                            : 'Marcar completada',
                        icon: Icon(
                          t.completada
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: t.completada
                              ? subject.color
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                        onPressed: () async {
                          try {
                            await FirestoreService.instance
                                .setTaskCompletada(t.id, !t.completada);
                          } catch (e) {
                            if (context.mounted) {
                              showErrorSnackBar(context, e);
                            }
                          }
                        },
                      ),
                      title: Text(
                        t.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: t.completada
                              ? TextDecoration.lineThrough
                              : null,
                        ),
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
    // Combinamos dos streams: items evaluativos + tareas de la materia.
    // Con eso calculamos para cada item su nota efectiva (manual o
    // auto-calculada de sus sub-tareas).
    return StreamBuilder<List<GradeItem>>(
      stream:
          FirestoreService.instance.watchGradeItemsBySubject(subject.id),
      builder: (context, gradeSnap) {
        return StreamBuilder<List<TaskItem>>(
          stream:
              FirestoreService.instance.watchTasksBySubject(subject.id),
          builder: (context, tasksSnap) {
            if (gradeSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = gradeSnap.data ?? const <GradeItem>[];
            final allTasks = tasksSnap.data ?? const <TaskItem>[];

            // Mapea cada item a su nota efectiva (considerando sub-tareas).
            final notasEfectivas = <String, double?>{};
            for (final it in items) {
              final subs = allTasks
                  .where((t) => t.gradeItemId == it.id)
                  .toList();
              notasEfectivas[it.id] =
                  computeGradeItemNota(item: it, subTareas: subs).nota;
            }

            // Acumulado y promedio usan las notas efectivas.
            final acumulado = items.fold<double>(0, (a, e) {
              final n = notasEfectivas[e.id];
              if (n == null) return a;
              return a + (n * e.porcentaje / 100.0);
            });
            final evaluados =
                items.where((e) => notasEfectivas[e.id] != null).toList();
            final promedio = evaluados.isEmpty
                ? 0.0
                : evaluados.fold<double>(
                        0, (a, e) => a + notasEfectivas[e.id]!) /
                    evaluados.length;

            // Para NotaNecesariaCard pasamos los grade items con las notas
            // efectivas inyectadas (clonamos a un GradeItem nuevo).
            final itemsConNotaEfectiva = items.map((it) {
              return GradeItem(
                id: it.id,
                subjectId: it.subjectId,
                nombre: it.nombre,
                porcentaje: it.porcentaje,
                nota: notasEfectivas[it.id],
                creadoEn: it.creadoEn,
              );
            }).toList();

            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: items.isEmpty
                          ? const EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No hay ítems evaluativos',
                              subtitle:
                                  'Toca el botón "Ítem" para agregar tu primer ítem.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 12),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final it = items[i];
                                return AnimatedListItem(
                                  key: ValueKey('gi_${it.id}'),
                                  child: GradeItemCard(
                                    item: it,
                                    subject: subject,
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
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 76),
                      child: Column(
                        children: [
                          Row(
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
                          const SizedBox(height: 4),
                          NotaNecesariaCard(
                            items: itemsConNotaEfectiva,
                            color: subject.color,
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
      },
    );
  }
}

class _SubjectInfoHeader extends StatelessWidget {
  final Subject subject;
  const _SubjectInfoHeader({required this.subject});

  @override
  Widget build(BuildContext context) {
    final entries = <Widget>[];
    if (subject.profesor != null && subject.profesor!.isNotEmpty) {
      entries.add(_InfoChip(
        icon: Icons.person_outline,
        text: subject.profesor!,
        color: subject.color,
      ));
    }
    if (subject.aula != null && subject.aula!.isNotEmpty) {
      entries.add(_InfoChip(
        icon: Icons.meeting_room_outlined,
        text: subject.aula!,
        color: subject.color,
      ));
    }
    if (subject.classLinkUrl != null && subject.classLinkUrl!.isNotEmpty) {
      entries.add(_InfoChip(
        icon: Icons.videocam_outlined,
        text: 'Link de clase',
        color: subject.color,
        onTap: () {
          // Copia al portapapeles vía SelectableText sería overkill; en
          // versión inicial mostramos un dialog con el link completo.
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Link de clase'),
              content: SelectableText(subject.classLinkUrl!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        },
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: subject.color.withValues(alpha: 0.06),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: child,
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
