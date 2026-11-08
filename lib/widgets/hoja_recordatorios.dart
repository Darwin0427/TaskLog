import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task_reminder.dart';
import '../services/notification_setup_service.dart';
import '../theme/app_theme.dart';
import 'ios_ui.dart';
import 'selectores_ios.dart';

/// Abre la hoja «Recordarme». Devuelve la lista nueva de recordatorios, o
/// null si se cerró sin guardar.
///
/// Muestra las cuatro opciones de siempre (el día de, 1 día, 3 días y
/// 1 semana antes) con su fecha real al lado, se pueden marcar varias, y
/// abajo «Fecha y hora» para un recordatorio personalizado.
Future<List<TaskReminder>?> mostrarHojaRecordatorios(
  BuildContext context, {
  required DateTime fechaLimite,
  required List<TaskReminder> actuales,
}) {
  return abrirHojaMedia<List<TaskReminder>>(
    context,
    _HojaRecordatorios(fechaLimite: fechaLimite, inicial: actuales),
  );
}

/// Días antes de las opciones fijas.
const List<int> diasPreset = <int>[0, 1, 3, 7];

String nombrePreset(int dias) => switch (dias) {
      0 => 'El día de, en la mañana',
      1 => '1 día antes',
      3 => '3 días antes',
      7 => '1 semana antes',
      _ => '$dias días antes',
    };

class _HojaRecordatorios extends StatefulWidget {
  final DateTime fechaLimite;
  final List<TaskReminder> inicial;

  const _HojaRecordatorios({required this.fechaLimite, required this.inicial});

  @override
  State<_HojaRecordatorios> createState() => _HojaRecordatoriosState();
}

class _HojaRecordatoriosState extends State<_HojaRecordatorios> {
  late final List<TaskReminder> _lista =
      List<TaskReminder>.from(widget.inicial);
  late DateTime _fechaCustom = _sugerida();
  TimeOfDay _horaCustom = const TimeOfDay(hour: 20, minute: 0);
  late final Future<bool> _permiso =
      NotificationSetupService.instance.hasNotificationPermission();

  DateTime _sugerida() {
    final d = soloDia(widget.fechaLimite).subtract(const Duration(days: 2));
    final hoy = soloDia(DateTime.now());
    return d.isBefore(hoy) ? hoy : d;
  }

  TaskReminder? _preset(int dias) {
    for (final r in _lista) {
      if (r.diasAntes == dias) return r;
    }
    return null;
  }

  void _togglePreset(int dias) {
    setState(() {
      final existente = _preset(dias);
      if (existente != null) {
        _lista.remove(existente);
      } else {
        _lista.add(TaskReminder(diasAntes: dias, hora: 9, minuto: 0));
      }
    });
  }

  void _agregarPersonalizado() {
    final dias = soloDia(widget.fechaLimite)
        .difference(soloDia(_fechaCustom))
        .inDays;
    if (dias < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El recordatorio debe ser antes de la fecha límite.'),
        ),
      );
      return;
    }
    setState(() {
      _lista.removeWhere((r) => r.diasAntes == dias);
      _lista.add(TaskReminder(
        diasAntes: dias,
        hora: _horaCustom.hour,
        minuto: _horaCustom.minute,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final df = DateFormat('d MMM', 'es');
    final ahora = DateTime.now();
    final personalizados = _lista
        .where((r) => !diasPreset.contains(r.diasAntes))
        .toList()
      ..sort((a, b) => b.diasAntes.compareTo(a.diasAntes));
    final venceTexto = tieneHora(widget.fechaLimite)
        ? '${df.format(widget.fechaLimite)} a las '
            '${formatearHora(context, widget.fechaLimite)}'
        : df.format(widget.fechaLimite);

    String fechaDe(TaskReminder r) {
      final f = r.resolverFecha(widget.fechaLimite);
      return '${df.format(f)}, ${formatearHora(context, f)}';
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            EncabezadoHoja(
              titulo: 'Recordarme',
              subtitulo: 'La tarea vence el $venceTexto',
              onConfirmar: () => Navigator.of(context).pop(_lista),
            ),
            const SizedBox(height: 8),
            GrupoIOS(
              children: [
                for (final d in diasPreset)
                  Builder(
                    builder: (context) {
                      final r = _preset(d) ??
                          TaskReminder(diasAntes: d, hora: 9, minuto: 0);
                      final paso =
                          r.resolverFecha(widget.fechaLimite).isBefore(ahora);
                      return Opacity(
                        opacity: paso ? 0.4 : 1,
                        child: FilaIOS(
                          titulo: nombrePreset(d),
                          subtitulo: paso ? '${fechaDe(r)} · ya pasó' : fechaDe(r),
                          trailing: _preset(d) != null
                              ? Icon(Icons.check_rounded, color: p.acento)
                              : const SizedBox(width: 24),
                          onTap: () => _togglePreset(d),
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (personalizados.isNotEmpty) ...[
              const EtiquetaGrupo('Tus recordatorios'),
              GrupoIOS(
                children: [
                  for (final r in personalizados)
                    FilaIOS(
                      titulo: fechaDe(r),
                      subtitulo: r.labelRelativo,
                      trailing: IconButton(
                        tooltip: 'Quitar',
                        icon: Icon(Icons.cancel_rounded, color: p.texto2),
                        onPressed: () => setState(() => _lista.remove(r)),
                      ),
                    ),
                ],
              ),
            ],
            const EtiquetaGrupo('Personalizado'),
            GrupoIOS(
              children: [
                FilaIOS(
                  titulo: 'Fecha y hora',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Chip(
                        texto: df.format(_fechaCustom),
                        onTap: () async {
                          final f = await elegirFecha(
                            context,
                            inicial: _fechaCustom,
                            primera: soloDia(ahora),
                            ultima: soloDia(widget.fechaLimite).isBefore(
                                    soloDia(ahora))
                                ? soloDia(ahora)
                                : soloDia(widget.fechaLimite),
                            titulo: 'Fecha del recordatorio',
                          );
                          if (f != null) setState(() => _fechaCustom = f);
                        },
                      ),
                      const SizedBox(width: 6),
                      _Chip(
                        texto: formatearHora(
                          context,
                          DateTime(2000, 1, 1, _horaCustom.hour,
                              _horaCustom.minute),
                        ),
                        onTap: () async {
                          final h = await elegirHora(
                            context,
                            inicial: _horaCustom,
                            titulo: 'Hora del recordatorio',
                          );
                          if (h != null) setState(() => _horaCustom = h);
                        },
                      ),
                    ],
                  ),
                ),
                FilaIOS(
                  leading: Icon(Icons.add_circle_rounded, color: p.acento),
                  tituloWidget: Text(
                    'Añadir este recordatorio',
                    style: TextStyle(fontSize: 17, color: p.acento),
                  ),
                  onTap: _agregarPersonalizado,
                ),
              ],
            ),
            FutureBuilder<bool>(
              future: _permiso,
              builder: (context, snap) {
                if (snap.data != false) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => NotificationSetupService.instance
                        .requestNotificationPermission(),
                    child: const PieGrupo(
                      'Las notificaciones están desactivadas. Toca aquí para '
                      'activarlas.',
                      icono: Icons.notifications_off_rounded,
                      color: AppColors.mediumPriority,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  const _Chip({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: p.grupo2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(texto, style: TextStyle(fontSize: 15, color: p.texto)),
      ),
    );
  }
}
