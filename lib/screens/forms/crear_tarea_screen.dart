import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task_item.dart';
import '../../models/task_reminder.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/grade_item_chips_selector.dart';
import '../../widgets/importancia_selector.dart';
import '../../widgets/subject_chips_selector.dart';
import 'seleccionar_recordatorios_screen.dart';

class CrearTareaScreen extends StatefulWidget {
  /// Si se pasa, edita una tarea existente. Si es null, crea una nueva.
  final TaskItem? existing;

  /// Materia preseleccionada al crear (ignorado en modo edición).
  final String? defaultSubjectId;

  const CrearTareaScreen({
    super.key,
    this.existing,
    this.defaultSubjectId,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearTareaScreen> createState() => _CrearTareaScreenState();
}

class _CrearTareaScreenState extends State<CrearTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _notaCtrl;

  String? _subjectId;
  String? _gradeItemId;
  String _importancia = 'Media';
  DateTime? _fechaLimite;
  List<TaskReminder> _recordatorios = const <TaskReminder>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _descCtrl = TextEditingController(text: e?.descripcion ?? '');
    _notaCtrl = TextEditingController(
      text: e?.nota?.toStringAsFixed(1) ?? '',
    );
    _subjectId = e?.subjectId ?? widget.defaultSubjectId;
    _gradeItemId = e?.gradeItemId;
    _importancia = e?.importancia ?? 'Media';
    _fechaLimite = e?.fechaLimite;
    // Al crear una tarea nueva, aplicamos los defaults según importancia.
    // Al editar, respetamos los que el usuario tenía configurados.
    _recordatorios = e != null
        ? List<TaskReminder>.from(e.recordatorios)
        : _defaultRecordatoriosFor(_importancia);
  }

  /// Recordatorios por defecto para una tarea nueva, según su importancia.
  /// Todos a las 9:00 AM.
  static List<TaskReminder> _defaultRecordatoriosFor(String importancia) {
    const hora = 9;
    const minuto = 0;
    List<int> dias;
    switch (importancia) {
      case 'Alta':
        dias = <int>[7, 3, 1, 0];
        break;
      case 'Baja':
        dias = <int>[0];
        break;
      case 'Media':
      default:
        dias = <int>[3, 1];
    }
    return dias
        .map((d) => TaskReminder(
              diasAntes: d,
              hora: hora,
              minuto: minuto,
            ))
        .toList();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  void _onSubjectChanged(String? id) {
    setState(() {
      _subjectId = id;
      // Al cambiar materia, ya no tiene sentido el grade item anterior.
      _gradeItemId = null;
      _notaCtrl.clear();
    });
  }

  void _onGradeItemChanged(String? id) {
    setState(() {
      _gradeItemId = id;
      if (id == null) _notaCtrl.clear();
    });
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fechaLimite = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una materia')),
      );
      return;
    }
    if (_fechaLimite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha límite')),
      );
      return;
    }

    // Validar la nota si está vinculada a un grade item.
    double? nota;
    if (_gradeItemId != null) {
      final notaRaw = _notaCtrl.text.replaceAll(',', '.').trim();
      if (notaRaw.isNotEmpty) {
        nota = double.tryParse(notaRaw);
        if (nota == null || nota < 0 || nota > 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La nota debe estar entre 0 y 5')),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final task = TaskItem(
        id: widget.existing?.id ?? '',
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        subjectId: _subjectId!,
        importancia: _importancia,
        fechaLimite: _fechaLimite!,
        completada: widget.existing?.completada ?? false,
        completadaEn: widget.existing?.completadaEn,
        gradeItemId: _gradeItemId,
        nota: nota,
        recordatorios: _recordatorios,
      );
      if (widget.isEditing) {
        await FirestoreService.instance.updateTask(widget.existing!.id, task);
      } else {
        await FirestoreService.instance.addTask(task);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("EEEE d 'de' MMMM, yyyy", 'es');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar tarea' : 'Nueva tarea'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            _Label('Materia *'),
            const SizedBox(height: 8),
            SubjectChipsSelector(
              selectedId: _subjectId,
              onChanged: _onSubjectChanged,
            ),
            const SizedBox(height: 24),
            _Label('Importancia *'),
            const SizedBox(height: 8),
            Center(
              child: ImportanciaSelector(
                value: _importancia,
                onChanged: (v) => setState(() => _importancia = v),
              ),
            ),
            const SizedBox(height: 24),
            _Label('Fecha límite *'),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.event),
                title: Text(
                  _fechaLimite == null
                      ? 'Seleccionar fecha'
                      : df.format(_fechaLimite!),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickFecha,
              ),
            ),
            const SizedBox(height: 24),
            _Label('Recordatorios'),
            const SizedBox(height: 8),
            _RecordatoriosCardCompact(
              count: _recordatorios.length,
              onTap: () async {
                final result = await Navigator.of(context)
                    .push<List<TaskReminder>>(
                  MaterialPageRoute(
                    builder: (_) => SeleccionarRecordatoriosScreen(
                      initial: _recordatorios,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _recordatorios = result);
                }
              },
            ),
            const SizedBox(height: 24),
            _Label('Vincular a una calificación (opcional)'),
            const SizedBox(height: 4),
            Text(
              'Si esta tarea ES una calificación de la materia (un parcial, un proyecto, etc.), vincúlala aquí. La nota de la tarea se usará como nota de esa calificación.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            GradeItemChipsSelector(
              subjectId: _subjectId,
              selectedGradeItemId: _gradeItemId,
              currentTaskId: widget.existing?.id,
              onChanged: _onGradeItemChanged,
            ),
            if (_gradeItemId != null) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _notaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Nota de la calificación (opcional)',
                  hintText: '0.0 a 5.0',
                  helperText:
                      'Deja vacío si aún no tienes la calificación. Puedes editarla después.',
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label:
                  Text(widget.isEditing ? 'Guardar cambios' : 'Guardar tarea'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  // ignore: unused_element_parameter
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
}

/// Card compacta que aparece en el formulario para indicar cuántos
/// recordatorios están configurados y abrir la pantalla de selección.
/// Sigue el mismo patrón que el card del detalle de tarea.
class _RecordatoriosCardCompact extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _RecordatoriosCardCompact({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = count == 0
        ? 'Ninguno configurado'
        : '$count ${count == 1 ? "configurado" : "configurados"}';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toca para configurar antes del vencimiento',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
