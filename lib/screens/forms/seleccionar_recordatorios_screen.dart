import 'package:flutter/material.dart';

import '../../models/task_reminder.dart';
import '../../widgets/recordatorios_selector.dart';

/// Pantalla dedicada para configurar la lista de recordatorios de una
/// tarea en creación o edición.
///
/// A diferencia de `GestionRecordatoriosScreen` (que actúa sobre una tarea
/// ya persistida en Firestore), esta pantalla trabaja con una lista local
/// que se retorna al formulario padre cuando el usuario vuelve atrás.
///
/// Uso:
/// ```dart
/// final resultado = await Navigator.of(context).push<List<TaskReminder>>(
///   MaterialPageRoute(
///     builder: (_) => SeleccionarRecordatoriosScreen(initial: _recordatorios),
///   ),
/// );
/// if (resultado != null) setState(() => _recordatorios = resultado);
/// ```
class SeleccionarRecordatoriosScreen extends StatefulWidget {
  final List<TaskReminder> initial;
  const SeleccionarRecordatoriosScreen({
    super.key,
    required this.initial,
  });

  @override
  State<SeleccionarRecordatoriosScreen> createState() =>
      _SeleccionarRecordatoriosScreenState();
}

class _SeleccionarRecordatoriosScreenState
    extends State<SeleccionarRecordatoriosScreen> {
  late List<TaskReminder> _list;

  @override
  void initState() {
    super.initState();
    _list = List<TaskReminder>.from(widget.initial);
  }

  void _saveAndPop() {
    Navigator.of(context).pop(_list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Interceptamos el back para retornar la lista actualizada al padre.
    return PopScope<List<TaskReminder>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _saveAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recordatorios'),
          actions: [
            IconButton(
              tooltip: 'Listo',
              icon: const Icon(Icons.check),
              onPressed: _saveAndPop,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Se avisará automáticamente antes del vencimiento. Puedes activar los presets o crear recordatorios personalizados.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            RecordatoriosSelector(
              value: _list,
              onChanged: (l) => setState(() => _list = l),
            ),
          ],
        ),
      ),
    );
  }
}
