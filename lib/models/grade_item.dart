import 'package:cloud_firestore/cloud_firestore.dart';

class GradeItem {
  final String id;
  final String subjectId;
  final String nombre;
  final double porcentaje;
  final double? nota;
  final DateTime? creadoEn;

  GradeItem({
    required this.id,
    required this.subjectId,
    required this.nombre,
    required this.porcentaje,
    this.nota,
    this.creadoEn,
  });

  factory GradeItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return GradeItem(
      id: doc.id,
      subjectId: (data['subjectId'] ?? '') as String,
      nombre: (data['nombre'] ?? '') as String,
      porcentaje: (data['porcentaje'] as num?)?.toDouble() ?? 0,
      nota: (data['nota'] as num?)?.toDouble(),
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'subjectId': subjectId,
        'nombre': nombre,
        'porcentaje': porcentaje,
        'nota': nota,
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
