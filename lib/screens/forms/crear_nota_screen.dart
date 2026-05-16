import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/firestore_service.dart';
import '../../widgets/importancia_selector.dart';
import '../../widgets/subject_chips_selector.dart';

class CrearNotaScreen extends StatefulWidget {
  final String? defaultSubjectId;
  final String? taskId;
  const CrearNotaScreen({super.key, this.defaultSubjectId, this.taskId});

  @override
  State<CrearNotaScreen> createState() => _CrearNotaScreenState();
}

class _CrearNotaScreenState extends State<CrearNotaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();

  String? _subjectId;
  String _importancia = 'Media';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.defaultSubjectId;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
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
        id: '',
        titulo: _tituloCtrl.text.trim(),
        contenido: _contenidoCtrl.text.trim(),
        subjectId: _subjectId!,
        importancia: _importancia,
        taskId: widget.taskId,
      );
      await FirestoreService.instance.addNote(note);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null
            ? 'Nueva nota'
            : 'Nueva nota para tarea'),
      ),
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
              label: const Text('Guardar nota'),
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
