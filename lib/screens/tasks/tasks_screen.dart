import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/filtros_tareas.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hoja_filtros.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/tasklog_tab_bar.dart';
import '../perfil/perfil_screen.dart';
import 'detalle_tarea_screen.dart';

/// Las cuatro tarjetas de arriba. Tocar una filtra la lista por esa
/// categoría (tocarla otra vez la quita).
enum CategoriaTareas { hoy, atrasadas, proximas, completadas }

/// Pestaña Tareas: tarjetas Hoy / Atrasadas / Próximas / Completadas y la
/// lista agrupada por fecha (lo atrasado y lo de hoy primero).
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  CategoriaTareas? _categoria;
  FiltrosTareas _filtros = FiltrosTareas.ninguno;

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
              return RefreshIndicator(
                onRefresh: FirestoreService.instance.refreshFromServer,
                edgeOffset: MediaQuery.paddingOf(context).top,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    EncabezadoGrande(
                      antetitulo: DateFormat("EEEE d 'de' MMMM", 'es')
                          .format(DateTime.now()),
                      titulo: 'Tareas',
                      acciones: [
                        BotonCirculo(
                          icono: Icons.tune_rounded,
                          tooltip: 'Filtros',
                          activo: _filtros.activos,
                          onTap: () => _abrirFiltros(materias, todas),
                        ),
                        AvatarUsuario(onTap: () => abrirPerfil(context)),
                      ],
                    ),
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snap.hasError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(friendlyErrorMessage(snap.error!)),
                        ),
                      )
                    else if (todas.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.checklist_rounded,
                          title: 'No tienes tareas',
                          subtitle:
                              'Toca el botón + para crear tu primera tarea.',
                        ),
                      )
                    else
                      ..._contenido(context, todas, porId),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _contenido(
    BuildContext context,
    List<TaskItem> todas,
    Map<String, Subject> porId,
  ) {
    final ahora = DateTime.now();
    final filtradas = todas.where(_filtros.acepta).toList();
    final clasif = ClasificacionTareas(filtradas, ahora);

    final secciones = <_Seccion>[];
    switch (_categoria) {
      case CategoriaTareas.hoy:
        secciones.add(_Seccion('Hoy', clasif.hoy));
      case CategoriaTareas.atrasadas:
        secciones.add(
          _Seccion('Atrasadas', clasif.atrasadas, color: AppColors.highPriority),
        );
      case CategoriaTareas.proximas:
        secciones.addAll(_porDia(clasif.proximas, ahora));
      case CategoriaTareas.completadas:
        secciones.add(_Seccion('Completadas', clasif.completadas));
      case null:
        if (clasif.atrasadas.isNotEmpty) {
          secciones.add(
            _Seccion('Atrasadas', clasif.atrasadas,
                color: AppColors.highPriority),
          );
        }
        if (clasif.hoy.isNotEmpty) secciones.add(_Seccion('Hoy', clasif.hoy));
        secciones.addAll(_porDia(clasif.proximas, ahora));
        if (_filtros.mostrarCompletadas && clasif.completadas.isNotEmpty) {
          secciones.add(_Seccion('Completadas', clasif.completadas));
        }
    }
    for (final s in secciones) {
      _ordenar(s.tareas, porId, completadas: s.titulo == 'Completadas');
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _TarjetasMetricas(
            clasif: clasif,
            seleccionada: _categoria,
            onTap: (c) =>
                setState(() => _categoria = _categoria == c ? null : c),
          ),
        ),
      ),
      if (secciones.every((s) => s.tareas.isEmpty))
        SliverPadding(
          padding: const EdgeInsets.only(top: 48),
          sliver: SliverToBoxAdapter(
            child: _VacioCategoria(categoria: _categoria),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          TaskLogTabBar.espacioInferior(context),
        ),
        sliver: SliverList.list(
          children: [
            for (final s in secciones)
              if (s.tareas.isNotEmpty) ...[
                TituloSeccion(s.titulo, color: s.color),
                GrupoIOS(
                  sangriaSeparador: 52,
                  children: [
                    for (final t in s.tareas)
                      FilaTarea(
                        key: ValueKey('tarea_${t.id}'),
                        tarea: t,
                        materia: porId[t.subjectId],
                        ahora: ahora,
                      ),
                  ],
                ),
              ],
          ],
        ),
      ),
    ];
  }

  /// Agrupa las próximas por día: «Mañana», luego «Jueves 17 sep», etc.
  List<_Seccion> _porDia(List<TaskItem> tareas, DateTime ahora) {
    final manana = soloDia(ahora).add(const Duration(days: 1));
    final grupos = <DateTime, List<TaskItem>>{};
    for (final t in tareas) {
      grupos.putIfAbsent(soloDia(t.fechaLimite), () => []).add(t);
    }
    final dias = grupos.keys.toList()..sort();
    final fmt = DateFormat('EEEE d MMM', 'es');
    return [
      for (final d in dias)
        _Seccion(
          d == manana ? 'Mañana' : _capitalizar(fmt.format(d)),
          grupos[d]!,
        ),
    ];
  }

  void _ordenar(
    List<TaskItem> l,
    Map<String, Subject> porId, {
    required bool completadas,
  }) {
    if (completadas) {
      l.sort((a, b) => (b.completadaEn ?? b.fechaLimite)
          .compareTo(a.completadaEn ?? a.fechaLimite));
      return;
    }
    switch (_filtros.orden) {
      case OrdenTareas.fecha:
        l.sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
      case OrdenTareas.prioridad:
        l.sort((a, b) {
          final c = FiltrosTareas.pesoPrioridad(a.importancia)
              .compareTo(FiltrosTareas.pesoPrioridad(b.importancia));
          return c != 0 ? c : a.fechaLimite.compareTo(b.fechaLimite);
        });
      case OrdenTareas.materia:
        l.sort((a, b) {
          final c = (porId[a.subjectId]?.nombre ?? '')
              .compareTo(porId[b.subjectId]?.nombre ?? '');
          return c != 0 ? c : a.fechaLimite.compareTo(b.fechaLimite);
        });
    }
  }
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Seccion {
  final String titulo;
  final List<TaskItem> tareas;
  final Color? color;
  _Seccion(this.titulo, List<TaskItem> tareas, {this.color})
      : tareas = List<TaskItem>.from(tareas);
}

/// Reparte las tareas en atrasadas, de hoy, próximas y completadas.
///
/// Una tarea sin hora (00:00) cuenta como de todo el día: solo se atrasa
/// cuando el día ya pasó. Con hora, se atrasa en cuanto pasa esa hora.
class ClasificacionTareas {
  final List<TaskItem> atrasadas = [];
  final List<TaskItem> hoy = [];
  final List<TaskItem> proximas = [];
  final List<TaskItem> completadas = [];

  ClasificacionTareas(Iterable<TaskItem> tareas, DateTime ahora) {
    final dia = soloDia(ahora);
    for (final t in tareas) {
      if (t.completada) {
        completadas.add(t);
      } else if (estaVencida(t, ahora)) {
        atrasadas.add(t);
      } else if (soloDia(t.fechaLimite) == dia) {
        hoy.add(t);
      } else {
        proximas.add(t);
      }
    }
  }

  static bool estaVencida(TaskItem t, DateTime ahora) {
    if (t.completada) return false;
    if (tieneHora(t.fechaLimite)) return t.fechaLimite.isBefore(ahora);
    return soloDia(t.fechaLimite).isBefore(soloDia(ahora));
  }
}

class _TarjetasMetricas extends StatelessWidget {
  final ClasificacionTareas clasif;
  final CategoriaTareas? seleccionada;
  final ValueChanged<CategoriaTareas> onTap;

  const _TarjetasMetricas({
    required this.clasif,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget tarjeta(
      CategoriaTareas c,
      String etiqueta,
      IconData icono,
      Color color,
      int n,
    ) =>
        Expanded(
          child: _TarjetaMetrica(
            etiqueta: etiqueta,
            icono: icono,
            color: color,
            cantidad: n,
            seleccionada: seleccionada == c,
            onTap: () => onTap(c),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            tarjeta(CategoriaTareas.hoy, 'Hoy', Icons.today_rounded,
                const Color(0xFF0A84FF), clasif.hoy.length),
            const SizedBox(width: 10),
            tarjeta(CategoriaTareas.atrasadas, 'Atrasadas',
                Icons.schedule_rounded, AppColors.highPriority,
                clasif.atrasadas.length),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tarjeta(CategoriaTareas.proximas, 'Próximas',
                Icons.calendar_month_rounded, AppColors.mediumPriority,
                clasif.proximas.length),
            const SizedBox(width: 10),
            tarjeta(CategoriaTareas.completadas, 'Completadas',
                Icons.check_rounded, const Color(0xFF8E8E93),
                clasif.completadas.length),
          ],
        ),
      ],
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color color;
  final int cantidad;
  final bool seleccionada;
  final VoidCallback onTap;

  const _TarjetaMetrica({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.cantidad,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Semantics(
      button: true,
      selected: seleccionada,
      label: '$etiqueta: $cantidad',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: seleccionada ? color.withValues(alpha: 0.22) : p.grupo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionada ? color : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, size: 18, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '$cantidad',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: p.texto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.texto2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VacioCategoria extends StatelessWidget {
  final CategoriaTareas? categoria;
  const _VacioCategoria({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final texto = switch (categoria) {
      CategoriaTareas.hoy => 'Nada para hoy.',
      CategoriaTareas.atrasadas => 'No tienes tareas atrasadas.',
      CategoriaTareas.proximas => 'No hay tareas próximas.',
      CategoriaTareas.completadas => 'Aún no completas ninguna tarea.',
      null => '¡Todo al día! No tienes tareas pendientes.',
    };
    return Center(
      child: Text(texto, style: TextStyle(fontSize: 15, color: p.texto2)),
    );
  }
}

/// Fila de una tarea: círculo para completar, prioridad en «!», título y
/// debajo la materia con la hora o «venció el …».
///
/// Se usa en Tareas, en el detalle de materia y en el calendario.
class FilaTarea extends StatelessWidget {
  final TaskItem tarea;
  final Subject? materia;
  final DateTime ahora;
  final bool mostrarMateria;

  const FilaTarea({
    super.key,
    required this.tarea,
    required this.materia,
    required this.ahora,
    this.mostrarMateria = true,
  });

  Future<void> _toggle(BuildContext context) async {
    try {
      await FirestoreService.instance
          .setTaskCompletada(tarea.id, !tarea.completada);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final vencida = ClasificacionTareas.estaVencida(tarea, ahora);
    final pendientes = tarea.recordatorios
        .where((r) => r.resolverFecha(tarea.fechaLimite).isAfter(ahora))
        .isNotEmpty;

    final partes = <InlineSpan>[];
    void agregar(String texto, {Color? color}) {
      if (partes.isNotEmpty) partes.add(const TextSpan(text: ' · '));
      partes.add(TextSpan(text: texto, style: TextStyle(color: color)));
    }

    if (mostrarMateria && materia != null) agregar(materia!.nombre);
    if (tarea.completada) {
      agregar(DateFormat('d MMM', 'es').format(tarea.fechaLimite));
    } else if (vencida) {
      agregar(
        'venció el ${DateFormat('d MMM', 'es').format(tarea.fechaLimite)}',
        color: AppColors.highPriority,
      );
    } else if (tieneHora(tarea.fechaLimite)) {
      agregar(formatearHora(context, tarea.fechaLimite));
    }
    if (pendientes && !tarea.completada) {
      partes.add(const TextSpan(text: '  '));
      partes.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.notifications_rounded, size: 13, color: p.texto2),
        ),
      );
    }

    final signos = MarcaPrioridad.signos(tarea.importancia);
    return FilaIOS(
      leading: CirculoCompletar(
        completada: tarea.completada,
        onTap: () => _toggle(context),
      ),
      tituloWidget: Text.rich(
        TextSpan(
          children: [
            if (signos.isNotEmpty && !tarea.completada)
              TextSpan(
                text: '$signos ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.forImportancia(tarea.importancia),
                ),
              ),
            TextSpan(text: tarea.titulo),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          color: tarea.completada ? p.texto2 : p.texto,
          decoration: tarea.completada ? TextDecoration.lineThrough : null,
        ),
      ),
      subtituloWidget: partes.isEmpty
          ? null
          : Text.rich(
              TextSpan(children: partes),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: p.texto2),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleTareaScreen(taskId: tarea.id),
        ),
      ),
    );
  }
}
