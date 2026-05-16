import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class CrearMateriaScreen extends StatefulWidget {
  const CrearMateriaScreen({super.key});

  @override
  State<CrearMateriaScreen> createState() => _CrearMateriaScreenState();
}

class _CrearMateriaScreenState extends State<CrearMateriaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  Color _color = AppColors.subjectPalette.first;
  String _iconName = 'book';
  bool _saving = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final subject = Subject(
        id: '',
        nombre: _nombreCtrl.text.trim(),
        colorHex: AppColors.toHex(_color),
        iconName: _iconName,
      );
      await FirestoreService.instance.addSubject(subject);
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
      appBar: AppBar(title: const Text('Nueva materia')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Preview
            Card(
              color: _color.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppIcons.byName(_iconName),
                        color: _color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _nombreCtrl.text.trim().isEmpty
                            ? 'Vista previa'
                            : _nombreCtrl.text.trim(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: _color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej. Cálculo, Programación...',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),
            _Label('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColors.subjectPalette.map((c) {
                final selected = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _Label('Ícono'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppIcons.all.entries.map((e) {
                final selected = e.key == _iconName;
                return GestureDetector(
                  onTap: () => setState(() => _iconName = e.key),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? _color.withValues(alpha: 0.2)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      e.value,
                      color: selected
                          ? _color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                );
              }).toList(),
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
              label: const Text('Crear materia'),
              style: FilledButton.styleFrom(
                backgroundColor: _color,
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
