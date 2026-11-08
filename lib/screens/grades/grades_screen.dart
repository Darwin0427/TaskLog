import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tasklog_tab_bar.dart';
import '../notifications/onboarding_notificaciones_screen.dart';
import 'detalle_materia_screen.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materias'),
        actions: const [_MenuCuenta()],
      ),
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final subjects = snap.data ?? const <Subject>[];
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'No tienes materias',
              subtitle: 'Toca el botón + para crear tu primera materia.',
            );
          }
          return RefreshIndicator(
            onRefresh: FirestoreService.instance.refreshFromServer,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                TaskLogTabBar.espacioInferior(context),
              ),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => AnimatedListItem(
                key: ValueKey('subject_${subjects[i].id}'),
                child: _SubjectCard(subject: subjects[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Menú de cuenta (temporal hasta la pantalla de Perfil, fase 5):
/// apariencia, ajustes de notificaciones (solo Android) y cerrar sesión.
class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta();

  @override
  Widget build(BuildContext context) {
    final esAndroid = defaultTargetPlatform == TargetPlatform.android;
    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (accion) async {
        switch (accion) {
          case 'tema':
            await mostrarSelectorTema(context);
          case 'notificaciones':
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const OnboardingNotificacionesScreen(allowSkip: true),
              ),
            );
          case 'salir':
            await AuthService.instance.signOut();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'tema',
          child: ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Apariencia'),
          ),
        ),
        if (esAndroid)
          const PopupMenuItem(
            value: 'notificaciones',
            child: ListTile(
              leading: Icon(Icons.notifications_active_outlined),
              title: Text('Ajustes de notificaciones'),
            ),
          ),
        PopupMenuItem(
          value: 'salir',
          child: ListTile(
            leading: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GradeItem>>(
      stream:
          FirestoreService.instance.watchGradeItemsBySubject(subject.id),
      builder: (context, snap) {
        final items = snap.data ?? const <GradeItem>[];
        final evaluadosPct = items
            .where((e) => e.nota != null)
            .fold<double>(0, (acc, e) => acc + e.porcentaje);
        final acumulado = items
            .where((e) => e.nota != null)
            .fold<double>(
                0, (acc, e) => acc + (e.nota! * e.porcentaje / 100.0));
        final evaluados = items.where((e) => e.nota != null).toList();
        final promedio = evaluados.isEmpty
            ? 0.0
            : evaluados.fold<double>(0, (a, e) => a + e.nota!) /
                evaluados.length;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetalleMateriaScreen(subject: subject),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: subject.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(subject.icon, color: subject.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.nombre,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} ítem${items.length == 1 ? '' : 's'}',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${promedio.toStringAsFixed(1)} / 5.0',
                            style: TextStyle(
                              color: subject.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Promedio',
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (evaluadosPct / 100).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor:
                          subject.color.withValues(alpha: 0.12),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(subject.color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${evaluadosPct.toStringAsFixed(0)}% evaluado · acumulado ${acumulado.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
