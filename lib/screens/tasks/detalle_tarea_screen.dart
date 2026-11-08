import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grade_item.dart';
import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../models/task_reminder.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hoja_recordatorios.dart';
import '../../widgets/ios_ui.dart';
import '../forms/crear_nota_screen.dart';
import '../forms/crear_tarea_screen.dart';
import '../notes/detalle_nota_screen.dart';

/// Detalle de una tarea: prioridad, título grande y materia; cuándo vence
/// (con cuánto falta); descripción; recordatorios editables aquí mismo;
/// evaluación vinculada; apuntes; y el botón «Marcar como completada».
class DetalleTareaScreen extends StatelessWidget {
  final String taskId;
  const DetalleTareaScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskItem?>(
      stream: FirestoreService.instance.watchTask(taskId),
      builder: (context, snap) {
        final tarea = snap.data;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _BarraSuperior(tarea: tarea),
                Expanded(child: _cuerpo(snap)),
              ],
            ),
          ),
          bottomNavigationBar: tarea == null ? null : _BotonCompletar(tarea),
        );
      },
    );
  }

  Widget _cuerpo(AsyncSnapshot<TaskItem?> snap) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final tarea = snap.data;
    if (tarea == null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Tarea no encontrada',
        subtitle: 'Es posible que la hayas eliminado.',
      );
    }
    return _Cuerpo(tarea: tarea);
  }
}

class _BarraSuperior extends StatelessWidget {
  final TaskItem? tarea;
  const _BarraSuperior({required this.tarea});

  Future<void> _eliminar(BuildContext context, TaskItem t) async {
    final ok = await confirmarIOS(
      context,
      titulo: '¿Eliminar tarea?',
      mensaje: 'Se eliminará «${t.titulo}» y sus apuntes vinculados. '
          'Esto no se puede deshacer.',
    );
    if (!ok || !context.mounted) return;
    try {
      await FirestoreService.instance.deleteTask(t.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tarea;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          BotonCirculo(
            icono: Icons.chevron_left_rounded,
            tooltip: 'Volver',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          if (t != null) ...[
            BotonCirculo(
              icono: Icons.edit_rounded,
              tooltip: 'Editar',
              onTap: () =>
                  abrirFormulario(context, CrearTareaScreen(existing: t)),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (v) {
                if (v == 'eliminar') _eliminar(context, t);
                if (v == 'apunte') {
                  abrirFormulario(
                    context,
                    CrearNotaScreen(
                      defaultSubjectId: t.subjectId,
                      taskId: t.id,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'apunte',
                  child: ListTile(
                    leading: Icon(Icons.note_add_outlined),
                    title: Text('Agregar apunte'),
                  ),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Eliminar tarea',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              ],
              child: const IgnorePointer(
                child: BotonCirculo(
                  icono: Icons.more_horiz_rounded,
                  tooltip: 'Más opciones',
                  onTap: null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  final TaskItem tarea;
  const _Cuerpo({required this.tarea});

  Future<void> _guardarRecordatorios(
    BuildContext context,
    List<TaskReminder> lista,
  ) async {
    try {
      await FirestoreService.instance
          .updateTask(tarea.id, tarea.copyWith(recordatorios: lista));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final ahora = DateTime.now();
    final colorPrioridad = AppColors.forImportancia(tarea.importancia);
    final recordatorios = List<TaskReminder>.from(tarea.recordatorios)
      ..sort((a, b) => a
          .resolverFecha(tarea.fechaLimite)
          .compareTo(b.resolverFecha(tarea.fechaLimite)));
    final df = DateFormat('d MMM', 'es');

    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, sSnap) {
        Subject? materia;
        for (final s in sSnap.data ?? const <Subject>[]) {
          if (s.id == tarea.subjectId) materia = s;
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              '${MarcaPrioridad.signos(tarea.importancia)} '
              '${tarea.importancia} prioridad',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorPrioridad,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tarea.titulo,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: tarea.completada ? p.texto2 : p.texto,
                decoration:
                    tarea.completada ? TextDecoration.lineThrough : null,
              ),
            ),
            if (materia != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  PuntoMateria(materia.color),
                  const SizedBox(width: 6),
                  Text(
                    materia.nombre,
                    style: TextStyle(fontSize: 15, color: materia.color),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            GrupoIOS(
              children: [
                FilaIOS(
                  leading: const IconoCuadrado(
                    icono: Icons.calendar_today_rounded,
                    color: Color(0xFFFF3B30),
                  ),
                  titulo: _cuando(context, tarea.fechaLimite),
                  trailing: Text(
                    _cuantoFalta(tarea, ahora),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tarea.completada
                          ? p.texto2
                          : _vencida(tarea, ahora)
                              ? AppColors.highPriority
                              : AppColors.mediumPriority,
                    ),
                  ),
                ),
                if (tarea.descripcion.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        tarea.descripcion,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: p.texto2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const EtiquetaGrupo('Recordatorios'),
            GrupoIOS(
              sangriaSeparador: 52,
              children: [
                for (final r in recordatorios)
                  Builder(
                    builder: (context) {
                      final f = r.resolverFecha(tarea.fechaLimite);
                      final paso = f.isBefore(ahora);
                      return Opacity(
                        opacity: paso ? 0.45 : 1,
                        child: FilaIOS(
                          leading: Icon(
                            paso
                                ? Icons.notifications_off_rounded
                                : Icons.notifications_rounded,
                            color: p.acento,
                          ),
                          titulo:
                              '${df.format(f)}, ${formatearHora(context, f)}',
                          subtitulo: paso
                              ? '${r.labelRelativo} · ya pasó'
                              : r.labelRelativo,
                          trailing: IconButton(
                            tooltip: 'Quitar recordatorio',
                            icon: Icon(Icons.cancel_rounded, color: p.texto2),
                            onPressed: () => _guardarRecordatorios(
                              context,
                              List<TaskReminder>.from(tarea.recordatorios)
                                ..remove(r),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                FilaIOS(
                  leading: Icon(Icons.add_circle_rounded, color: p.acento),
                  tituloWidget: Text(
                    recordatorios.isEmpty
                        ? 'Añadir recordatorio'
                        : 'Cambiar recordatorios',
                    style: TextStyle(fontSize: 17, color: p.acento),
                  ),
                  onTap: () async {
                    final nueva = await mostrarHojaRecordatorios(
                      context,
                      fechaLimite: tarea.fechaLimite,
                      actuales: tarea.recordatorios,
                    );
                    if (nueva != null && context.mounted) {
                      await _guardarRecordatorios(context, nueva);
                    }
                  },
                ),
              ],
            ),
            if (tarea.gradeItemId != null)
              _EvaluacionVinculada(tarea: tarea),
            _ApuntesDeTarea(tarea: tarea),
          ],
        );
      },
    );
  }

  static bool _vencida(TaskItem t, DateTime ahora) {
    if (tieneHora(t.fechaLimite)) return t.fechaLimite.isBefore(ahora);
    return soloDia(t.fechaLimite).isBefore(soloDia(ahora));
  }

  static String _cuando(BuildContext context, DateTime f) {
    final hoy = soloDia(DateTime.now());
    final dia = soloDia(f);
    String base;
    if (dia == hoy) {
      base = 'Hoy';
    } else if (dia == hoy.add(const Duration(days: 1))) {
      base = 'Mañana';
    } else if (dia == hoy.subtract(const Duration(days: 1))) {
      base = 'Ayer';
    } else {
      final s = DateFormat("EEEE d 'de' MMMM", 'es').format(f);
      base = s[0].toUpperCase() + s.substring(1);
    }
    return tieneHora(f) ? '$base, ${formatearHora(context, f)}' : base;
  }

  static String _cuantoFalta(TaskItem t, DateTime ahora) {
    if (t.completada) return 'Hecha';
    if (_vencida(t, ahora)) {
      final dias = soloDia(ahora).difference(soloDia(t.fechaLimite)).inDays;
      if (dias <= 0) return 'Venció';
      return dias == 1 ? 'Hace 1 día' : 'Hace $dias días';
    }
    if (tieneHora(t.fechaLimite)) {
      final d = t.fechaLimite.difference(ahora);
      if (d.inMinutes < 60) return 'En ${d.inMinutes} min';
      if (d.inHours < 24) return 'En ${d.inHours} h';
    }
    final dias = soloDia(t.fechaLimite).difference(soloDia(ahora)).inDays;
    if (dias <= 0) return 'Hoy';
    return dias == 1 ? 'Mañana' : 'En $dias días';
  }
}

class _EvaluacionVinculada extends StatelessWidget {
  final TaskItem tarea;
  const _EvaluacionVinculada({required this.tarea});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GradeItem>>(
      stream:
          FirestoreService.instance.watchGradeItemsBySubject(tarea.subjectId),
      builder: (context, snap) {
        GradeItem? item;
        for (final g in snap.data ?? const <GradeItem>[]) {
          if (g.id == tarea.gradeItemId) item = g;
        }
        if (item == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EtiquetaGrupo('Evaluación'),
            GrupoIOS(
              children: [
                FilaIOS(
                  leading: const IconoCuadrado(
                    icono: Icons.link_rounded,
                    color: Color(0xFF8E8E93),
                  ),
                  titulo: item.nombre,
                  subtitulo:
                      '${item.porcentaje.toStringAsFixed(0)} % de la materia',
                  valor: tarea.nota == null
                      ? 'Sin nota'
                      : tarea.nota!.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ApuntesDeTarea extends StatelessWidget {
  final TaskItem tarea;
  const _ApuntesDeTarea({required this.tarea});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return StreamBuilder<List<Note>>(
      stream: FirestoreService.instance.watchNotesByTask(tarea.id),
      builder: (context, snap) {
        final notas = snap.data ?? const <Note>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EtiquetaGrupo(
              notas.isEmpty ? 'Apuntes' : 'Apuntes · ${notas.length}',
            ),
            GrupoIOS(
              sangriaSeparador: 52,
              children: [
                for (final n in notas)
                  FilaIOS(
                    leading: const Icon(
                      Icons.description_outlined,
                      color: AppColors.mediumPriority,
                    ),
                    titulo: n.titulo,
                    chevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetalleNotaScreen(noteId: n.id),
                      ),
                    ),
                  ),
                FilaIOS(
                  leading: Icon(Icons.add_circle_rounded, color: p.acento),
                  tituloWidget: Text(
                    'Agregar apunte',
                    style: TextStyle(fontSize: 17, color: p.acento),
                  ),
                  onTap: () => abrirFormulario(
                    context,
                    CrearNotaScreen(
                      defaultSubjectId: tarea.subjectId,
                      taskId: tarea.id,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BotonCompletar extends StatelessWidget {
  final TaskItem tarea;
  const _BotonCompletar(this.tarea);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: BotonPrincipal(
          texto: tarea.completada
              ? 'Marcar como pendiente'
              : 'Marcar como completada',
          icono: tarea.completada ? Icons.undo_rounded : Icons.check_rounded,
          onPressed: () async {
            try {
              await FirestoreService.instance
                  .setTaskCompletada(tarea.id, !tarea.completada);
            } catch (e) {
              if (context.mounted) showErrorSnackBar(context, e);
            }
          },
        ),
      ),
    );
  }
}
