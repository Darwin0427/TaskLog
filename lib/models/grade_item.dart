import 'package:cloud_firestore/cloud_firestore.dart';

class GradeItem {
  final String id;
  final String subjectId;
  final String nombre;
  final double porcentaje;
  final double? nota;

  /// Fecha de la evaluación (opcional, ej. el día del parcial).
  final DateTime? fecha;

  final DateTime? creadoEn;

  GradeItem({
    required this.id,
    required this.subjectId,
    required this.nombre,
    required this.porcentaje,
    this.nota,
    this.fecha,
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
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'subjectId': subjectId,
        'nombre': nombre,
        'porcentaje': porcentaje,
        'nota': nota,
        if (fecha != null) 'fecha': Timestamp.fromDate(fecha!),
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
