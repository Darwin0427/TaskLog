import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../services/firestore_service.dart';

class CrearGradeItemScreen extends StatefulWidget {
  final Subject subject;
  const CrearGradeItemScreen({super.key, required this.subject});

  @override
  State<CrearGradeItemScreen> createState() => _CrearGradeItemScreenState();
}

class _CrearGradeItemScreenState extends State<CrearGradeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _porcentajeCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  double _usado = 0;
  bool _loadingUsado = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
      final suma = items.fold<double>(0, (a, e) => a + e.porcentaje);
      if (mounted) {
        setState(() {
          _usado = suma;
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

  double get _disponible => (100 - _usado).clamp(0, 100);
  double get _restanteTrasGuardar =>
      _disponible - _porcentajeIngresado;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _porcentajeIngresado;
    if (p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El porcentaje debe ser mayor a 0')),
      );
      return;
    }
    if (_usado + p > 100.0001) {
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
        id: '',
        subjectId: widget.subject.id,
        nombre: _nombreCtrl.text.trim(),
        porcentaje: p,
        nota: nota,
      );
      await FirestoreService.instance.addGradeItem(item);
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
    final color = widget.subject.color;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ítem evaluativo')),
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
              label: const Text('Guardar ítem'),
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
