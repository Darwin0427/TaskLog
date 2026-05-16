import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String titulo;
  final String contenido;
  final String subjectId;
  final String importancia;
  final String? taskId;
  final DateTime? creadoEn;

  Note({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.subjectId,
    required this.importancia,
    this.taskId,
    this.creadoEn,
  });

  factory Note.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Note(
      id: doc.id,
      titulo: (data['titulo'] ?? '') as String,
      contenido: (data['contenido'] ?? '') as String,
      subjectId: (data['subjectId'] ?? '') as String,
      importancia: (data['importancia'] ?? 'Media') as String,
      taskId: data['taskId'] as String?,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'titulo': titulo,
      'contenido': contenido,
      'subjectId': subjectId,
      'importancia': importancia,
      'creadoEn': FieldValue.serverTimestamp(),
    };
    if (taskId != null) map['taskId'] = taskId;
    return map;
  }
}
