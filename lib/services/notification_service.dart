import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../screens/tasks/detalle_tarea_screen.dart';
import '../utils/recordatorios_scheduler.dart';

/// Servicio centralizado de notificaciones locales, basado en el plugin
/// `awesome_notifications`.
///
/// Migramos de `flutter_local_notifications` porque este último tiene
/// problemas conocidos con MIUI/Xiaomi al usar AlarmManager: el
/// scheduling se registra pero las notificaciones nunca disparan.
/// `awesome_notifications` usa WorkManager internamente, que respeta
/// mejor las políticas de restricción de MIUI.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Key global del Navigator para poder navegar desde el callback de tap.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;

  /// Log interno vía `debugPrint`. Se ve en la consola con
  /// `flutter run` / `adb logcat` durante desarrollo. En release build
  /// no imprime nada.
  void _log(String msg) {
    debugPrint('[NotifService] $msg');
  }

  // ─────────────────────────── configuración ───────────────────────────

  static const String _channelKey = 'recordatorios_tareas';
  static const String _channelName = 'Recordatorios de tareas';
  static const String _channelDescription =
      'Avisos programados de tareas cercanas a vencer';

  /// ID fijo de la notificación de prueba del onboarding.
  static const int _testNotificationId = 777777;

  /// Máximo de recordatorios que dejamos programados a la vez.
  ///
  /// iOS solo guarda 64 notificaciones locales pendientes por app y
  /// descarta las demás en silencio; dejamos margen para la de prueba.
  /// Android no tiene ese tope tan bajo (el sistema limita alrededor de
  /// 500 alarmas por app), así que ahí el margen es mucho mayor.
  static int get limiteProgramadas =>
      defaultTargetPlatform == TargetPlatform.iOS ? 60 : 400;

  /// Cola para que dos sincronizaciones no se pisen entre sí.
  Future<void> _colaSync = Future<void>.value();

  // ─────────────────────────── inicialización ───────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
      _log('tz.local = $localName');
    } catch (e) {
      _log('tz.local no set: $e');
    }

    await AwesomeNotifications().initialize(
      // Ícono de notificación (drawable ya generado en Fase 1 personalización).
      'resource://drawable/ic_stat_notif',
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: _channelName,
          channelDescription: _channelDescription,
          // `Max` (nivel más alto) para que aparezca como banner heads-up
          // y no la pueda silenciar MIUI en background.
          importance: NotificationImportance.Max,
          defaultColor: const Color(0xFF534AB7),
          ledColor: const Color(0xFF534AB7),
          playSound: true,
          enableVibration: true,
          criticalAlerts: false,
          defaultPrivacy: NotificationPrivacy.Public,
          channelShowBadge: true,
        ),
      ],
      debug: !kReleaseMode,
    );

    // Listener para tap sobre la notificación.
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
    );

    _initialized = true;
    _log('inicializado (awesome_notifications)');
  }

  /// Callback estático — awesome_notifications lo invoca en un isolate
  /// separado en escenarios de cold-start, por eso necesita
  /// `@pragma("vm:entry-point")`.
  @pragma('vm:entry-point')
  static Future<void> _onActionReceived(ReceivedAction action) async {
    final taskId = action.payload?['taskId'];
    if (taskId == null || taskId.isEmpty || taskId == 'test') return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DetalleTareaScreen(taskId: taskId),
      ),
    );
  }

  // ─────────────────────────── permisos ───────────────────────────

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (allowed) return true;

    // awesome_notifications abre el diálogo del sistema con estos permisos.
    final granted = await AwesomeNotifications()
        .requestPermissionToSendNotifications(
      channelKey: _channelKey,
      permissions: <NotificationPermission>[
        NotificationPermission.Alert,
        NotificationPermission.Sound,
        NotificationPermission.Vibration,
        NotificationPermission.Badge,
        NotificationPermission.PreciseAlarms,
      ],
    );
    _log('requestPermissions granted=$granted');
    return granted;
  }

  // ─────────────────────────── programación ───────────────────────────

  /// Sincroniza las notificaciones programadas con la lista completa de
  /// tareas del usuario.
  ///
  /// Cancela los recordatorios que haya en el sistema y vuelve a programar
  /// solo los [limiteProgramadas] más cercanos (ver
  /// `seleccionarProximosRecordatorios`). Es el punto de entrada principal:
  /// se llama al abrir la app y cada vez que cambia una tarea.
  Future<void> sincronizarRecordatorios(List<TaskItem> tareas) {
    if (kIsWeb) return Future<void>.value();
    _colaSync = _colaSync.then((_) => _sincronizar(tareas));
    return _colaSync;
  }

  Future<void> _sincronizar(List<TaskItem> tareas) async {
    try {
      final seleccion = seleccionarProximosRecordatorios(
        tareas,
        ahora: DateTime.now(),
        limite: limiteProgramadas,
      );

      final programadas =
          await AwesomeNotifications().listScheduledNotifications();
      for (final n in programadas) {
        final id = n.content?.id;
        if (id == null || id == _testNotificationId) continue;
        await AwesomeNotifications().cancel(id);
      }

      for (final p in seleccion) {
        await _crearRecordatorio(p.task, p.indice, p.recordatorio, p.fecha);
      }
      _log('sync: ${seleccion.length} programados '
          '(límite $limiteProgramadas, tareas ${tareas.length})');
    } catch (e) {
      _log('sync falló: $e');
    }
  }

  /// Programa los recordatorios de una sola tarea, sin respetar el límite
  /// global. Preferir [sincronizarRecordatorios].
  Future<void> programarRecordatoriosDeTarea(TaskItem task) async {
    _log('programar id=${task.id} n=${task.recordatorios.length} '
        'fL=${task.fechaLimite.toIso8601String().substring(0, 16)}');
    if (kIsWeb) return;
    if (task.id.isEmpty) return;

    await cancelarRecordatoriosDeTarea(task.id);

    final now = DateTime.now();
    for (var i = 0; i < task.recordatorios.length; i++) {
      final r = task.recordatorios[i];
      final fecha = r.resolverFecha(task.fechaLimite);
      if (fecha.isBefore(now)) {
        _log('  #$i saltado: fecha pasada');
        continue;
      }
      await _crearRecordatorio(task, i, r, fecha);
    }
  }

  Future<void> _crearRecordatorio(
    TaskItem task,
    int indice,
    TaskReminder r,
    DateTime fecha,
  ) async {
    final id = _notificationId(task.id, indice);
    try {
      final ok = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: _channelKey,
          title: task.titulo,
          body: _construirBody(r),
          payload: {'taskId': task.id},
          notificationLayout: NotificationLayout.Default,
          // `Alarm` mantiene la prioridad alta (esquiva restricciones de
          // MIUI) pero sin `fullScreenIntent` para que se comporte como
          // notificación normal, no como despertador.
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
        ),
        schedule: NotificationCalendar.fromDate(
          date: fecha,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
      _log('  #$indice id=$id '
          'fecha=${fecha.toIso8601String().substring(0, 16)} '
          '${ok ? "OK" : "no-op"}');
    } catch (e) {
      _log('  #$indice falló: $e');
    }
  }

  Future<void> cancelarRecordatoriosDeTarea(String taskId) async {
    if (kIsWeb) return;
    if (taskId.isEmpty) return;
    try {
      final scheduled =
          await AwesomeNotifications().listScheduledNotifications();
      for (final n in scheduled) {
        final payload = n.content?.payload;
        final id = n.content?.id;
        if (payload?['taskId'] == taskId && id != null) {
          await AwesomeNotifications().cancel(id);
        }
      }
    } catch (e) {
      _log('Error cancelando reminders de $taskId: $e');
    }
  }

  Future<void> cancelarTodo() async {
    if (kIsWeb) return;
    try {
      await AwesomeNotifications().cancelAll();
    } catch (e) {
      _log('Error cancelando todos: $e');
    }
  }

  static int _notificationId(String taskId, int index) {
    final h = taskId.hashCode & 0x7FFFFFFF;
    return (h % 20000000) * 100 + index;
  }

  static String _construirBody(TaskReminder r) {
    if (r.diasAntes == 0) return 'Hoy vence';
    if (r.diasAntes == 1) return 'Mañana vence';
    return 'Faltan ${r.diasAntes} días';
  }

  // ─────────────────────────── test (usado por onboarding) ───────────────────

  /// Programa una notificación de prueba a `delay` segundos en el futuro.
  /// Usada por la pantalla de onboarding de notificaciones para que el
  /// usuario verifique en vivo que la configuración quedó correcta.
  Future<bool> scheduleTestNotification({
    Duration delay = const Duration(seconds: 15),
  }) async {
    if (kIsWeb) return false;
    final target = DateTime.now().add(delay);
    _log('scheduleTestNotification target=${target.toIso8601String()}');
    try {
      final ok = await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _testNotificationId,
          channelKey: _channelKey,
          title: 'TaskLog',
          body: '¡Funciona! Las notificaciones llegan a tiempo.',
          payload: {'taskId': 'test'},
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
        ),
        schedule: NotificationCalendar.fromDate(
          date: target,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );
      _log('scheduleTestNotification ${ok ? "OK" : "no-op"}');
      return ok;
    } catch (e) {
      _log('scheduleTestNotification falló: $e');
      return false;
    }
  }
}
