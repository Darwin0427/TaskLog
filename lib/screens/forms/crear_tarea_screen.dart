import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../widgets/importancia_selector.dart';
import '../../widgets/subject_chips_selector.dart';

class CrearTareaScreen extends StatefulWidget {
  final String? defaultSubjectId;
  const CrearTareaScreen({super.key, this.defaultSubjectId});

  @override
  State<CrearTareaScreen> createState() => _CrearTareaScreenState();
}

class _CrearTareaScreenState extends State<CrearTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _subjectId;
  String _importancia = 'Media';
  DateTime? _fechaLimite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.defaultSubjectId;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
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

    setState(() => _saving = true);
    try {
      final task = TaskItem(
        id: '',
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        subjectId: _subjectId!,
        importancia: _importancia,
        fechaLimite: _fechaLimite!,
      );
      await FirestoreService.instance.addTask(task);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("EEEE d 'de' MMMM, yyyy", 'es');
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva tarea')),
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
              onChanged: (id) => setState(() => _subjectId = id),
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
              label: const Text('Guardar tarea'),
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
