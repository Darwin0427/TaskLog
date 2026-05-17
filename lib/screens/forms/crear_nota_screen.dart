import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/importancia_selector.dart';
import '../../widgets/subject_chips_selector.dart';
import '../../widgets/task_chips_selector.dart';

class CrearNotaScreen extends StatefulWidget {
  /// Si se pasa, edita una nota existente. Si es null, crea una nueva.
  final Note? existing;

  /// Materia preseleccionada al crear (ignorado en edición).
  final String? defaultSubjectId;

  /// Tarea preseleccionada al crear. En modo edición se ignora y usamos
  /// el taskId actual de la nota.
  final String? taskId;

  const CrearNotaScreen({
    super.key,
    this.existing,
    this.defaultSubjectId,
    this.taskId,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearNotaScreen> createState() => _CrearNotaScreenState();
}

class _CrearNotaScreenState extends State<CrearNotaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _contenidoCtrl;

  String? _subjectId;
  String? _taskId;
  String _importancia = 'Media';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _contenidoCtrl = TextEditingController(text: e?.contenido ?? '');
    _subjectId = e?.subjectId ?? widget.defaultSubjectId;
    _taskId = e?.taskId ?? widget.taskId;
    _importancia = e?.importancia ?? 'Media';
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  void _onSubjectChanged(String? id) {
    setState(() {
      _subjectId = id;
      // Si la tarea seleccionada ya no pertenece a esta materia, la
      // desvinculamos. La validación real ocurre al guardar mediante el
      // re-render del selector — aquí solo limpiamos para evitar inconsistencia.
      _taskId = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una materia')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final note = Note(
        id: widget.existing?.id ?? '',
        titulo: _tituloCtrl.text.trim(),
        contenido: _contenidoCtrl.text.trim(),
        subjectId: _subjectId!,
        importancia: _importancia,
        taskId: _taskId,
      );
      if (widget.isEditing) {
        await FirestoreService.instance.updateNote(widget.existing!.id, note);
      } else {
        await FirestoreService.instance.addNote(note);
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
    String titleText;
    if (widget.isEditing) {
      titleText = 'Editar nota';
    } else if (widget.taskId != null) {
      titleText = 'Nueva nota para tarea';
    } else {
      titleText = 'Nueva nota';
    }

    // Si la nota viene "forzada" desde el detalle de una tarea (taskId
    // pasado al constructor en modo crear), bloqueamos el selector para
    // evitar que la cambie por accidente.
    final taskLocked = !widget.isEditing && widget.taskId != null;

    return Scaffold(
      appBar: AppBar(title: Text(titleText)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contenidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Contenido *',
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
            Row(
              children: [
                _Label('Vincular a tarea (opcional)'),
                if (taskLocked) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline, size: 14),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (taskLocked)
              // Caso especial: el usuario entró a este formulario desde el
              // detalle de una tarea concreta — no le dejamos cambiarla.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta nota se vinculará a la tarea actual',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            else
              TaskChipsSelector(
                subjectId: _subjectId,
                selectedTaskId: _taskId,
                onChanged: (id) => setState(() => _taskId = id),
              ),
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
              label: Text(widget.isEditing ? 'Guardar cambios' : 'Guardar nota'),
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
