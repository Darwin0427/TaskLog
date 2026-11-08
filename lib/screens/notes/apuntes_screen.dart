import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/tasklog_tab_bar.dart';
import '../perfil/perfil_screen.dart';
import 'detalle_nota_screen.dart';

/// Pestaña Apuntes: buscador, filtro por materia y los apuntes agrupados
/// en «Esta semana» y «Anteriores».
class ApuntesScreen extends StatefulWidget {
  const ApuntesScreen({super.key});

  @override
  State<ApuntesScreen> createState() => _ApuntesScreenState();
}

class _ApuntesScreenState extends State<ApuntesScreen> {
  String _busqueda = '';
  String? _materia; // null = todas

  bool _coincide(Note n) {
    if (_materia != null && n.subjectId != _materia) return false;
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return true;
    return n.titulo.toLowerCase().contains(q) ||
        n.contenido.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Scaffold(
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, subjSnap) {
          final materias = subjSnap.data ?? const <Subject>[];
          final porId = <String, Subject>{for (final s in materias) s.id: s};
          return StreamBuilder<List<TaskItem>>(
            stream: FirestoreService.instance.watchTasks(),
            builder: (context, tSnap) {
              final tareas = <String, TaskItem>{
                for (final t in tSnap.data ?? const <TaskItem>[]) t.id: t,
              };
              return StreamBuilder<List<Note>>(
                stream: FirestoreService.instance.watchNotes(),
                builder: (context, snap) {
                  final todas = snap.data ?? const <Note>[];
                  final notas = todas.where(_coincide).toList();
                  final limite =
                      soloDia(DateTime.now()).subtract(const Duration(days: 6));
                  final semana = notas
                      .where((n) =>
                          n.creadoEn == null || !n.creadoEn!.isBefore(limite))
                      .toList();
                  final antes = notas
                      .where((n) =>
                          n.creadoEn != null && n.creadoEn!.isBefore(limite))
                      .toList();

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      EncabezadoGrande(
                        titulo: 'Apuntes',
                        acciones: [
                          AvatarUsuario(onTap: () => abrirPerfil(context)),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: CupertinoSearchTextField(
                            placeholder: 'Buscar',
                            onChanged: (v) => setState(() => _busqueda = v),
                            style: TextStyle(color: p.texto),
                            backgroundColor: p.grupo2,
                          ),
                        ),
                      ),
                      if (materias.isNotEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 48,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 6),
                              children: [
                                Pildora(
                                  texto: 'Todos',
                                  seleccionada: _materia == null,
                                  onTap: () => setState(() => _materia = null),
                                ),
                                for (final m in materias) ...[
                                  const SizedBox(width: 8),
                                  Pildora(
                                    texto: m.nombre,
                                    colorPunto: m.color,
                                    seleccionada: _materia == m.id,
                                    onTap: () => setState(
                                      () => _materia =
                                          _materia == m.id ? null : m.id,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (todas.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.edit_note_rounded,
                            title: 'No tienes apuntes',
                            subtitle:
                                'Toca el botón + para escribir el primero.',
                          ),
                        )
                      else if (notas.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 48),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: Text(
                                'Ningún apunte coincide.',
                                style:
                                    TextStyle(fontSize: 15, color: p.texto2),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            TaskLogTabBar.espacioInferior(context),
                          ),
                          sliver: SliverList.list(
                            children: [
                              for (final grupo in [
                                ('Esta semana', semana),
                                ('Anteriores', antes),
                              ])
                                if (grupo.$2.isNotEmpty) ...[
                                  TituloSeccion(grupo.$1),
                                  GrupoIOS(
                                    children: [
                                      for (final n in grupo.$2)
                                        FilaApunte(
                                          nota: n,
                                          materia: porId[n.subjectId],
                                          tarea: n.taskId == null
                                              ? null
                                              : tareas[n.taskId],
                                        ),
                                    ],
                                  ),
                                ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Fila de un apunte: título, fecha + primera línea y la materia (y la
/// tarea vinculada, si tiene).
class FilaApunte extends StatelessWidget {
  final Note nota;
  final Subject? materia;
  final TaskItem? tarea;
  final bool mostrarMateria;

  const FilaApunte({
    super.key,
    required this.nota,
    required this.materia,
    this.tarea,
    this.mostrarMateria = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final primera = nota.contenido
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^- \[[ xX]\] '), '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => 'Sin contenido');
    final fecha = nota.creadoEn == null
        ? ''
        : '${DateFormat('d/M', 'es').format(nota.creadoEn!)}  ';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleNotaScreen(noteId: nota.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nota.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.texto,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: fecha,
                    style: TextStyle(color: p.texto),
                  ),
                  TextSpan(text: primera),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: p.texto2),
            ),
            if ((mostrarMateria && materia != null) || tarea != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (mostrarMateria && materia != null) ...[
                    Icon(Icons.folder_outlined, size: 14, color: p.texto2),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        materia!.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.texto2),
                      ),
                    ),
                  ],
                  if (tarea != null) ...[
                    if (mostrarMateria && materia != null)
                      const SizedBox(width: 10),
                    Icon(Icons.link_rounded, size: 14, color: p.texto2),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tarea!.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.texto2),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
