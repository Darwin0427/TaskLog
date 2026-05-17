import 'package:flutter/material.dart';

import '../models/grade_item.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';

/// Diálogo compacto para ingresar/editar SOLO la nota de un grade item.
/// El caso más común: el profe entregó la calificación de un parcial y
/// quieres registrarla rápido sin pasar por el formulario completo.
///
/// Si el grade item tiene sub-tareas vinculadas, la nota se calcula
/// automáticamente desde ellas y este diálogo muestra solo un aviso.
class EditGradeNotaDialog extends StatefulWidget {
  final GradeItem item;
  final Subject subject;

  /// Si true, el grade item se calcula automáticamente de sus sub-tareas
  /// y no se puede editar manualmente.
  final bool autoCalculada;

  const EditGradeNotaDialog({
    super.key,
    required this.item,
    required this.subject,
    this.autoCalculada = false,
  });

  static Future<void> show(
    BuildContext context, {
    required GradeItem item,
    required Subject subject,
    bool autoCalculada = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => EditGradeNotaDialog(
        item: item,
        subject: subject,
        autoCalculada: autoCalculada,
      ),
    );
  }

  @override
  State<EditGradeNotaDialog> createState() => _EditGradeNotaDialogState();
}

class _EditGradeNotaDialogState extends State<EditGradeNotaDialog> {
  late final TextEditingController _notaCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notaCtrl = TextEditingController(
      text: widget.item.nota?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    double? nota;
    final raw = _notaCtrl.text.trim();
    if (raw.isNotEmpty) {
      nota = double.tryParse(raw.replaceAll(',', '.'));
      if (nota == null) {
        setState(() => _error = 'Número inválido');
        return;
      }
      if (nota < 0 || nota > 5) {
        setState(() => _error = 'Debe estar entre 0 y 5');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await FirestoreService.instance.setGradeItemNota(widget.item.id, nota);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  Future<void> _eliminar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ítem?'),
        content: Text(
          'Se eliminará "${widget.item.nombre}". Si tiene tareas vinculadas, '
          'se desvincularán pero no se borrarán.',
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
      await FirestoreService.instance.deleteGradeItem(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.subject.color;
    return AlertDialog(
      title: Text(widget.item.nombre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item.porcentaje.toStringAsFixed(0)}% del curso',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (widget.autoCalculada)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: color),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Esta calificación está vinculada a una tarea. La nota se toma directamente de la tarea — para cambiarla, edita la tarea.',
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _notaCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Nota obtenida',
                hintText: '0.0 a 5.0',
                suffixIcon: _notaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Quitar nota',
                        onPressed: () {
                          _notaCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                errorText: _error,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Deja vacío si aún no tienes la calificación.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _eliminar,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(widget.autoCalculada ? 'Cerrar' : 'Cancelar'),
        ),
        if (!widget.autoCalculada)
          FilledButton(
            onPressed: _saving ? null : _guardar,
            style: FilledButton.styleFrom(backgroundColor: color),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar'),
          ),
      ],
      actionsOverflowAlignment: OverflowBarAlignment.center,
    );
  }
}
