import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task_item.dart';
import '../../models/task_reminder.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/recordatorios_selector.dart';

/// Pantalla dedicada para gestionar los recordatorios programados de una
/// tarea concreta. Se abre desde el detalle de la tarea vía tap en la card
/// "Recordatorios".
///
/// Presenta:
/// - Header con título de la tarea y fecha límite.
/// - Lista de recordatorios, cada uno con fecha calculada, descripción
///   relativa y botón para eliminar.
/// - Botón "Agregar recordatorio" que abre el mismo diálogo del formulario.
class GestionRecordatoriosScreen extends StatelessWidget {
  final String taskId;
  const GestionRecordatoriosScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
      ),
      body: StreamBuilder<TaskItem?>(
        stream: FirestoreService.instance.watchTask(taskId),
        builder: (context, snap) {
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
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final TaskItem task;
  const _Body({required this.task});

  Future<void> _removeReminder(BuildContext context, TaskReminder r) async {
    final newList =
        task.recordatorios.where((x) => x.diasAntes != r.diasAntes).toList();
    try {
      await FirestoreService.instance.updateTask(
        task.id,
        task.copyWith(recordatorios: newList),
      );
      if (context.mounted) {
        showSuccessSnackBar(context, 'Recordatorio eliminado.');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _addReminder(BuildContext context) async {
    final result = await showAddReminderDialog(context);
    if (result == null) return;
    if (!context.mounted) return;
    // Si ya existe uno con esa cantidad de días, se reemplaza.
    final newList = List<TaskReminder>.from(task.recordatorios)
      ..removeWhere((r) => r.diasAntes == result.diasAntes)
      ..add(result)
      ..sort((a, b) => b.diasAntes.compareTo(a.diasAntes));
    try {
      await FirestoreService.instance.updateTask(
        task.id,
        task.copyWith(recordatorios: newList),
      );
      if (context.mounted) {
        showSuccessSnackBar(context, 'Recordatorio agregado.');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dfDate = DateFormat("d 'de' MMM", 'es');
    final dfHeader = DateFormat("EEEE d 'de' MMMM", 'es');
    // Copia ordenada de más lejano a más cercano al vencimiento.
    final reminders = List<TaskReminder>.from(task.recordatorios)
      ..sort((a, b) => b.diasAntes.compareTo(a.diasAntes));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Header contextual: recuerda al usuario de qué tarea son estos
        // recordatorios y cuándo vence.
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.titulo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Vence ${dfHeader.format(task.fechaLimite)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Lista de recordatorios
        if (reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin recordatorios programados',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca "Agregar" para crear el primero.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < reminders.length; i++) ...[
                  _ReminderRow(
                    reminder: reminders[i],
                    fechaAbsoluta:
                        reminders[i].resolverFecha(task.fechaLimite),
                    formatter: dfDate,
                    onDelete: () => _removeReminder(context, reminders[i]),
                  ),
                  if (i < reminders.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Botón para agregar
        FilledButton.tonalIcon(
          onPressed: () => _addReminder(context),
          icon: const Icon(Icons.add),
          label: const Text('Agregar recordatorio'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Fila individual de un recordatorio: ícono + fecha absoluta + descripción
/// relativa + botón para eliminar.
class _ReminderRow extends StatelessWidget {
  final TaskReminder reminder;
  final DateTime fechaAbsoluta;
  final DateFormat formatter;
  final VoidCallback onDelete;

  const _ReminderRow({
    required this.reminder,
    required this.fechaAbsoluta,
    required this.formatter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fechaTexto =
        '${formatter.format(fechaAbsoluta)}, ${reminder.labelHora}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fechaTexto,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  reminder.labelRelativo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Eliminar recordatorio',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
