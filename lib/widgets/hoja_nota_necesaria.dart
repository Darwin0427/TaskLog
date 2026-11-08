import 'package:flutter/material.dart';

import '../models/grade_item.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../utils/promedios.dart';
import 'ios_ui.dart';

/// Abre la hoja «Nota necesaria» de una materia: eliges con qué nota
/// quieres terminar y la app te dice cuánto necesitas en lo que falta.
///
/// [items] deben traer la nota efectiva de cada evaluación.
Future<void> mostrarHojaNotaNecesaria(
  BuildContext context, {
  required Subject materia,
  required List<GradeItem> items,
}) {
  return abrirHojaMedia<void>(
    context,
    _HojaNotaNecesaria(materia: materia, items: items),
  );
}

const List<double> _metas = <double>[3.0, 3.5, 4.0, 4.5];

class _HojaNotaNecesaria extends StatefulWidget {
  final Subject materia;
  final List<GradeItem> items;

  const _HojaNotaNecesaria({required this.materia, required this.items});

  @override
  State<_HojaNotaNecesaria> createState() => _HojaNotaNecesariaState();
}

class _HojaNotaNecesariaState extends State<_HojaNotaNecesaria> {
  late double _meta = _metas.contains(widget.materia.meta)
      ? widget.materia.meta!
      : 3.0;
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirestoreService.instance.setSubjectMeta(widget.materia.id, _meta);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final r = ResumenMateria.de(widget.items);
    final necesaria = notaNecesaria(r, _meta);
    final pendientes = widget.items.where((e) => e.nota == null).toList();
    final actual = r.notaActual;

    // Estado: verde alcanzable, ámbar apretado, rojo imposible.
    late final String estado;
    late final Color color;
    if (necesaria == null) {
      final logra = r.puntos >= _meta;
      estado = logra ? 'Ya lo lograste' : 'Ya no queda nada por evaluar';
      color = logra ? AppColors.lowPriority : AppColors.highPriority;
    } else if (necesaria <= 0) {
      estado = 'Ya la tienes asegurada';
      color = AppColors.lowPriority;
    } else if (necesaria > 5.0) {
      estado = 'No es posible (pasa de 5.0)';
      color = AppColors.highPriority;
    } else if (necesaria > 4.0) {
      estado = 'Apretado';
      color = AppColors.mediumPriority;
    } else {
      estado = 'Alcanzable';
      color = AppColors.lowPriority;
    }
    final finalCon3 = r.faltante > 0 ? r.puntos + 3.0 * r.faltante / 100 : null;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoHoja(
              titulo: 'Nota necesaria',
              subtitulo: actual == null
                  ? widget.materia.nombre
                  : '${widget.materia.nombre} · ${actual.toStringAsFixed(2)} '
                      'en el ${r.evaluado.round()} % evaluado',
            ),
            const EtiquetaGrupo('Quiero terminar con'),
            SegmentadoIOS<double>(
              opciones: {for (final m in _metas) m: m.toStringAsFixed(1)},
              valor: _meta,
              onChanged: (v) => setState(() => _meta = v),
            ),
            const SizedBox(height: 22),
            if (necesaria != null && necesaria > 0) ...[
              Text(
                'Necesitas al menos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: p.texto2),
              ),
              Text(
                necesaria > 5.0 ? '> 5.0' : necesaria.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: color,
                ),
              ),
              Text(
                'en el ${r.faltante.round()} % que falta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: p.texto2),
              ),
              const SizedBox(height: 10),
            ],
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      color == AppColors.lowPriority
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      size: 15,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      estado,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (pendientes.isNotEmpty || finalCon3 != null)
              GrupoIOS(
                children: [
                  for (final e in pendientes)
                    FilaIOS(
                      titulo: 'Falta: ${e.nombre}',
                      valor: '${e.porcentaje.toStringAsFixed(0)} %',
                    ),
                  if (finalCon3 != null)
                    FilaIOS(
                      titulo: 'Si sacas 3.0, terminas en',
                      trailing: Text(
                        finalCon3.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: p.acento,
                        ),
                      ),
                    ),
                ],
              ),
            if (widget.items.isEmpty)
              const PieGrupo(
                'Agrega las evaluaciones de la materia con su porcentaje '
                'para poder calcular.',
              ),
            const SizedBox(height: 18),
            BotonPrincipal(
              texto: 'Guardar meta de ${_meta.toStringAsFixed(1)}',
              cargando: _guardando,
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
