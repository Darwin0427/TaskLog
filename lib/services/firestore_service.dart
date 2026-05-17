import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/grade_item.dart';
import '../models/note.dart';
import '../models/subject.dart';
import '../models/task_item.dart';

/// Resumen de cuántos hijos tiene una materia. Útil para decidir si se
/// puede borrar.
class SubjectChildrenCount {
  final int tasks;
  final int notes;
  final int gradeItems;
  const SubjectChildrenCount({
    required this.tasks,
    required this.notes,
    required this.gradeItems,
  });

  int get total => tasks + notes + gradeItems;
  bool get isEmpty => total == 0;
}

/// Servicio centralizado de Firestore. Todas las colecciones viven bajo
/// `users/{uid}/...`.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(_uid).collection(name);

  /// Fuerza un re-fetch desde el servidor reciclando la conexión.
  /// Útil para el gesto "pull to refresh", aunque los Streams ya se
  /// mantienen sincronizados automáticamente.
  Future<void> refreshFromServer() async {
    try {
      await _db.disableNetwork();
      await _db.enableNetwork();
    } catch (_) {
      // Ignoramos errores aquí: si no hay red, el caché local sigue activo.
    }
  }

  // ─────────────────────────── Subjects ───────────────────────────

  Stream<List<Subject>> watchSubjects() {
    return _col('subjects').orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Subject.fromDoc).toList(),
        );
  }

  Future<void> addSubject(Subject subject) async {
    await _col('subjects').add(subject.toMap());
  }

  Future<void> updateSubject(String id, Subject subject) async {
    // Solo actualizamos los campos editables, no `creadoEn`.
    final data = <String, dynamic>{
      'nombre': subject.nombre,
      'color': subject.colorHex,
      'iconName': subject.iconName,
    };
    // Para campos opcionales: si están vacíos los borramos del documento;
    // si tienen valor los guardamos.
    data['profesor'] =
        (subject.profesor != null && subject.profesor!.isNotEmpty)
            ? subject.profesor
            : FieldValue.delete();
    data['aula'] = (subject.aula != null && subject.aula!.isNotEmpty)
        ? subject.aula
        : FieldValue.delete();
    data['classLinkUrl'] =
        (subject.classLinkUrl != null && subject.classLinkUrl!.isNotEmpty)
            ? subject.classLinkUrl
            : FieldValue.delete();
    await _col('subjects').doc(id).update(data);
  }

  Future<void> deleteSubject(String id) async {
    await _col('subjects').doc(id).delete();
  }

  /// Cuenta cuántos documentos hijos (tareas, notas, gradeItems) están
  /// asociados a esta materia. Útil para bloquear el borrado si tiene
  /// dependencias.
  Future<SubjectChildrenCount> countSubjectChildren(String subjectId) async {
    final futures = await Future.wait(<Future<AggregateQuerySnapshot>>[
      _col('tasks').where('subjectId', isEqualTo: subjectId).count().get(),
      _col('notes').where('subjectId', isEqualTo: subjectId).count().get(),
      _col('gradeItems')
          .where('subjectId', isEqualTo: subjectId)
          .count()
          .get(),
    ]);
    return SubjectChildrenCount(
      tasks: futures[0].count ?? 0,
      notes: futures[1].count ?? 0,
      gradeItems: futures[2].count ?? 0,
    );
  }

  // ─────────────────────────── Tasks ──────────────────────────────

  Stream<List<TaskItem>> watchTasks() {
    return _col('tasks').orderBy('fechaLimite').snapshots().map(
          (snap) => snap.docs.map(TaskItem.fromDoc).toList(),
        );
  }

  /// Lista las tareas asociadas a un grade item concreto (sub-tareas que
  /// aportan a su nota).
  Stream<List<TaskItem>> watchTasksByGradeItem(String gradeItemId) {
    return _col('tasks')
        .where('gradeItemId', isEqualTo: gradeItemId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(TaskItem.fromDoc).toList();
      list.sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
      return list;
    });
  }

  /// Recalcula la nota de un grade item basándose en su tarea vinculada.
  /// Una tarea = una calificación: la nota del grade item es la nota de
  /// su tarea vinculada (si hay tarea vinculada con nota), o null.
  /// Si no hay tarea vinculada, no toca la nota del grade item.
  Future<void> _recalcGradeItemNota(String gradeItemId) async {
    final snap = await _col('tasks')
        .where('gradeItemId', isEqualTo: gradeItemId)
        .get();
    if (snap.docs.isEmpty) return;

    // Tomamos la nota de la primera tarea vinculada (debería ser la única).
    final task = TaskItem.fromDoc(snap.docs.first);
    await _col('gradeItems').doc(gradeItemId).update(<String, dynamic>{
      'nota': task.nota,
    });
  }

  Stream<List<TaskItem>> watchTasksBySubject(String subjectId) {
    // Nota: no usamos `.orderBy('fechaLimite')` en el query porque combinar
    // where + orderBy en campos distintos requiere un índice compuesto en
    // Firestore. Ordenamos en cliente para evitar tener que crear índices.
    return _col('tasks')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(TaskItem.fromDoc).toList();
      list.sort((a, b) => a.fechaLimite.compareTo(b.fechaLimite));
      return list;
    });
  }

  Future<void> addTask(TaskItem task) async {
    await _col('tasks').add(task.toMap());
    // Si la tarea aporta a un grade item, recalcular la nota agregada.
    if (task.gradeItemId != null) {
      await _recalcGradeItemNota(task.gradeItemId!);
    }
  }

  Future<void> updateTask(String id, TaskItem task) async {
    // Saber el gradeItemId anterior por si cambió la asociación,
    // para recalcular tanto el viejo como el nuevo.
    final prevDoc = await _col('tasks').doc(id).get();
    final prevGradeItemId = prevDoc.data()?['gradeItemId'] as String?;

    final data = <String, dynamic>{
      'titulo': task.titulo,
      'descripcion': task.descripcion,
      'subjectId': task.subjectId,
      'importancia': task.importancia,
      'fechaLimite': Timestamp.fromDate(task.fechaLimite),
    };
    // Campos opcionales del vínculo a un grade item: si están en null,
    // los borramos del documento.
    data['gradeItemId'] =
        task.gradeItemId ?? FieldValue.delete();
    data['pesoEnGradeItem'] =
        task.pesoEnGradeItem ?? FieldValue.delete();
    data['nota'] = task.nota ?? FieldValue.delete();
    await _col('tasks').doc(id).update(data);

    // Recalcular ambos grade items afectados (el anterior y el nuevo,
    // si difieren).
    final affected = <String>{};
    if (prevGradeItemId != null) affected.add(prevGradeItemId);
    if (task.gradeItemId != null) affected.add(task.gradeItemId!);
    for (final gid in affected) {
      await _recalcGradeItemNota(gid);
    }
  }

  /// Marca una tarea como completada o pendiente. Si `completada == true`
  /// también registra el timestamp en `completadaEn`.
  Future<void> setTaskCompletada(String id, bool completada) async {
    await _col('tasks').doc(id).update(<String, dynamic>{
      'completada': completada,
      'completadaEn':
          completada ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  /// Borra una tarea y todas sus notas asociadas (con `taskId == id`).
  /// Si la tarea aportaba a un grade item, recalcula su nota.
  Future<void> deleteTask(String id) async {
    // Capturar gradeItemId antes de borrar para poder recalcular después.
    final doc = await _col('tasks').doc(id).get();
    final gradeItemId = doc.data()?['gradeItemId'] as String?;

    final batch = _db.batch();
    batch.delete(_col('tasks').doc(id));
    final notesSnap =
        await _col('notes').where('taskId', isEqualTo: id).get();
    for (final n in notesSnap.docs) {
      batch.delete(n.reference);
    }
    await batch.commit();

    if (gradeItemId != null) {
      await _recalcGradeItemNota(gradeItemId);
    }
  }

  Future<TaskItem?> getTask(String id) async {
    final doc = await _col('tasks').doc(id).get();
    if (!doc.exists) return null;
    return TaskItem.fromDoc(doc);
  }

  /// Escucha cambios sobre una sola tarea (tiempo real).
  Stream<TaskItem?> watchTask(String id) {
    return _col('tasks').doc(id).snapshots().map(
          (doc) => doc.exists ? TaskItem.fromDoc(doc) : null,
        );
  }

  // ─────────────────────────── Notes ──────────────────────────────

  Stream<List<Note>> watchNotes() {
    return _col('notes').orderBy('creadoEn', descending: true).snapshots().map(
          (snap) => snap.docs.map(Note.fromDoc).toList(),
        );
  }

  Stream<List<Note>> watchNotesBySubject(String subjectId) {
    return _col('notes')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Note.fromDoc).toList();
      list.sort((a, b) {
        final ad = a.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  Stream<List<Note>> watchNotesByTask(String taskId) {
    return _col('notes')
        .where('taskId', isEqualTo: taskId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Note.fromDoc).toList();
      list.sort((a, b) {
        final ad = a.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  Future<void> addNote(Note note) async {
    await _col('notes').add(note.toMap());
  }

  Future<void> updateNote(String id, Note note) async {
    final data = <String, dynamic>{
      'titulo': note.titulo,
      'contenido': note.contenido,
      'subjectId': note.subjectId,
      'importancia': note.importancia,
    };
    if (note.taskId != null) {
      data['taskId'] = note.taskId;
    } else {
      data['taskId'] = FieldValue.delete();
    }
    await _col('notes').doc(id).update(data);
  }

  Future<void> deleteNote(String id) async {
    await _col('notes').doc(id).delete();
  }

  Future<Note?> getNote(String id) async {
    final doc = await _col('notes').doc(id).get();
    if (!doc.exists) return null;
    return Note.fromDoc(doc);
  }

  /// Escucha cambios sobre una sola nota (tiempo real).
  Stream<Note?> watchNote(String id) {
    return _col('notes').doc(id).snapshots().map(
          (doc) => doc.exists ? Note.fromDoc(doc) : null,
        );
  }

  // ─────────────────────────── Grade Items ────────────────────────

  Stream<List<GradeItem>> watchGradeItemsBySubject(String subjectId) {
    return _col('gradeItems')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(GradeItem.fromDoc).toList();
      list.sort((a, b) {
        final ad = a.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.creadoEn ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });
      return list;
    });
  }

  Future<List<GradeItem>> getGradeItemsBySubject(String subjectId) async {
    final snap = await _col('gradeItems')
        .where('subjectId', isEqualTo: subjectId)
        .get();
    return snap.docs.map(GradeItem.fromDoc).toList();
  }

  Future<void> addGradeItem(GradeItem item) async {
    await _col('gradeItems').add(item.toMap());
  }

  Future<void> updateGradeItem(String id, GradeItem item) async {
    await _col('gradeItems').doc(id).update(<String, dynamic>{
      'nombre': item.nombre,
      'porcentaje': item.porcentaje,
      'nota': item.nota,
    });
  }

  /// Atajo para actualizar solo la nota (caso más común tras una evaluación).
  Future<void> setGradeItemNota(String id, double? nota) async {
    await _col('gradeItems').doc(id).update(<String, dynamic>{
      'nota': nota,
    });
  }

  Future<void> deleteGradeItem(String id) async {
    final batch = _db.batch();
    batch.delete(_col('gradeItems').doc(id));
    // Limpiar el vínculo en las tareas que apuntaban a este grade item.
    final tasksSnap =
        await _col('tasks').where('gradeItemId', isEqualTo: id).get();
    for (final doc in tasksSnap.docs) {
      batch.update(doc.reference, <String, dynamic>{
        'gradeItemId': FieldValue.delete(),
        'pesoEnGradeItem': FieldValue.delete(),
        // La nota la conservamos: la tarea sigue calificada aunque su grupo
        // padre ya no exista.
      });
    }
    await batch.commit();
  }
}
