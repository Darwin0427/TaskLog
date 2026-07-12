import 'package:cloud_firestore/cloud_firestore.dart';

import 'task_reminder.dart';

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

  /// Lista de recordatorios programados para esta tarea.
  /// Vacía por defecto. Se persiste en Firestore como array de mapas.
  final List<TaskReminder> recordatorios;

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
    this.recordatorios = const <TaskReminder>[],
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
      recordatorios: ((data['recordatorios'] as List?) ?? const [])
          .map((m) => TaskReminder.fromMap(m as Map<String, dynamic>))
          .toList(),
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
        'recordatorios': recordatorios.map((r) => r.toMap()).toList(),
        'creadoEn': FieldValue.serverTimestamp(),
      };

  /// Copia inmutable con campos sobreescritos. Útil, por ejemplo, para
  /// asignar el ID recién generado por Firestore después de `add`.
  TaskItem copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    String? subjectId,
    String? importancia,
    DateTime? fechaLimite,
    bool? completada,
    DateTime? completadaEn,
    String? gradeItemId,
    double? pesoEnGradeItem,
    double? nota,
    List<TaskReminder>? recordatorios,
    DateTime? creadoEn,
  }) {
    return TaskItem(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      subjectId: subjectId ?? this.subjectId,
      importancia: importancia ?? this.importancia,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      completada: completada ?? this.completada,
      completadaEn: completadaEn ?? this.completadaEn,
      gradeItemId: gradeItemId ?? this.gradeItemId,
      pesoEnGradeItem: pesoEnGradeItem ?? this.pesoEnGradeItem,
      nota: nota ?? this.nota,
      recordatorios: recordatorios ?? this.recordatorios,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
