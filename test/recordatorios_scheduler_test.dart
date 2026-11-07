import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas/models/task_item.dart';
import 'package:gestor_tareas/models/task_reminder.dart';
import 'package:gestor_tareas/utils/recordatorios_scheduler.dart';

TaskItem _tarea(
  String id,
  DateTime fechaLimite,
  List<TaskReminder> recordatorios, {
  bool completada = false,
}) {
  return TaskItem(
    id: id,
    titulo: 'Tarea $id',
    descripcion: '',
    subjectId: 'materia',
    importancia: 'Media',
    fechaLimite: fechaLimite,
    completada: completada,
    recordatorios: recordatorios,
  );
}

void main() {
  final ahora = DateTime(2026, 11, 10, 12, 0);

  group('TaskReminder.resolverFecha', () {
    test('resta los días y aplica la hora indicada', () {
      const r = TaskReminder(diasAntes: 3, hora: 9, minuto: 30);
      expect(
        r.resolverFecha(DateTime(2026, 5, 30, 23, 59)),
        DateTime(2026, 5, 27, 9, 30),
      );
    });

    test('cruza correctamente el cambio de mes', () {
      const r = TaskReminder(diasAntes: 7, hora: 8, minuto: 0);
      expect(
        r.resolverFecha(DateTime(2026, 12, 3)),
        DateTime(2026, 11, 26, 8, 0),
      );
    });
  });

  group('seleccionarProximosRecordatorios', () {
    test('omite tareas completadas y recordatorios que ya pasaron', () {
      final tareas = [
        _tarea('pasada', DateTime(2026, 11, 10), const [
          TaskReminder(diasAntes: 0, hora: 9, minuto: 0), // 10 nov 9:00, ya pasó
          TaskReminder(diasAntes: 0, hora: 18, minuto: 0), // 10 nov 18:00
        ]),
        _tarea(
          'hecha',
          DateTime(2026, 11, 20),
          const [TaskReminder(diasAntes: 1, hora: 9, minuto: 0)],
          completada: true,
        ),
      ];

      final r = seleccionarProximosRecordatorios(
        tareas,
        ahora: ahora,
        limite: 60,
      );

      expect(r, hasLength(1));
      expect(r.single.task.id, 'pasada');
      expect(r.single.indice, 1);
      expect(r.single.fecha, DateTime(2026, 11, 10, 18, 0));
    });

    test('ordena por fecha y respeta el límite', () {
      final tareas = <TaskItem>[
        for (var i = 0; i < 30; i++)
          _tarea('t$i', DateTime(2026, 12, 1).add(Duration(days: i)), const [
            TaskReminder(diasAntes: 7, hora: 9, minuto: 0),
            TaskReminder(diasAntes: 3, hora: 9, minuto: 0),
            TaskReminder(diasAntes: 1, hora: 9, minuto: 0),
            TaskReminder(diasAntes: 0, hora: 9, minuto: 0),
          ]),
      ];

      final r = seleccionarProximosRecordatorios(
        tareas,
        ahora: ahora,
        limite: 60,
      );

      expect(r, hasLength(60)); // 120 candidatos, solo 60 caben
      for (var i = 1; i < r.length; i++) {
        expect(r[i].fecha.isBefore(r[i - 1].fecha), isFalse);
      }
      // El primero es el más próximo: t0, 7 días antes del 1 de diciembre.
      expect(r.first.task.id, 't0');
      expect(r.first.fecha, DateTime(2026, 11, 24, 9, 0));
    });

    test('límite cero no programa nada', () {
      final tareas = [
        _tarea('t', DateTime(2026, 12, 1),
            const [TaskReminder(diasAntes: 1, hora: 9, minuto: 0)]),
      ];
      expect(
        seleccionarProximosRecordatorios(tareas, ahora: ahora, limite: 0),
        isEmpty,
      );
    });
  });
}
