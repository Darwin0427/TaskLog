import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Selectores de fecha y hora con las ruedas de iOS, en una hoja que sube
/// desde abajo con «Cancelar» y «Listo».
///
/// Reemplazan a `showTimePicker`/`showDatePicker` de Material, que en
/// iPhone se sienten ajenos (y el de hora obligaba a teclear 24 h).

/// Devuelve la hora elegida, o `null` si el usuario canceló.
///
/// Usa el formato del iPhone: 12 h (a. m./p. m.) o 24 h según su ajuste.
Future<TimeOfDay?> elegirHora(
  BuildContext context, {
  required TimeOfDay inicial,
  String titulo = 'Hora',
}) async {
  final base = DateTime(2000, 1, 1, inicial.hour, inicial.minute);
  final elegido = await _mostrarRueda(
    context,
    titulo: titulo,
    inicial: base,
    modo: CupertinoDatePickerMode.time,
  );
  if (elegido == null) return null;
  return TimeOfDay(hour: elegido.hour, minute: elegido.minute);
}

/// Devuelve la fecha elegida (a medianoche), o `null` si el usuario canceló.
Future<DateTime?> elegirFecha(
  BuildContext context, {
  required DateTime inicial,
  required DateTime primera,
  required DateTime ultima,
  String titulo = 'Fecha',
}) async {
  var valor = DateTime(inicial.year, inicial.month, inicial.day);
  if (valor.isBefore(primera)) valor = primera;
  if (valor.isAfter(ultima)) valor = ultima;
  final elegido = await _mostrarRueda(
    context,
    titulo: titulo,
    inicial: valor,
    modo: CupertinoDatePickerMode.date,
    minimo: primera,
    maximo: ultima,
  );
  if (elegido == null) return null;
  return DateTime(elegido.year, elegido.month, elegido.day);
}

Future<DateTime?> _mostrarRueda(
  BuildContext context, {
  required String titulo,
  required DateTime inicial,
  required CupertinoDatePickerMode modo,
  DateTime? minimo,
  DateTime? maximo,
}) {
  var seleccion = inicial;
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: false,
    builder: (ctx) {
      final p = TaskLogPalette.of(ctx);
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  Expanded(
                    child: Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.texto,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(seleccion),
                    child: const Text(
                      'Listo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: p.texto,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: modo,
                  initialDateTime: inicial,
                  minimumDate: minimo,
                  maximumDate: maximo,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
                  onDateTimeChanged: (v) => seleccion = v,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
