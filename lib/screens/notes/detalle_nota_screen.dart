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
import '../tasks/detalle_tarea_screen.dart';

class DetalleNotaScreen extends StatelessWidget {
  final String noteId;
  const DetalleNotaScreen({super.key, required this.noteId});

  Future<void> _confirmAndDelete(BuildContext context, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar nota?'),
        content: Text(
          'Se eliminará "${note.titulo}". Esta acción no se puede deshacer.',
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
      await FirestoreService.instance.deleteNote(note.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Note?>(
      stream: FirestoreService.instance.watchNote(noteId),
      builder: (context, snap) {
        final note = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nota'),
            actions: note == null
                ? null
                : [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CrearNotaScreen(existing: note),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmAndDelete(context, note),
                    ),
                  ],
          ),
          body: _buildBody(context, snap),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<Note?> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final note = snap.data;
    if (note == null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Nota no encontrada',
      );
    }
    return _Body(note: note);
  }
}

class _Body extends StatelessWidget {
  final Note note;
  const _Body({required this.note});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("d 'de' MMMM, yyyy 'a las' HH:mm", 'es');
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, subjSnap) {
        Subject? subject;
        for (final s in (subjSnap.data ?? const <Subject>[])) {
          if (s.id == note.subjectId) {
            subject = s;
            break;
          }
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              note.titulo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                PriorityBadge(importancia: note.importancia),
                if (subject != null)
                  SubjectBadge(
                    nombre: subject.nombre,
                    color: subject.color,
                  ),
              ],
            ),
            if (note.creadoEn != null) ...[
              const SizedBox(height: 12),
              Text(
                'Creada el ${df.format(note.creadoEn!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                note.contenido,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (note.taskId != null) ...[
              const SizedBox(height: 24),
              Text(
                'Vinculada a una tarea',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              _LinkedTaskCard(taskId: note.taskId!),
            ],
          ],
        );
      },
    );
  }
}

class _LinkedTaskCard extends StatelessWidget {
  final String taskId;
  const _LinkedTaskCard({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskItem?>(
      future: FirestoreService.instance.getTask(taskId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final task = snap.data;
        if (task == null) {
          return Text(
            'La tarea asociada ya no existe.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        final df = DateFormat('dd MMM', 'es');
        return Card(
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: const Icon(Icons.task_alt),
            title: Text(
              task.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Vence ${df.format(task.fechaLimite)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalleTareaScreen(taskId: task.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
