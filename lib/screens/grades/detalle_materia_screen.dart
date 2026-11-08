import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/grade_item.dart';
import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/grade_calc.dart';
import '../../utils/promedios.dart';
import '../../widgets/hoja_nota_necesaria.dart';
import '../../widgets/ios_ui.dart';
import '../forms/crear_grade_item_screen.dart';
import '../forms/crear_materia_screen.dart';
import '../forms/crear_nota_screen.dart';
import '../forms/crear_tarea_screen.dart';
import '../notes/apuntes_screen.dart';
import '../tasks/tasks_screen.dart';

enum _Seccion { evaluaciones, tareas, apuntes }

/// Detalle de una materia: cabecera centrada estilo Contactos con tres
/// accesos rápidos (clase virtual, nota necesaria, horario), la nota
/// actual y un segmentado Evaluaciones · Tareas · Apuntes.
class DetalleMateriaScreen extends StatefulWidget {
  /// Materia inicial; la versión "viva" llega del stream para reflejar
  /// ediciones al instante.
  final Subject subject;
  const DetalleMateriaScreen({super.key, required this.subject});

  @override
  State<DetalleMateriaScreen> createState() => _DetalleMateriaScreenState();
}

class _DetalleMateriaScreenState extends State<DetalleMateriaScreen> {
  _Seccion _seccion = _Seccion.evaluaciones;

  void _agregar(Subject m) {
    final Widget form = switch (_seccion) {
      _Seccion.evaluaciones => CrearGradeItemScreen(subject: m),
      _Seccion.tareas => CrearTareaScreen(defaultSubjectId: m.id),
      _Seccion.apuntes => CrearNotaScreen(defaultSubjectId: m.id),
    };
    abrirFormulario(context, form);
  }

  Future<void> _eliminar(Subject m) async {
    final SubjectChildrenCount n;
    try {
      n = await FirestoreService.instance.countSubjectChildren(m.id);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return;
    }
    if (!mounted) return;
    if (!n.isEmpty) {
      final partes = <String>[
        if (n.tasks > 0) '${n.tasks} ${n.tasks == 1 ? 'tarea' : 'tareas'}',
        if (n.notes > 0) '${n.notes} ${n.notes == 1 ? 'apunte' : 'apuntes'}',
        if (n.gradeItems > 0)
          '${n.gradeItems} '
              '${n.gradeItems == 1 ? 'evaluación' : 'evaluaciones'}',
      ];
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'Esta materia todavía tiene ${partes.join(', ')}. '
            'Elimínalos primero.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final ok = await confirmarIOS(
      context,
      titulo: '¿Eliminar materia?',
      mensaje: 'Se eliminará «${m.nombre}». Esto no se puede deshacer.',
    );
    if (!ok || !mounted) return;
    try {
      await FirestoreService.instance.deleteSubject(m.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, snap) {
        var m = widget.subject;
        var existe = true;
        if (snap.hasData) {
          existe = false;
          for (final s in snap.data!) {
            if (s.id == widget.subject.id) {
              m = s;
              existe = true;
            }
          }
        }
        if (!existe) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _contenido(m);
      },
    );
  }

  Widget _contenido(Subject m) {
    return StreamBuilder<List<GradeItem>>(
      stream: FirestoreService.instance.watchGradeItemsBySubject(m.id),
      builder: (context, gSnap) => StreamBuilder<List<TaskItem>>(
        stream: FirestoreService.instance.watchTasksBySubject(m.id),
        builder: (context, tSnap) => StreamBuilder<List<Note>>(
          stream: FirestoreService.instance.watchNotesBySubject(m.id),
          builder: (context, nSnap) {
            final items = gSnap.data ?? const <GradeItem>[];
            final tareas = tSnap.data ?? const <TaskItem>[];
            final notas = nSnap.data ?? const <Note>[];

            // Nota efectiva de cada evaluación (manual o de su tarea).
            final efectivas = <GradeItem>[
              for (final it in items)
                GradeItem(
                  id: it.id,
                  subjectId: it.subjectId,
                  nombre: it.nombre,
                  porcentaje: it.porcentaje,
                  nota: computeGradeItemNota(
                    item: it,
                    subTareas:
                        tareas.where((t) => t.gradeItemId == it.id).toList(),
                  ).nota,
                  creadoEn: it.creadoEn,
                ),
            ];

            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _barra(m),
                    const SizedBox(height: 4),
                    _Cabecera(materia: m),
                    const SizedBox(height: 16),
                    _AccesosRapidos(materia: m, items: efectivas),
                    const SizedBox(height: 14),
                    _TarjetaNota(materia: m, items: efectivas),
                    const SizedBox(height: 16),
                    SegmentadoIOS<_Seccion>(
                      opciones: {
                        _Seccion.evaluaciones: 'Evaluaciones · ${items.length}',
                        _Seccion.tareas: 'Tareas · ${tareas.length}',
                        _Seccion.apuntes: 'Apuntes · ${notas.length}',
                      },
                      valor: _seccion,
                      onChanged: (v) => setState(() => _seccion = v),
                    ),
                    const SizedBox(height: 14),
                    ...switch (_seccion) {
                      _Seccion.evaluaciones =>
                        _evaluaciones(m, items, efectivas, tareas),
                      _Seccion.tareas => _tareas(m, tareas),
                      _Seccion.apuntes => _apuntes(m, notas, tareas),
                    },
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _barra(Subject m) {
    return Row(
      children: [
        BotonCirculo(
          icono: Icons.chevron_left_rounded,
          tooltip: 'Volver',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        BotonCirculo(
          icono: Icons.add_rounded,
          tooltip: switch (_seccion) {
            _Seccion.evaluaciones => 'Nueva evaluación',
            _Seccion.tareas => 'Nueva tarea',
            _Seccion.apuntes => 'Nuevo apunte',
          },
          onTap: () => _agregar(m),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (v) {
            if (v == 'editar') {
              abrirFormulario(context, CrearMateriaScreen(existing: m));
            }
            if (v == 'eliminar') _eliminar(m);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Editar materia'),
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
                  'Eliminar materia',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    );
  }

  List<Widget> _evaluaciones(
    Subject m,
    List<GradeItem> items,
    List<GradeItem> efectivas,
    List<TaskItem> tareas,
  ) {
    final p = TaskLogPalette.of(context);
    if (items.isEmpty) {
      return [
        _Vacio(
          texto: 'Aún no hay evaluaciones.',
          accion: 'Agregar evaluación',
          onTap: () => abrirFormulario(context, CrearGradeItemScreen(subject: m)),
        ),
      ];
    }
    final suma = items.fold<double>(0, (a, e) => a + e.porcentaje);
    return [
      GrupoIOS(
        children: [
          for (var i = 0; i < items.length; i++)
            Builder(
              builder: (context) {
                final it = items[i];
                final nota = efectivas[i].nota;
                TaskItem? vinculada;
                for (final t in tareas) {
                  if (t.gradeItemId == it.id) vinculada = t;
                }
                return FilaIOS(
                  titulo: it.nombre,
                  subtitulo: vinculada == null
                      ? '${it.porcentaje.toStringAsFixed(0)} % del curso'
                      : '${it.porcentaje.toStringAsFixed(0)} % · '
                          'tarea: ${vinculada.titulo}',
                  trailing: Text(
                    nota == null ? 'Sin nota' : nota.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: nota == null ? 15 : 17,
                      fontWeight:
                          nota == null ? FontWeight.w400 : FontWeight.w600,
                      color: nota == null ? p.texto2 : p.texto,
                    ),
                  ),
                  chevron: true,
                  onTap: () => abrirFormulario(
                    context,
                    CrearGradeItemScreen(subject: m, existing: it),
                  ),
                );
              },
            ),
        ],
      ),
      PieGrupo(
        suma < 100
            ? 'Registrado ${suma.toStringAsFixed(0)} % de 100 %. '
                'Falta registrar ${(100 - suma).toStringAsFixed(0)} %.'
            : 'Las evaluaciones suman el 100 % de la materia.',
      ),
    ];
  }

  List<Widget> _tareas(Subject m, List<TaskItem> tareas) {
    if (tareas.isEmpty) {
      return [
        _Vacio(
          texto: 'No hay tareas en esta materia.',
          accion: 'Agregar tarea',
          onTap: () =>
              abrirFormulario(context, CrearTareaScreen(defaultSubjectId: m.id)),
        ),
      ];
    }
    final ahora = DateTime.now();
    final pendientes = tareas.where((t) => !t.completada).toList();
    final hechas = tareas.where((t) => t.completada).toList();
    return [
      if (pendientes.isNotEmpty)
        GrupoIOS(
          sangriaSeparador: 52,
          children: [
            for (final t in pendientes)
              FilaTarea(
                tarea: t,
                materia: m,
                ahora: ahora,
                mostrarMateria: false,
              ),
          ],
        ),
      if (hechas.isNotEmpty) ...[
        const EtiquetaGrupo('Completadas'),
        GrupoIOS(
          sangriaSeparador: 52,
          children: [
            for (final t in hechas)
              FilaTarea(
                tarea: t,
                materia: m,
                ahora: ahora,
                mostrarMateria: false,
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _apuntes(Subject m, List<Note> notas, List<TaskItem> tareas) {
    if (notas.isEmpty) {
      return [
        _Vacio(
          texto: 'No hay apuntes en esta materia.',
          accion: 'Escribir apunte',
          onTap: () =>
              abrirFormulario(context, CrearNotaScreen(defaultSubjectId: m.id)),
        ),
      ];
    }
    final porId = <String, TaskItem>{for (final t in tareas) t.id: t};
    return [
      GrupoIOS(
        children: [
          for (final n in notas)
            FilaApunte(
              nota: n,
              materia: m,
              tarea: n.taskId == null ? null : porId[n.taskId],
              mostrarMateria: false,
            ),
        ],
      ),
    ];
  }
}

class _Cabecera extends StatelessWidget {
  final Subject materia;
  const _Cabecera({required this.materia});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final detalle = <String>[
      if ((materia.profesor ?? '').isNotEmpty) 'Prof. ${materia.profesor}',
      if ((materia.aula ?? '').isNotEmpty) 'Aula ${materia.aula}',
    ].join(' · ');
    return Column(
      children: [
        IconoCuadrado(icono: materia.icon, color: materia.color, tamano: 64),
        const SizedBox(height: 10),
        Text(
          materia.nombre,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: p.texto,
          ),
        ),
        if (detalle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: p.texto2),
          ),
        ],
      ],
    );
  }
}

class _AccesosRapidos extends StatelessWidget {
  final Subject materia;
  final List<GradeItem> items;
  const _AccesosRapidos({required this.materia, required this.items});

  Future<void> _abrirClase(BuildContext context) async {
    var url = materia.classLinkUrl!.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  void _verHorario(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Horario'),
        content: Text(materia.horario!),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tieneLink = (materia.classLinkUrl ?? '').isNotEmpty;
    final tieneHorario = (materia.horario ?? '').isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _Acceso(
            icono: Icons.videocam_rounded,
            texto: 'Clase virtual',
            habilitado: tieneLink,
            onTap: () => tieneLink
                ? _abrirClase(context)
                : abrirFormulario(
                    context, CrearMateriaScreen(existing: materia)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Acceso(
            icono: Icons.track_changes_rounded,
            texto: 'Nota necesaria',
            habilitado: true,
            onTap: () => mostrarHojaNotaNecesaria(
              context,
              materia: materia,
              items: items,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Acceso(
            icono: Icons.schedule_rounded,
            texto: 'Horario',
            habilitado: tieneHorario,
            onTap: () => tieneHorario
                ? _verHorario(context)
                : abrirFormulario(
                    context, CrearMateriaScreen(existing: materia)),
          ),
        ),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool habilitado;
  final VoidCallback onTap;

  const _Acceso({
    required this.icono,
    required this.texto,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final color = habilitado ? p.acento : p.texto2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: p.grupo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              texto,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaNota extends StatelessWidget {
  final Subject materia;
  final List<GradeItem> items;
  const _TarjetaNota({required this.materia, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final r = ResumenMateria.de(items);
    final actual = r.notaActual;
    final meta = materia.meta;
    final necesaria = meta == null ? null : notaNecesaria(r, meta);

    return GestureDetector(
      onTap: () => mostrarHojaNotaNecesaria(
        context,
        materia: materia,
        items: items,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: p.grupo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota actual',
                      style: TextStyle(fontSize: 13, color: p.texto2),
                    ),
                    Text(
                      actual == null ? '–' : actual.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: p.texto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Evaluado',
                            style: TextStyle(fontSize: 13, color: p.texto2),
                          ),
                          const Spacer(),
                          Text(
                            '${r.evaluado.round()} %',
                            style: TextStyle(fontSize: 13, color: p.texto2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (r.evaluado / 100).clamp(0, 1).toDouble(),
                          minHeight: 6,
                          backgroundColor: p.grupo2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(materia.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (meta != null && necesaria != null) ...[
              const SizedBox(height: 10),
              Text(
                necesaria <= 0
                    ? 'Ya tienes asegurado el ${meta.toStringAsFixed(1)}.'
                    : necesaria > 5
                        ? 'Ya no alcanza para terminar con '
                            '${meta.toStringAsFixed(1)}.'
                        : 'Para terminar con ${meta.toStringAsFixed(1)} '
                            'necesitas ${necesaria.toStringAsFixed(2)} en lo '
                            'que falta.',
                style: TextStyle(
                  fontSize: 13,
                  color: necesaria > 5 ? AppColors.highPriority : p.acento,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String texto;
  final String accion;
  final VoidCallback onTap;

  const _Vacio({required this.texto, required this.accion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return GrupoIOS(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Center(
            child: Text(texto, style: TextStyle(fontSize: 15, color: p.texto2)),
          ),
        ),
        FilaIOS(
          tituloWidget: Center(
            child: Text(accion, style: TextStyle(fontSize: 17, color: p.acento)),
          ),
          onTap: onTap,
        ),
      ],
    );
  }
}
