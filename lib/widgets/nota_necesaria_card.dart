import 'package:flutter/material.dart';

import '../models/grade_item.dart';

/// Calcula cuánto se necesita en los ítems sin evaluar para llegar a una
/// meta dada (por defecto 3.0).
///
/// Fórmula: meta = acumulado + (notaNecesaria * pctPendiente / 100)
/// → notaNecesaria = (meta - acumulado) * 100 / pctPendiente
class NotaNecesariaCard extends StatefulWidget {
  final List<GradeItem> items;
  final Color color;

  const NotaNecesariaCard({
    super.key,
    required this.items,
    required this.color,
  });

  @override
  State<NotaNecesariaCard> createState() => _NotaNecesariaCardState();
}

class _NotaNecesariaCardState extends State<NotaNecesariaCard> {
  double _meta = 3.0;

  @override
  Widget build(BuildContext context) {
    final evaluados = widget.items.where((e) => e.nota != null).toList();
    final pendientes = widget.items.where((e) => e.nota == null).toList();

    final acumulado = evaluados.fold<double>(
      0,
      (a, e) => a + (e.nota! * e.porcentaje / 100.0),
    );
    final pctPendiente = pendientes.fold<double>(0, (a, e) => a + e.porcentaje);

    String mensaje;
    Color colorTexto = widget.color;
    IconData icon = Icons.info_outline;

    if (widget.items.isEmpty) {
      mensaje = 'Aún no hay ítems para calcular.';
      colorTexto = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (acumulado >= _meta) {
      mensaje =
          'Ya superaste la meta de ${_meta.toStringAsFixed(1)} con tu acumulado actual.';
      colorTexto = Colors.green.shade700;
      icon = Icons.celebration_outlined;
    } else if (pctPendiente <= 0) {
      mensaje =
          'No hay porcentaje pendiente para alcanzar la meta de ${_meta.toStringAsFixed(1)}.';
      colorTexto = Colors.red.shade700;
      icon = Icons.block;
    } else {
      final notaNecesaria = (_meta - acumulado) * 100.0 / pctPendiente;
      if (notaNecesaria > 5.0) {
        mensaje =
            'Necesitarías ${notaNecesaria.toStringAsFixed(2)} en el ${pctPendiente.toStringAsFixed(0)}% restante. '
            'Es matemáticamente imposible llegar a ${_meta.toStringAsFixed(1)} (máx 5.0).';
        colorTexto = Colors.red.shade700;
        icon = Icons.warning_amber_outlined;
      } else if (notaNecesaria <= 0) {
        mensaje =
            'Ya tienes asegurada la meta. Puedes sacar 0 en lo restante.';
        colorTexto = Colors.green.shade700;
        icon = Icons.thumb_up_outlined;
      } else {
        mensaje =
            'Necesitas ${notaNecesaria.toStringAsFixed(2)} promedio en el ${pctPendiente.toStringAsFixed(0)}% restante para llegar a ${_meta.toStringAsFixed(1)}.';
      }
    }

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: Icon(Icons.calculate_outlined, color: widget.color),
      title: Text(
        '¿Qué nota necesito?',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: widget.color,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: colorTexto),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: TextStyle(color: colorTexto),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Meta: ${_meta.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: _meta,
                      min: 0,
                      max: 5,
                      divisions: 50,
                      activeColor: widget.color,
                      label: _meta.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _meta = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
