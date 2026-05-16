import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/grade_item.dart';
import '../models/note.dart';
import '../models/subject.dart';
import '../models/task_item.dart';

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

  // ─────────────────────────── Subjects ───────────────────────────

  Stream<List<Subject>> watchSubjects() {
    return _col('subjects').orderBy('nombre').snapshots().map(
          (snap) => snap.docs.map(Subject.fromDoc).toList(),
        );
  }

  Future<void> addSubject(Subject subject) async {
    await _col('subjects').add(subject.toMap());
  }

  // ─────────────────────────── Tasks ──────────────────────────────

  Stream<List<TaskItem>> watchTasks() {
    return _col('tasks').orderBy('fechaLimite').snapshots().map(
          (snap) => snap.docs.map(TaskItem.fromDoc).toList(),
        );
  }

  Stream<List<TaskItem>> watchTasksBySubject(String subjectId) {
    return _col('tasks')
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('fechaLimite')
        .snapshots()
        .map((snap) => snap.docs.map(TaskItem.fromDoc).toList());
  }

  Future<void> addTask(TaskItem task) async {
    await _col('tasks').add(task.toMap());
  }

  Future<TaskItem?> getTask(String id) async {
    final doc = await _col('tasks').doc(id).get();
    if (!doc.exists) return null;
    return TaskItem.fromDoc(doc);
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
}
