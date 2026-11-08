import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/grade_item.dart';
import '../models/note.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import 'notification_service.dart';

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

  /// Vuelve a calcular qué recordatorios quedan programados en el sistema
  /// a partir de todas las tareas del usuario.
  ///
  /// Con [soloCache] lee del caché local (instantáneo y funciona sin red);
  /// es lo que se usa justo después de crear/editar una tarea, porque la
  /// escritura ya está en el caché. Al abrir la app se usa `false` para
  /// traer también lo que haya cambiado desde otro dispositivo.
  Future<void> sincronizarRecordatorios({bool soloCache = true}) async {
    try {
      final snap = await _col('tasks').get(GetOptions(
        source: soloCache ? Source.cache : Source.serverAndCache,
      ));
      final tareas = snap.docs.map(TaskItem.fromDoc).toList();
      await NotificationService.instance.sincronizarRecordatorios(tareas);
    } catch (e) {
      debugPrint('[Firestore] sincronizarRecordatorios falló: $e');
    }
  }

  /// Lanza una escritura sin esperar a que llegue al servidor.
  ///
  /// Firestore aplica el cambio al instante en el caché del teléfono (la
  /// pantalla se actualiza enseguida) y lo sube cuando hay conexión. Si
  /// se esperara al servidor, sin internet la app quedaría "guardando…"
  /// para siempre.
  void _enSegundoPlano(Future<Object?> escritura) {
    unawaited(
      escritura.then<void>((_) {}, onError: (Object e) {
        debugPrint('[Firestore] escritura en segundo plano falló: $e');
      }),
    );
  }

  /// Borra todos los documentos del usuario (se usa al eliminar la
  /// cuenta). Va por lotes de 400 porque Firestore acepta máximo 500
  /// operaciones por lote.
  Future<void> borrarTodosLosDatos() async {
    for (final nombre in const ['tasks', 'notes', 'gradeItems', 'subjects']) {
      while (true) {
        final snap = await _col(nombre).limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
  }

  // ─────────────────────────── Subjects ───────────────────────────

  Stream<List<Subject>> watchSubjects() {
    return _col('subjects').orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Subject.fromDoc).toList(),
        );
  }

  Future<void> addSubject(Subject subject) async {
    _enSegundoPlano(_col('subjects').add(subject.toMap()));
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
    data['horario'] = (subject.horario != null && subject.horario!.isNotEmpty)
        ? subject.horario
        : FieldValue.delete();
    _enSegundoPlano(_col('subjects').doc(id).update(data));
  }

  /// Guarda la meta de nota final de una materia (ej. 3.5). Null la borra.
  Future<void> setSubjectMeta(String id, double? meta) async {
    _enSegundoPlano(_col('subjects').doc(id).update(<String, dynamic>{
      'meta': meta ?? FieldValue.delete(),
    }));
  }

  Future<void> deleteSubject(String id) async {
    _enSegundoPlano(_col('subjects').doc(id).delete());
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
    if (snap.docs.isEmpty) {
      // Ya no hay tareas vinculadas: la nota venía de la tarea, así que la
      // evaluación vuelve a quedar sin nota (antes se quedaba con la nota
      // vieja y contaba en el promedio).
      try {
        await _col('gradeItems').doc(gradeItemId).update(<String, dynamic>{
          'nota': null,
        });
      } on FirebaseException catch (e) {
        // La evaluación pudo haberse borrado; no es un error.
        if (e.code != 'not-found') rethrow;
      }
      return;
    }

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

  /// Crea la tarea y devuelve su ID.
  ///
  /// No espera la confirmación del servidor: Firestore guarda primero en
  /// el teléfono y sincroniza después. Así el formulario se cierra al
  /// instante aunque no haya internet (antes se quedaba esperando).
  Future<String> addTask(TaskItem task) async {
    final ref = _col('tasks').doc();
    final escritura = ref.set(task.toMap());
    unawaited(sincronizarRecordatorios());
    unawaited(_despuesDeEscribir(escritura, {task.gradeItemId}));
    return ref.id;
  }

  Future<void> updateTask(String id, TaskItem task) async {
    final ref = _col('tasks').doc(id);
    // Saber el gradeItemId anterior por si cambió la asociación, para
    // recalcular tanto el viejo como el nuevo. Primero del caché (rápido
    // y sin red); si no está, del servidor.
    String? prevGradeItemId;
    try {
      final prev = await ref.get(const GetOptions(source: Source.cache));
      prevGradeItemId = prev.data()?['gradeItemId'] as String?;
    } catch (_) {
      try {
        final prev = await ref.get();
        prevGradeItemId = prev.data()?['gradeItemId'] as String?;
      } catch (_) {}
    }

    final data = <String, dynamic>{
      'titulo': task.titulo,
      'descripcion': task.descripcion,
      'subjectId': task.subjectId,
      'importancia': task.importancia,
      'fechaLimite': Timestamp.fromDate(task.fechaLimite),
      'recordatorios': task.recordatorios.map((r) => r.toMap()).toList(),
    };
    // Campos opcionales del vínculo a un grade item: si están en null,
    // los borramos del documento.
    data['gradeItemId'] = task.gradeItemId ?? FieldValue.delete();
    data['pesoEnGradeItem'] = task.pesoEnGradeItem ?? FieldValue.delete();
    data['nota'] = task.nota ?? FieldValue.delete();
    final escritura = ref.update(data);

    // Reprogramar recordatorios: si cambió la fecha límite o la lista de
    // recordatorios, se ajusta automáticamente.
    unawaited(sincronizarRecordatorios());
    unawaited(
      _despuesDeEscribir(escritura, {prevGradeItemId, task.gradeItemId}),
    );
  }

  /// Espera a que una escritura llegue al servidor y luego recalcula las
  /// notas de las evaluaciones afectadas. Corre en segundo plano.
  Future<void> _despuesDeEscribir(
    Future<void> escritura,
    Set<String?> evaluaciones,
  ) async {
    try {
      await escritura;
      for (final gid in evaluaciones.whereType<String>()) {
        await _recalcGradeItemNota(gid);
      }
    } catch (e) {
      debugPrint('[Firestore] escritura en segundo plano falló: $e');
    }
  }

  /// Marca una tarea como completada o pendiente. Si `completada == true`
  /// también registra el timestamp en `completadaEn`.
  Future<void> setTaskCompletada(String id, bool completada) async {
    // Sin esperar al servidor: el cambio se ve al instante también sin red.
    unawaited(
      _col('tasks')
          .doc(id)
          .update(<String, dynamic>{
            'completada': completada,
            'completadaEn': completada
                ? FieldValue.serverTimestamp()
                : FieldValue.delete(),
          })
          .catchError((Object e) => debugPrint('[Firestore] completar: $e')),
    );

    // Completada → sus recordatorios salen de la selección.
    // Reactivada → vuelven los que aún no hayan disparado.
    unawaited(sincronizarRecordatorios());
  }

  /// Borra una tarea y todas sus notas asociadas (con `taskId == id`).
  /// Si la tarea aportaba a un grade item, recalcula su nota.
  /// Cancela también todas sus notificaciones pendientes.
  Future<void> deleteTask(String id) async {
    // Cancelar ya sus recordatorios; la sincronización de abajo rellena
    // los cupos que queden libres con los de otras tareas.
    await NotificationService.instance.cancelarRecordatoriosDeTarea(id);

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

    unawaited(sincronizarRecordatorios());
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

  /// Crea el apunte y devuelve su ID (el editor sigue guardando sobre él).
  Future<String> addNote(Note note) async {
    final ref = _col('notes').doc();
    // `set` sobre un ID generado en el teléfono: no espera al servidor para
    // conocer el ID, así que funciona igual sin conexión.
    unawaited(ref.set(note.toMap()));
    return ref.id;
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
    _enSegundoPlano(_col('notes').doc(id).update(data));
  }

  Future<void> deleteNote(String id) async {
    _enSegundoPlano(_col('notes').doc(id).delete());
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

  /// Todas las evaluaciones del usuario (para promedios generales).
  Stream<List<GradeItem>> watchAllGradeItems() {
    return _col('gradeItems').snapshots().map(
          (snap) => snap.docs.map(GradeItem.fromDoc).toList(),
        );
  }

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

  /// Crea la evaluación y devuelve su ID (para vincularle una tarea).
  Future<String> addGradeItem(GradeItem item) async {
    final ref = _col('gradeItems').doc();
    _enSegundoPlano(ref.set(item.toMap()));
    return ref.id;
  }

  Future<void> updateGradeItem(String id, GradeItem item) async {
    _enSegundoPlano(_col('gradeItems').doc(id).update(<String, dynamic>{
      'nombre': item.nombre,
      'porcentaje': item.porcentaje,
      'nota': item.nota,
      'fecha': item.fecha == null
          ? FieldValue.delete()
          : Timestamp.fromDate(item.fecha!),
    }));
  }

  /// Atajo para actualizar solo la nota (caso más común tras una evaluación).
  Future<void> setGradeItemNota(String id, double? nota) async {
    _enSegundoPlano(_col('gradeItems').doc(id).update(<String, dynamic>{
      'nota': nota,
    }));
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
