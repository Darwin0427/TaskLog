import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../services/firestore_service.dart';
import '../../services/preferencias_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../utils/promedios.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/tasklog_tab_bar.dart';
import '../perfil/perfil_screen.dart';
import 'detalle_materia_screen.dart';

/// Pestaña Materias: promedio general arriba y cada materia como fila
/// estilo Ajustes (ícono en cuadrado de color, avance y nota a la derecha).
class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, snap) {
          return StreamBuilder<List<GradeItem>>(
            stream: FirestoreService.instance.watchAllGradeItems(),
            builder: (context, gSnap) {
              final materias = snap.data ?? const <Subject>[];
              final resumenes =
                  resumirPorMateria(gSnap.data ?? const <GradeItem>[]);
              return RefreshIndicator(
                onRefresh: FirestoreService.instance.refreshFromServer,
                edgeOffset: MediaQuery.paddingOf(context).top,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    ValueListenableBuilder<String>(
                      valueListenable: PreferenciasService.instance.semestre,
                      builder: (context, semestre, _) => EncabezadoGrande(
                        antetitulo: 'Semestre $semestre',
                        titulo: 'Materias',
                        acciones: [
                          AvatarUsuario(onTap: () => abrirPerfil(context)),
                        ],
                      ),
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
                    else if (materias.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.school_outlined,
                          title: 'No tienes materias',
                          subtitle:
                              'Toca el botón + para crear tu primera materia.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          TaskLogTabBar.espacioInferior(context),
                        ),
                        sliver: SliverList.list(
                          children: [
                            _TarjetaPromedio(
                              materias: materias,
                              resumenes: resumenes,
                            ),
                            const SizedBox(height: 22),
                            GrupoIOS(
                              sangriaSeparador: 58,
                              children: [
                                for (final m in materias)
                                  _FilaMateria(
                                    materia: m,
                                    resumen: resumenes[m.id],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TarjetaPromedio extends StatelessWidget {
  final List<Subject> materias;
  final Map<String, ResumenMateria> resumenes;

  const _TarjetaPromedio({required this.materias, required this.resumenes});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final deMaterias =
        materias.map((m) => resumenes[m.id]).whereType<ResumenMateria>();
    final prom = promedioGeneral(deMaterias);
    final evaluadoMedio = materias.isEmpty
        ? 0.0
        : materias
                .map((m) => resumenes[m.id]?.evaluado ?? 0)
                .fold<double>(0, (a, b) => a + b) /
            materias.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: p.grupo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promedio general',
            style: TextStyle(fontSize: 15, color: p.texto2),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prom == null ? '–' : prom.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: prom == null ? p.texto2 : colorNota(prom),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ 5.0',
                  style: TextStyle(fontSize: 17, color: p.texto2),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${materias.length} '
                    '${materias.length == 1 ? 'materia' : 'materias'}',
                    style: TextStyle(fontSize: 13, color: p.texto2),
                  ),
                  Text(
                    '${evaluadoMedio.round()} % evaluado',
                    style: TextStyle(fontSize: 13, color: p.texto2),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Color de una nota de 0 a 5: verde si aprueba con holgura, ámbar si
/// está justa y rojo si pierde (menos de 3.0).
Color colorNota(double nota) {
  if (nota < 3.0) return AppColors.highPriority;
  if (nota < 3.5) return AppColors.mediumPriority;
  return AppColors.lowPriority;
}

class _FilaMateria extends StatelessWidget {
  final Subject materia;
  final ResumenMateria? resumen;

  const _FilaMateria({required this.materia, required this.resumen});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final nota = resumen?.notaActual;
    final evaluado = resumen?.evaluado ?? 0;
    return FilaIOS(
      leading: IconoCuadrado(icono: materia.icon, color: materia.color),
      titulo: materia.nombre,
      subtitulo: resumen == null || resumen!.cantidad == 0
          ? 'Sin evaluaciones'
          : '${evaluado.round()} % evaluado',
      trailing: Text(
        nota == null ? '–' : nota.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: nota == null ? p.texto2 : p.texto,
        ),
      ),
      chevron: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleMateriaScreen(subject: materia),
        ),
      ),
    );
  }
}
