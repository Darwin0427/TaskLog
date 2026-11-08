import 'package:flutter/material.dart';

import '../models/task_reminder.dart';
import 'selectores_ios.dart';

/// Widget para seleccionar y configurar los recordatorios de una tarea.
///
/// Presenta 4 presets fijos como filas con checkbox (el día de, 1 día
/// antes, 3 días antes, 1 semana antes). Cuando un preset está activo,
/// muestra su hora (9:00 AM por defecto) y permite cambiarla con un
/// la rueda de hora de iOS (`elegirHora`).
///
/// Adicionalmente, permite agregar recordatorios personalizados con
/// cualquier número de días y cualquier hora vía un diálogo.
///
/// El widget es "controlado": recibe la lista actual (`value`) y notifica
/// cambios vía `onChanged`. Los recordatorios se ordenan automáticamente
/// de más lejano a más cercano al vencimiento.
class RecordatoriosSelector extends StatelessWidget {
  final List<TaskReminder> value;
  final ValueChanged<List<TaskReminder>> onChanged;

  const RecordatoriosSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  // Días de los 4 presets fijos. Cualquier otro valor se considera custom.
  static const List<int> _presetDays = <int>[0, 1, 3, 7];

  static const Map<int, String> _presetLabels = <int, String>{
    0: 'El día de',
    1: '1 día antes',
    3: '3 días antes',
    7: '1 semana antes',
  };

  // Valor pre-cargado de hora al activar un preset o agregar personalizado.
  static const int _defaultHora = 9;
  static const int _defaultMinuto = 0;

  // ─────────────────────────── helpers ───────────────────────────

  TaskReminder? _reminderFor(int dias) {
    for (final r in value) {
      if (r.diasAntes == dias) return r;
    }
    return null;
  }

  List<TaskReminder> get _customs =>
      value.where((r) => !_presetDays.contains(r.diasAntes)).toList();

  void _sort(List<TaskReminder> list) {
    list.sort((a, b) => b.diasAntes.compareTo(a.diasAntes));
  }

  void _togglePreset(int dias) {
    final list = List<TaskReminder>.from(value);
    if (list.any((r) => r.diasAntes == dias)) {
      list.removeWhere((r) => r.diasAntes == dias);
    } else {
      list.add(TaskReminder(
        diasAntes: dias,
        hora: _defaultHora,
        minuto: _defaultMinuto,
      ));
      _sort(list);
    }
    onChanged(list);
  }

  void _updateHora(TaskReminder r, TimeOfDay picked) {
    final list = List<TaskReminder>.from(value);
    final idx = list.indexWhere((x) => x.diasAntes == r.diasAntes);
    if (idx == -1) return;
    list[idx] = r.copyWith(hora: picked.hour, minuto: picked.minute);
    onChanged(list);
  }

  void _removeCustom(TaskReminder r) {
    final list = List<TaskReminder>.from(value)
      ..removeWhere((x) => x.diasAntes == r.diasAntes);
    onChanged(list);
  }

  Future<void> _editHora(BuildContext context, TaskReminder r) async {
    final picked = await elegirHora(
      context,
      inicial: TimeOfDay(hour: r.hora, minute: r.minuto),
      titulo: 'Hora del recordatorio',
    );
    if (picked != null) _updateHora(r, picked);
  }

  Future<void> _addCustom(BuildContext context) async {
    final result = await showAddReminderDialog(context);
    if (result == null) return;
    // Si ya existía un recordatorio con esa cantidad de días, lo reemplazamos.
    final list = List<TaskReminder>.from(value)
      ..removeWhere((r) => r.diasAntes == result.diasAntes)
      ..add(result);
    _sort(list);
    onChanged(list);
  }

  // ─────────────────────────── build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final customs = _customs;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card con las 4 filas de presets.
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < _presetDays.length; i++) ...[
                _PresetRow(
                  dias: _presetDays[i],
                  label: _presetLabels[_presetDays[i]]!,
                  reminder: _reminderFor(_presetDays[i]),
                  onToggle: () => _togglePreset(_presetDays[i]),
                  onEditHora: (r) => _editHora(context, r),
                ),
                if (i < _presetDays.length - 1)
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

        // Card con los personalizados (si hay).
        if (customs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Personalizados',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < customs.length; i++) ...[
                  _CustomRow(
                    reminder: customs[i],
                    onEditHora: (r) => _editHora(context, r),
                    onRemove: () => _removeCustom(customs[i]),
                  ),
                  if (i < customs.length - 1)
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
        ],

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addCustom(context),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Agregar recordatorio'),
          ),
        ),
      ],
    );
  }
}

/// Fila de un preset (checkbox + label + botón de hora opcional).
class _PresetRow extends StatelessWidget {
  final int dias;
  final String label;
  final TaskReminder? reminder;
  final VoidCallback onToggle;
  final ValueChanged<TaskReminder> onEditHora;

  const _PresetRow({
    required this.dias,
    required this.label,
    required this.reminder,
    required this.onToggle,
    required this.onEditHora,
  });

  @override
  Widget build(BuildContext context) {
    final selected = reminder != null;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (selected)
              TextButton.icon(
                onPressed: () => onEditHora(reminder!),
                icon: const Icon(Icons.access_time_outlined, size: 18),
                label: Text(reminder!.labelHora),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila de un recordatorio personalizado (nombre + hora + eliminar).
class _CustomRow extends StatelessWidget {
  final TaskReminder reminder;
  final ValueChanged<TaskReminder> onEditHora;
  final VoidCallback onRemove;

  const _CustomRow({
    required this.reminder,
    required this.onEditHora,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder.labelRelativo,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          TextButton.icon(
            onPressed: () => onEditHora(reminder),
            icon: const Icon(Icons.access_time_outlined, size: 18),
            label: Text(reminder.labelHora),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Eliminar',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Diálogo para agregar un recordatorio con cantidad de días y hora
/// arbitrarias. Retorna el `TaskReminder` resultante o `null` si el
/// usuario cancela. Público para poder reusarse desde otras pantallas
/// (por ejemplo, el detalle de tarea en la Fase 5).
Future<TaskReminder?> showAddReminderDialog(BuildContext context) {
  final daysCtrl = TextEditingController();
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  String? error;

  return showDialog<TaskReminder>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Nuevo recordatorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cuántos días antes',
                  hintText: 'Ej: 2, 5, 14',
                  helperText: '0 = el mismo día del vencimiento',
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
              ),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final picked = await elegirHora(
                    ctx,
                    inicial: time,
                    titulo: 'Hora del recordatorio',
                  );
                  if (picked != null) setState(() => time = picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hora'),
                            Text(
                              _fmtTime(time),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(ctx).colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final dias = int.tryParse(daysCtrl.text.trim());
                if (dias == null || dias < 0 || dias > 365) {
                  setState(() =>
                      error = 'Ingresa un número entre 0 y 365');
                  return;
                }
                Navigator.of(dialogCtx).pop(TaskReminder(
                  diasAntes: dias,
                  hora: time.hour,
                  minuto: time.minute,
                ));
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    ),
  );
}

String _fmtTime(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
