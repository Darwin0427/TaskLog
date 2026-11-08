import 'package:flutter/material.dart';

import '../models/filtros_tareas.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../theme/app_theme.dart';
import 'ios_ui.dart';

/// Abre la hoja «Filtros». Devuelve los filtros nuevos, o null si se cerró
/// sin confirmar.
///
/// [soloMaterias] deja solo la sección de materias (para Apuntes).
/// [tareas] se usa para el pie «Se mostrarán X de Y tareas».
Future<FiltrosTareas?> mostrarHojaFiltros(
  BuildContext context, {
  required FiltrosTareas actuales,
  required List<Subject> materias,
  List<TaskItem> tareas = const <TaskItem>[],
  bool soloMaterias = false,
}) {
  return abrirHojaMedia<FiltrosTareas>(
    context,
    _HojaFiltros(
      inicial: actuales,
      materias: materias,
      tareas: tareas,
      soloMaterias: soloMaterias,
    ),
  );
}

class _HojaFiltros extends StatefulWidget {
  final FiltrosTareas inicial;
  final List<Subject> materias;
  final List<TaskItem> tareas;
  final bool soloMaterias;

  const _HojaFiltros({
    required this.inicial,
    required this.materias,
    required this.tareas,
    required this.soloMaterias,
  });

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late FiltrosTareas _f = widget.inicial;

  static const _nombresOrden = <OrdenTareas, String>{
    OrdenTareas.fecha: 'Fecha',
    OrdenTareas.prioridad: 'Prioridad',
    OrdenTareas.materia: 'Materia',
  };

  void _toggleMateria(String id) {
    final s = Set<String>.from(_f.materias);
    if (!s.remove(id)) s.add(id);
    setState(() => _f = _f.copyWith(materias: s));
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final total = widget.tareas.length;
    final visibles = widget.tareas
        .where((t) => _f.acepta(t) && (_f.mostrarCompletadas || !t.completada))
        .length;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            EncabezadoHoja(
              titulo: 'Filtros',
              izquierda: BotonCapsula(
                texto: 'Restablecer',
                onTap: () => setState(() => _f = FiltrosTareas.ninguno),
              ),
              onConfirmar: () => Navigator.of(context).pop(_f),
            ),
            const EtiquetaGrupo('Materia'),
            if (widget.materias.isEmpty)
              const PieGrupo('Todavía no tienes materias.')
            else
              GrupoIOS(
                sangriaSeparador: 58,
                children: [
                  for (final m in widget.materias)
                    FilaIOS(
                      leading: IconoCuadrado(icono: m.icon, color: m.color),
                      titulo: m.nombre,
                      trailing: _f.materias.contains(m.id)
                          ? Icon(Icons.check_rounded, color: p.acento)
                          : const SizedBox(width: 24),
                      onTap: () => _toggleMateria(m.id),
                    ),
                ],
              ),
            if (!widget.soloMaterias) ...[
              const EtiquetaGrupo('Prioridad'),
              SegmentadoIOS<String>(
                opciones: const {
                  'Todas': 'Todas',
                  'Alta': 'Alta',
                  'Media': 'Media',
                  'Baja': 'Baja',
                },
                valor: _f.prioridad ?? 'Todas',
                onChanged: (v) => setState(
                  () => _f = v == 'Todas'
                      ? _f.copyWith(borrarPrioridad: true)
                      : _f.copyWith(prioridad: v),
                ),
              ),
              const SizedBox(height: 18),
              GrupoIOS(
                children: [
                  FilaIOS(
                    titulo: 'Ordenar por',
                    trailing: PopupMenuButton<OrdenTareas>(
                      initialValue: _f.orden,
                      onSelected: (o) =>
                          setState(() => _f = _f.copyWith(orden: o)),
                      itemBuilder: (_) => [
                        for (final e in _nombresOrden.entries)
                          PopupMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _nombresOrden[_f.orden]!,
                            style: TextStyle(fontSize: 17, color: p.acento),
                          ),
                          Icon(Icons.unfold_more_rounded,
                              size: 18, color: p.acento),
                        ],
                      ),
                    ),
                  ),
                  FilaIOS(
                    titulo: 'Mostrar completadas',
                    trailing: InterruptorIOS(
                      valor: _f.mostrarCompletadas,
                      onChanged: (v) => setState(
                        () => _f = _f.copyWith(mostrarCompletadas: v),
                      ),
                    ),
                  ),
                ],
              ),
              if (total > 0)
                PieGrupo('Se mostrarán $visibles de $total tareas.'),
            ],
          ],
        ),
      ),
    );
  }
}
