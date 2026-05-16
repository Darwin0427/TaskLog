import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../forms/crear_materia_screen.dart';
import 'detalle_materia_screen.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificaciones'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await AuthService.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
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
            return Stack(
              children: [
                const EmptyState(
                  icon: Icons.school_outlined,
                  title: 'No tienes materias',
                  subtitle:
                      'Toca el botón + para crear tu primera materia.',
                ),
                Positioned(
                  bottom: 96,
                  right: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'fab_grades_empty',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CrearMateriaScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva materia'),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          }
          return Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _SubjectCard(subject: subjects[i]),
              ),
              Positioned(
                bottom: 96,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_grades',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CrearMateriaScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Materia'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
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
