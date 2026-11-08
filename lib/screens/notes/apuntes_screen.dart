import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/subject.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tasklog_tab_bar.dart';
import 'detalle_nota_screen.dart';

/// Pestaña Apuntes: todos los apuntes del usuario, del más reciente al más
/// antiguo, sin importar la materia.
///
/// Versión base (fase 1 del rediseño). El buscador, el filtro por materia
/// y la agrupación por fecha llegan en la fase 2.
class ApuntesScreen extends StatelessWidget {
  const ApuntesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apuntes')),
      body: StreamBuilder<List<Subject>>(
        stream: FirestoreService.instance.watchSubjects(),
        builder: (context, subjSnap) {
          final materias = <String, Subject>{
            for (final s in subjSnap.data ?? const <Subject>[]) s.id: s,
          };
          return StreamBuilder<List<Note>>(
            stream: FirestoreService.instance.watchNotes(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final notas = snap.data ?? const <Note>[];
              if (notas.isEmpty) {
                return const EmptyState(
                  icon: Icons.edit_note_rounded,
                  title: 'No tienes apuntes',
                  subtitle: 'Toca el botón + para escribir el primero.',
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  TaskLogTabBar.espacioInferior(context),
                ),
                itemCount: notas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ApunteCard(
                  nota: notas[i],
                  materia: materias[notas[i].subjectId],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApunteCard extends StatelessWidget {
  final Note nota;
  final Subject? materia;

  const _ApunteCard({required this.nota, required this.materia});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final fecha = nota.creadoEn;
    final primeraLinea = nota.contenido
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetalleNotaScreen(noteId: nota.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nota.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (fecha != null)
                    Text(
                      DateFormat('d MMM', 'es').format(fecha),
                      style: TextStyle(fontSize: 13, color: p.texto2),
                    ),
                ],
              ),
              if (primeraLinea.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  primeraLinea,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: p.texto2),
                ),
              ],
              if (materia != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: materia!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      materia!.nombre,
                      style: TextStyle(fontSize: 13, color: p.texto2),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
