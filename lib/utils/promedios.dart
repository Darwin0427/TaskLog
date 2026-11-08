import '../models/grade_item.dart';

/// Resumen de las notas de una materia.
///
/// - [evaluado]: porcentaje del curso que ya tiene nota (0–100).
/// - [puntos]: lo acumulado sobre 5.0 con esos porcentajes
///   (ej. 4.2 en el 70 % → 2.94 puntos).
/// - [notaActual]: promedio ponderado de lo evaluado (ej. 4.2), o null si
///   no hay nada evaluado.
class ResumenMateria {
  final double evaluado;
  final double puntos;
  final double totalPorcentaje;
  final int cantidad;

  const ResumenMateria({
    required this.evaluado,
    required this.puntos,
    required this.totalPorcentaje,
    required this.cantidad,
  });

  double? get notaActual => evaluado > 0 ? puntos / (evaluado / 100) : null;

  /// Porcentaje que falta por evaluar del 100 %.
  double get faltante => (100 - evaluado).clamp(0, 100).toDouble();

  factory ResumenMateria.de(Iterable<GradeItem> items) {
    var evaluado = 0.0;
    var puntos = 0.0;
    var total = 0.0;
    var n = 0;
    for (final e in items) {
      n++;
      total += e.porcentaje;
      if (e.nota != null) {
        evaluado += e.porcentaje;
        puntos += e.nota! * e.porcentaje / 100;
      }
    }
    return ResumenMateria(
      evaluado: evaluado,
      puntos: puntos,
      totalPorcentaje: total,
      cantidad: n,
    );
  }
}

/// Agrupa las evaluaciones por materia y resume cada una.
Map<String, ResumenMateria> resumirPorMateria(Iterable<GradeItem> items) {
  final grupos = <String, List<GradeItem>>{};
  for (final e in items) {
    grupos.putIfAbsent(e.subjectId, () => []).add(e);
  }
  return grupos.map((k, v) => MapEntry(k, ResumenMateria.de(v)));
}

/// Promedio general: media de la nota actual de las materias que ya tienen
/// algo evaluado. Null si ninguna tiene notas.
double? promedioGeneral(Iterable<ResumenMateria> resumenes) {
  final notas =
      resumenes.map((r) => r.notaActual).whereType<double>().toList();
  if (notas.isEmpty) return null;
  return notas.reduce((a, b) => a + b) / notas.length;
}

/// Nota que hace falta en lo que queda para terminar con [meta].
/// Null si ya no queda nada por evaluar.
double? notaNecesaria(ResumenMateria r, double meta) {
  if (r.faltante <= 0) return null;
  return (meta - r.puntos) / (r.faltante / 100);
}
