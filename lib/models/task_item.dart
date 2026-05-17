import 'package:cloud_firestore/cloud_firestore.dart';

class TaskItem {
  final String id;
  final String titulo;
  final String descripcion;
  final String subjectId;
  final String importancia; // 'Alta' | 'Media' | 'Baja'
  final DateTime fechaLimite;
  final bool completada;
  final DateTime? completadaEn;

  /// Vínculo opcional a un ítem evaluativo (grade item) de la misma materia.
  /// Si está presente, la tarea aporta a la nota del grade item con peso
  /// [pesoEnGradeItem] (0-100) y nota propia [nota].
  final String? gradeItemId;
  final double? pesoEnGradeItem;
  final double? nota;

  final DateTime? creadoEn;

  TaskItem({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.subjectId,
    required this.importancia,
    required this.fechaLimite,
    this.completada = false,
    this.completadaEn,
    this.gradeItemId,
    this.pesoEnGradeItem,
    this.nota,
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
      completada: (data['completada'] as bool?) ?? false,
      completadaEn: (data['completadaEn'] as Timestamp?)?.toDate(),
      gradeItemId: data['gradeItemId'] as String?,
      pesoEnGradeItem: (data['pesoEnGradeItem'] as num?)?.toDouble(),
      nota: (data['nota'] as num?)?.toDouble(),
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'titulo': titulo,
        'descripcion': descripcion,
        'subjectId': subjectId,
        'importancia': importancia,
        'fechaLimite': Timestamp.fromDate(fechaLimite),
        'completada': completada,
        if (gradeItemId != null) 'gradeItemId': gradeItemId,
        if (pesoEnGradeItem != null) 'pesoEnGradeItem': pesoEnGradeItem,
        if (nota != null) 'nota': nota,
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
