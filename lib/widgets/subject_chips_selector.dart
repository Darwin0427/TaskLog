import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';
import 'empty_state.dart';

/// Fila de chips para seleccionar una materia. Carga las materias desde
/// Firestore vía StreamBuilder. Si no hay materias, muestra un mensaje
/// pidiendo crear una primero.
class SubjectChipsSelector extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const SubjectChipsSelector({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 24,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final subjects = snap.data ?? const <Subject>[];
        if (subjects.isEmpty) {
          return Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.school_outlined,
                title: 'Aún no tienes materias',
                subtitle:
                    'Ve a la pestaña Calificaciones para crear una materia primero.',
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subjects.map((s) {
            final selected = s.id == selectedId;
            return ChoiceChip(
              label: Text(s.nombre),
              selected: selected,
              onSelected: (_) => onChanged(s.id),
              selectedColor: s.color.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: selected ? s.color : null,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
              avatar: Icon(s.icon, size: 18, color: s.color),
            );
          }).toList(),
        );
      },
    );
  }
}
