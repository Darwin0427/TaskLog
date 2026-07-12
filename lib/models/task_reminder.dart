import 'package:flutter/foundation.dart';

/// Un recordatorio programado para una tarea.
///
/// Se describe como "N días antes del vencimiento, a las HH:MM". La fecha
/// absoluta se calcula al momento de programar la notificación restando
/// `diasAntes` a la fecha límite y aplicando la `hora` y `minuto`.
///
/// Ejemplo: para una tarea que vence el 30 de mayo, un `TaskReminder`
/// con `diasAntes: 3, hora: 9, minuto: 0` se resuelve al 27 de mayo 9:00 AM.
@immutable
class TaskReminder {
  /// Cuántos días antes del vencimiento se dispara.
  /// 0 = el mismo día del vencimiento.
  final int diasAntes;

  /// Hora del día en formato 24 horas (0-23).
  final int hora;

  /// Minuto (0-59).
  final int minuto;

  const TaskReminder({
    required this.diasAntes,
    required this.hora,
    required this.minuto,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'diasAntes': diasAntes,
        'hora': hora,
        'minuto': minuto,
      };

  factory TaskReminder.fromMap(Map<String, dynamic> m) => TaskReminder(
        diasAntes: (m['diasAntes'] as num?)?.toInt() ?? 0,
        hora: (m['hora'] as num?)?.toInt() ?? 9,
        minuto: (m['minuto'] as num?)?.toInt() ?? 0,
      );

  /// Calcula el `DateTime` local al que este recordatorio debería
  /// disparar, dado el vencimiento de la tarea.
  DateTime resolverFecha(DateTime fechaLimite) {
    final base = fechaLimite.subtract(Duration(days: diasAntes));
    return DateTime(base.year, base.month, base.day, hora, minuto);
  }

  /// Etiqueta legible del "cuánto antes": "el día de", "1 día antes",
  /// "1 semana antes", "3 días antes"...
  String get labelRelativo {
    if (diasAntes == 0) return 'el día de';
    if (diasAntes == 1) return '1 día antes';
    if (diasAntes == 7) return '1 semana antes';
    return '$diasAntes días antes';
  }

  /// Etiqueta de hora en formato 24h con dos dígitos ("09:00", "21:15").
  /// Elegimos 24h para que sea consistente con el TimePicker (que forzamos
  /// a 24h) y evitar la ambigüedad AM/PM.
  String get labelHora {
    final h = hora.toString().padLeft(2, '0');
    final m = minuto.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TaskReminder copyWith({int? diasAntes, int? hora, int? minuto}) {
    return TaskReminder(
      diasAntes: diasAntes ?? this.diasAntes,
      hora: hora ?? this.hora,
      minuto: minuto ?? this.minuto,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskReminder &&
      other.diasAntes == diasAntes &&
      other.hora == hora &&
      other.minuto == minuto;

  @override
  int get hashCode => Object.hash(diasAntes, hora, minuto);
}
