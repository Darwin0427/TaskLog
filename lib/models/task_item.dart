import 'package:cloud_firestore/cloud_firestore.dart';

class TaskItem {
  final String id;
  final String titulo;
  final String descripcion;
  final String subjectId;
  final String importancia; // 'Alta' | 'Media' | 'Baja'
  final DateTime fechaLimite;
  final DateTime? creadoEn;

  TaskItem({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.subjectId,
    required this.importancia,
    required this.fechaLimite,
    this.creadoEn,
  });

  factory TaskItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TaskItem(
      id: doc.id,
      titulo: (data['titulo'] ?? '') as String,
      descripcion: (data['descripcion'] ?? '') as String,
      subjectId: (data['subjectId'] ?? '') as String,
      importancia: (data['importancia'] ?? 'Media') as String,
      fechaLimite:
          (data['fechaLimite'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'titulo': titulo,
        'descripcion': descripcion,
        'subjectId': subjectId,
        'importancia': importancia,
        'fechaLimite': Timestamp.fromDate(fechaLimite),
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
