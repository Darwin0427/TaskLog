import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_state.dart';
import '../forms/crear_nota_screen.dart';

/// Abre un apunte existente. Ver y editar son la misma pantalla (el
/// editor de apuntes), así que aquí solo se carga el apunte por su ID.
class DetalleNotaScreen extends StatelessWidget {
  final String noteId;
  const DetalleNotaScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Note?>(
      future: FirestoreService.instance.getNote(noteId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final nota = snap.data;
        if (nota == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: 'Apunte no encontrado',
              subtitle: 'Es posible que lo hayas eliminado.',
            ),
          );
        }
        return CrearNotaScreen(key: ValueKey(nota.id), existing: nota);
      },
    );
  }
}
