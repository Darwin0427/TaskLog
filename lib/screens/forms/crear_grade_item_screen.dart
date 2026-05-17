import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_messages.dart';

class CrearGradeItemScreen extends StatefulWidget {
  final Subject subject;

  /// Si se pasa, edita un grade item existente. Si es null, crea uno nuevo.
  final GradeItem? existing;

  const CrearGradeItemScreen({
    super.key,
    required this.subject,
    this.existing,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearGradeItemScreen> createState() => _CrearGradeItemScreenState();
}

class _CrearGradeItemScreenState extends State<CrearGradeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _porcentajeCtrl;
  late final TextEditingController _notaCtrl;

  /// Porcentaje ya consumido por OTROS items (excluyendo el actual si estamos
  /// editando).
  double _usadoExcluyendoActual = 0;
  bool _loadingUsado = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombreCtrl = TextEditingController(text: e?.nombre ?? '');
    _porcentajeCtrl = TextEditingController(
      text: e == null ? '' : e.porcentaje.toStringAsFixed(0),
    );
    _notaCtrl = TextEditingController(
      text: e?.nota == null ? '' : e!.nota!.toStringAsFixed(1),
    );
    _porcentajeCtrl.addListener(() => setState(() {}));
    _cargarPorcentajeUsado();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _porcentajeCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPorcentajeUsado() async {
    try {
      final items = await FirestoreService.instance
          .getGradeItemsBySubject(widget.subject.id);
      double suma = 0;
      for (final it in items) {
        // En modo editar, excluimos el item actual del cálculo del disponible.
        if (widget.isEditing && it.id == widget.existing!.id) continue;
        suma += it.porcentaje;
      }
      if (mounted) {
        setState(() {
          _usadoExcluyendoActual = suma;
          _loadingUsado = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsado = false);
    }
  }

  double get _porcentajeIngresado {
    final s = _porcentajeCtrl.text.replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  double get _disponible =>
      (100 - _usadoExcluyendoActual).clamp(0, 100).toDouble();

  double get _restanteTrasGuardar => _disponible - _porcentajeIngresado;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _porcentajeIngresado;
    if (p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El porcentaje debe ser mayor a 0')),
      );
      return;
    }
    if (_usadoExcluyendoActual + p > 100.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El total superaría el 100%. Disponible: ${_disponible.toStringAsFixed(1)}%',
          ),
        ),
      );
      return;
    }

    double? nota;
    if (_notaCtrl.text.trim().isNotEmpty) {
      nota = double.tryParse(_notaCtrl.text.replaceAll(',', '.'));
      if (nota == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La nota no es un número válido')),
        );
        return;
      }
      if (nota < 0 || nota > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La nota debe estar entre 0 y 5')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final item = GradeItem(
        id: widget.existing?.id ?? '',
        subjectId: widget.subject.id,
        nombre: _nombreCtrl.text.trim(),
        porcentaje: p,
        nota: nota,
      );
      if (widget.isEditing) {
        await FirestoreService.instance
            .updateGradeItem(widget.existing!.id, item);
      } else {
        await FirestoreService.instance.addGradeItem(item);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    if (!widget.isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ítem?'),
        content: Text(
          'Se eliminará "${widget.existing!.nombre}". Esta acción no se puede deshacer.',
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
    if (!mounted) return;
    try {
      await FirestoreService.instance.deleteGradeItem(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.subject.color;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar ítem' : 'Nuevo ítem evaluativo'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: color.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(widget.subject.icon, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.subject.nombre,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_loadingUsado)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        'Disponible: ${_disponible.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del ítem *',
                hintText: 'Ej. Parcial 1, Proyecto final',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _porcentajeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Porcentaje *',
                suffixText: '%',
                helperText: _loadingUsado
                    ? null
                    : _porcentajeIngresado > 0
                        ? 'Quedarían ${_restanteTrasGuardar.toStringAsFixed(1)}% disponibles'
                        : 'Hay ${_disponible.toStringAsFixed(1)}% disponibles',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final d = double.tryParse(v.replaceAll(',', '.'));
                if (d == null) return 'Número inválido';
                if (d <= 0 || d > 100) return 'Debe ser entre 0 y 100';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nota obtenida (opcional)',
                hintText: '0.0 a 5.0',
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving || _loadingUsado ? null : _submit,
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
              label: Text(
                widget.isEditing ? 'Guardar cambios' : 'Guardar ítem',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
