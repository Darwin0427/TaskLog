import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/filtros_tareas.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hoja_filtros.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/tasklog_tab_bar.dart';
import '../perfil/perfil_screen.dart';
import '../tasks/detalle_tarea_screen.dart';

enum _VistaCalendario { mes, semana, dia }

/// Pestaña Calendario: el mes como título grande, vistas Mes / Semana /
/// Día, puntos de color por materia y la agenda del día elegido.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _VistaCalendario _vista = _VistaCalendario.mes;
  DateTime _enfocado = soloDia(DateTime.now());
  DateTime _elegido = soloDia(DateTime.now());
  FiltrosTareas _filtros = FiltrosTareas.ninguno;

  void _irAHoy() {
    final hoy = soloDia(DateTime.now());
    setState(() {
      _enfocado = hoy;
      _elegido = hoy;
    });
  }

  void _moverMes(int delta) {
    setState(() {
      if (_vista == _VistaCalendario.dia) {
        _elegido = _elegido.add(Duration(days: delta));
        _enfocado = _elegido;
      } else if (_vista == _VistaCalendario.semana) {
        _enfocado = _enfocado.add(Duration(days: 7 * delta));
      } else {
        _enfocado = DateTime(_enfocado.year, _enfocado.month + delta, 1);
      }
    });
  }

  Future<void> _abrirFiltros(
    List<Subject> materias,
    List<TaskItem> tareas,
  ) async {
    final nuevos = await mostrarHojaFiltros(
      context,
      actuales: _filtros,
      materias: materias,
      tareas: tareas,
    );
    if (nuevos != null) setState(() => _filtros = nuevos);
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final mes = DateFormat('MMMM', 'es').format(_enfocado);

    return Scaffold(
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, subjSnap) {
          final materias = subjSnap.data ?? const <Subject>[];
          final porId = <String, Subject>{for (final s in materias) s.id: s};
          return StreamBuilder<List<TaskItem>>(
            stream: FirestoreService.instance.watchTasks(),
            builder: (context, snap) {
              final todas = snap.data ?? const <TaskItem>[];
              final visibles = todas
                  .where((t) =>
                      _filtros.acepta(t) &&
                      (_filtros.mostrarCompletadas || !t.completada))
                  .toList();
              final porDia = <DateTime, List<TaskItem>>{};
              for (final t in visibles) {
                porDia.putIfAbsent(soloDia(t.fechaLimite), () => []).add(t);
              }
              final delDia = List<TaskItem>.from(porDia[_elegido] ?? const [])
                ..sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  EncabezadoGrande(
                    antetitulo: '${_enfocado.year}',
                    titulo: mes[0].toUpperCase() + mes.substring(1),
                    accionIzquierda: Row(
                      children: [
                        BotonCirculo(
                          icono: Icons.chevron_left_rounded,
                          tooltip: 'Anterior',
                          onTap: () => _moverMes(-1),
                        ),
                        const SizedBox(width: 8),
                        BotonCirculo(
                          icono: Icons.chevron_right_rounded,
                          tooltip: 'Siguiente',
                          onTap: () => _moverMes(1),
                        ),
                      ],
                    ),
                    acciones: [
                      BotonCapsula(texto: 'Hoy', onTap: _irAHoy),
                      BotonCirculo(
                        icono: Icons.tune_rounded,
                        tooltip: 'Filtros',
                        activo: _filtros.activos,
                        onTap: () => _abrirFiltros(materias, todas),
                      ),
                      AvatarUsuario(onTap: () => abrirPerfil(context)),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: SegmentadoIOS<_VistaCalendario>(
                        opciones: const {
                          _VistaCalendario.mes: 'Mes',
                          _VistaCalendario.semana: 'Semana',
                          _VistaCalendario.dia: 'Día',
                        },
                        valor: _vista,
                        onChanged: (v) => setState(() {
                          _vista = v;
                          _enfocado = _elegido;
                        }),
                      ),
                    ),
                  ),
                  if (_vista != _VistaCalendario.dia)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _Cuadricula(
                          enfocado: _enfocado,
                          elegido: _elegido,
                          formato: _vista == _VistaCalendario.mes
                              ? CalendarFormat.month
                              : CalendarFormat.week,
                          porDia: porDia,
                          porId: porId,
                          onElegir: (d) => setState(() {
                            _elegido = soloDia(d);
                            _enfocado = soloDia(d);
                          }),
                          onPagina: (d) =>
                              setState(() => _enfocado = soloDia(d)),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      TaskLogTabBar.espacioInferior(context),
                    ),
                    sliver: SliverList.list(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _fechaLarga(_elegido),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: p.texto2,
                                  ),
                                ),
                              ),
                              if (delDia.isNotEmpty)
                                Text(
                                  '${delDia.length} '
                                  '${delDia.length == 1 ? 'tarea' : 'tareas'}',
                                  style:
                                      TextStyle(fontSize: 13, color: p.texto2),
                                ),
                            ],
                          ),
                        ),
                        if (delDia.isEmpty)
                          GrupoIOS(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Center(
                                  child: Text(
                                    'Sin tareas este día',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: p.texto2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          GrupoIOS(
                            sangriaSeparador: 30,
                            children: [
                              for (final t in delDia)
                                _FilaAgenda(
                                  tarea: t,
                                  materia: porId[t.subjectId],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _fechaLarga(DateTime d) {
    final s = DateFormat("EEEE, d 'de' MMMM", 'es').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _Cuadricula extends StatelessWidget {
  final DateTime enfocado;
  final DateTime elegido;
  final CalendarFormat formato;
  final Map<DateTime, List<TaskItem>> porDia;
  final Map<String, Subject> porId;
  final ValueChanged<DateTime> onElegir;
  final ValueChanged<DateTime> onPagina;

  const _Cuadricula({
    required this.enfocado,
    required this.elegido,
    required this.formato,
    required this.porDia,
    required this.porId,
    required this.onElegir,
    required this.onPagina,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final hoy = soloDia(DateTime.now());

    Widget dia(DateTime d, {bool fuera = false}) {
      final esHoy = soloDia(d) == hoy;
      final esElegido = soloDia(d) == elegido;
      final finDeSemana =
          d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      Color colorTexto = finDeSemana ? p.texto2 : p.texto;
      if (esHoy) colorTexto = p.acento;
      if (esElegido) colorTexto = Colors.white;
      return Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: esElegido
                ? (esHoy ? AppColors.primary : p.texto2)
                : Colors.transparent,
          ),
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  esHoy || esElegido ? FontWeight.w600 : FontWeight.w400,
              color: fuera ? p.texto2.withValues(alpha: 0.4) : colorTexto,
            ),
          ),
        ),
      );
    }

    return TableCalendar<TaskItem>(
      locale: 'es',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: enfocado,
      calendarFormat: formato,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mes',
        CalendarFormat.week: 'Semana',
      },
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      rowHeight: 50,
      daysOfWeekHeight: 22,
      selectedDayPredicate: (d) => soloDia(d) == elegido,
      onDaySelected: (sel, _) => onElegir(sel),
      onPageChanged: onPagina,
      eventLoader: (d) => porDia[soloDia(d)] ?? const <TaskItem>[],
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (d, locale) =>
            DateFormat.E(locale).format(d)[0].toUpperCase(),
        weekdayStyle: TextStyle(fontSize: 13, color: p.texto2),
        weekendStyle: TextStyle(fontSize: 13, color: p.texto2),
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.zero,
      ),
      calendarBuilders: CalendarBuilders<TaskItem>(
        defaultBuilder: (context, d, _) => dia(d),
        todayBuilder: (context, d, _) => dia(d),
        selectedBuilder: (context, d, _) => dia(d),
        outsideBuilder: (context, d, _) => dia(d, fuera: true),
        markerBuilder: (context, d, eventos) {
          if (eventos.isEmpty) return const SizedBox.shrink();
          final colores = <Color>[];
          for (final t in eventos) {
            final c = porId[t.subjectId]?.color ?? p.texto2;
            if (!colores.contains(c)) colores.add(c);
            if (colores.length == 3) break;
          }
          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in colores)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: PuntoMateria(c, tamano: 5),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Fila de la agenda: barra vertical del color de la materia, título,
/// materia debajo y la hora a la derecha.
class _FilaAgenda extends StatelessWidget {
  final TaskItem tarea;
  final Subject? materia;

  const _FilaAgenda({required this.tarea, required this.materia});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final color = materia?.color ?? p.texto2;
    final signos = MarcaPrioridad.signos(tarea.importancia);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleTareaScreen(taskId: tarea.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (signos.isNotEmpty && !tarea.completada)
                            TextSpan(
                              text: '$signos ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color:
                                    AppColors.forImportancia(tarea.importancia),
                              ),
                            ),
                          TextSpan(text: tarea.titulo),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: tarea.completada ? p.texto2 : p.texto,
                        decoration: tarea.completada
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (materia != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        materia!.nombre,
                        style: TextStyle(fontSize: 13, color: p.texto2),
                      ),
                    ],
                  ],
                ),
              ),
              Center(
                child: Text(
                  tieneHora(tarea.fechaLimite)
                      ? formatearHora(context, tarea.fechaLimite)
                      : 'Todo el día',
                  style: TextStyle(fontSize: 13, color: p.texto2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
