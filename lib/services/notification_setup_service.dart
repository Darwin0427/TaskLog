import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado consolidado de todos los permisos y configuraciones que
/// impactan si las notificaciones programadas llegan o no.
@immutable
class NotificationReadinessStatus {
  /// Marca / fabricante del dispositivo, en minúsculas
  /// (ejemplo: `xiaomi`, `huawei`, `oppo`, `samsung`, `motorola`).
  final String manufacturer;

  /// True si el fabricante es conocido por tener políticas agresivas
  /// de background (Xiaomi, Huawei, Oppo, Vivo, Realme, Honor).
  final bool isRestrictiveManufacturer;

  /// Android 13+: permiso POST_NOTIFICATIONS otorgado.
  final bool notificationPermission;

  /// Android 12+: permiso SCHEDULE_EXACT_ALARM otorgado (o equivalente
  /// `PreciseAlarms` de awesome_notifications).
  final bool exactAlarmPermission;

  /// La app está en la whitelist de battery optimization (Doze).
  final bool batteryOptimizationExempted;

  /// Autoinicio configurado. Para fabricantes que no soportan este
  /// concepto (Samsung, Motorola), retorna true por defecto.
  final bool autoStartEnabled;

  /// Configuración de batería específica del fabricante (MIUI, EMUI,
  /// ColorOS) marcada como deshabilitada. Para fabricantes que no lo
  /// soportan, retorna true por defecto.
  final bool manufacturerBatteryDisabled;

  const NotificationReadinessStatus({
    required this.manufacturer,
    required this.isRestrictiveManufacturer,
    required this.notificationPermission,
    required this.exactAlarmPermission,
    required this.batteryOptimizationExempted,
    required this.autoStartEnabled,
    required this.manufacturerBatteryDisabled,
  });

  /// True si todos los pre-requisitos críticos están cumplidos.
  bool get isFullyReady =>
      notificationPermission &&
      exactAlarmPermission &&
      batteryOptimizationExempted &&
      (!isRestrictiveManufacturer ||
          (autoStartEnabled && manufacturerBatteryDisabled));

  @override
  String toString() => 'NotificationReadinessStatus('
      'manufacturer=$manufacturer, '
      'restrictive=$isRestrictiveManufacturer, '
      'notif=$notificationPermission, '
      'exactAlarm=$exactAlarmPermission, '
      'batteryOpt=$batteryOptimizationExempted, '
      'autoStart=$autoStartEnabled, '
      'manuBattery=$manufacturerBatteryDisabled, '
      'ready=$isFullyReady)';
}

/// Servicio que coordina detección de fabricante, chequeo de permisos y
/// deep-links a las pantallas de configuración del sistema necesarias
/// para que las notificaciones programadas funcionen de forma
/// confiable en dispositivos con políticas agresivas de background.
///
/// Este servicio complementa a `NotificationService`:
/// - `NotificationService` maneja el plugin y la programación.
/// - Este maneja los permisos del sistema operativo.
class NotificationSetupService {
  NotificationSetupService._();
  static final NotificationSetupService instance =
      NotificationSetupService._();

  /// Fabricantes conocidos por tener políticas agresivas de background
  /// que suelen matar apps y bloquear notificaciones programadas.
  static const Set<String> _restrictiveManufacturers = {
    'xiaomi',
    'redmi',
    'poco',
    'huawei',
    'honor',
    'oppo',
    'vivo',
    'realme',
    'oneplus',
    'iqoo',
  };

  static const String _onboardingCompletedKey =
      'notif_onboarding_completed_v1';

  AndroidDeviceInfo? _cachedAndroidInfo;

  Future<AndroidDeviceInfo?> _androidInfo() async {
    if (_cachedAndroidInfo != null) return _cachedAndroidInfo;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      _cachedAndroidInfo = await DeviceInfoPlugin().androidInfo;
      return _cachedAndroidInfo;
    } catch (e) {
      debugPrint('[NotifSetup] Error leyendo AndroidDeviceInfo: $e');
      return null;
    }
  }

  Future<String> getManufacturer() async {
    if (kIsWeb) return 'web';
    // En iPhone no hay fabricantes "agresivos": el sistema dispara las
    // notificaciones programadas por su cuenta. Este servicio (y su
    // onboarding) solo aplican a Android.
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'apple';
    final info = await _androidInfo();
    return (info?.manufacturer ?? 'unknown').toLowerCase().trim();
  }

  Future<bool> isRestrictiveManufacturer() async {
    final m = await getManufacturer();
    return _restrictiveManufacturers.contains(m);
  }

  // ─────────────────────────── permisos: chequeo ─────────────────────────

  Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      return await AwesomeNotifications().isNotificationAllowed();
    } catch (e) {
      debugPrint('[NotifSetup] hasNotificationPermission error: $e');
      return false;
    }
  }

  Future<bool> hasExactAlarmPermission() async {
    if (kIsWeb) return false;
    try {
      final allowed = await AwesomeNotifications().checkPermissionList(
        permissions: <NotificationPermission>[
          NotificationPermission.PreciseAlarms,
        ],
      );
      return allowed.contains(NotificationPermission.PreciseAlarms);
    } catch (e) {
      debugPrint('[NotifSetup] hasExactAlarmPermission error: $e');
      return false;
    }
  }

  Future<bool> hasBatteryOptimizationExempted() async {
    if (kIsWeb) return true;
    try {
      final result =
          await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      return result ?? false;
    } catch (e) {
      debugPrint('[NotifSetup] hasBatteryOptimizationExempted error: $e');
      return false;
    }
  }

  /// Retorna true para dispositivos sin autostart nativo (Samsung stock,
  /// Motorola, Pixel) o cuando el usuario ya confirmó el diálogo.
  Future<bool> hasAutoStartEnabled() async {
    if (kIsWeb) return true;
    try {
      final result = await DisableBatteryOptimization.isAutoStartEnabled;
      return result ?? true;
    } catch (e) {
      debugPrint('[NotifSetup] hasAutoStartEnabled error: $e');
      return true;
    }
  }

  Future<bool> hasManufacturerBatteryDisabled() async {
    if (kIsWeb) return true;
    try {
      final result = await DisableBatteryOptimization
          .isManufacturerBatteryOptimizationDisabled;
      return result ?? true;
    } catch (e) {
      debugPrint('[NotifSetup] hasManufacturerBatteryDisabled error: $e');
      return true;
    }
  }

  /// Snapshot combinado del estado actual. Se recomienda llamarlo cada
  /// vez que el usuario vuelve a la pantalla de onboarding para
  /// re-evaluar (los permisos pueden haber cambiado si abrió Ajustes).
  Future<NotificationReadinessStatus> getStatus() async {
    final manufacturer = await getManufacturer();
    final restrictive = _restrictiveManufacturers.contains(manufacturer);

    // En paralelo — cada check hace su propio try/catch, no propaga error.
    final results = await Future.wait<bool>([
      hasNotificationPermission(),
      hasExactAlarmPermission(),
      hasBatteryOptimizationExempted(),
      hasAutoStartEnabled(),
      hasManufacturerBatteryDisabled(),
    ]);

    return NotificationReadinessStatus(
      manufacturer: manufacturer,
      isRestrictiveManufacturer: restrictive,
      notificationPermission: results[0],
      exactAlarmPermission: results[1],
      batteryOptimizationExempted: results[2],
      autoStartEnabled: results[3],
      manufacturerBatteryDisabled: results[4],
    );
  }

  // ─────────────────────────── permisos: acción ─────────────────────────

  /// Dispara el diálogo del sistema de POST_NOTIFICATIONS (Android 13+).
  /// Si ya estaba concedido, no hace nada.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (allowed) return true;
      final granted = await AwesomeNotifications()
          .requestPermissionToSendNotifications(
        channelKey: 'recordatorios_tareas',
        permissions: <NotificationPermission>[
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Vibration,
          NotificationPermission.Badge,
        ],
      );
      return granted;
    } catch (e) {
      debugPrint('[NotifSetup] requestNotificationPermission error: $e');
      return false;
    }
  }

  /// Abre la pantalla de "Alarmas y recordatorios" del sistema (Android 12+).
  /// El usuario debe activar el switch manualmente.
  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await AwesomeNotifications()
          .requestPermissionToSendNotifications(
        channelKey: 'recordatorios_tareas',
        permissions: <NotificationPermission>[
          NotificationPermission.PreciseAlarms,
        ],
      );
      return granted;
    } catch (e) {
      debugPrint('[NotifSetup] requestExactAlarmPermission error: $e');
      return false;
    }
  }

  /// Muestra el diálogo nativo de "¿Permitir que TaskLog ignore el
  /// ahorro de batería?". Si el usuario acepta, TaskLog queda whitelisted.
  Future<void> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return;
    try {
      await DisableBatteryOptimization
          .showDisableBatteryOptimizationSettings();
    } catch (e) {
      debugPrint('[NotifSetup] requestBatteryOptimizationExemption error: $e');
    }
  }

  /// Abre la pantalla de "Autoinicio" del fabricante (MIUI, EMUI, ColorOS,
  /// FuntouchOS). Muestra un diálogo previo con instrucciones.
  Future<void> openAutoStartSettings() async {
    if (kIsWeb) return;
    try {
      await DisableBatteryOptimization.showEnableAutoStartSettings(
        'Activa el inicio automático',
        'Sin esto, tu celular puede cerrar TaskLog en background y '
            'las notificaciones no llegarán. Busca "TaskLog" en la '
            'lista y activa el switch.',
      );
    } catch (e) {
      debugPrint('[NotifSetup] openAutoStartSettings error: $e');
    }
  }

  /// Abre la pantalla de "Ahorro de batería" específica del fabricante
  /// (MIUI, EMUI). Muestra diálogo previo con instrucciones para poner
  /// TaskLog en modo "sin restricciones".
  Future<void> openManufacturerBatterySettings() async {
    if (kIsWeb) return;
    try {
      await DisableBatteryOptimization
          .showDisableManufacturerBatteryOptimizationSettings(
        'Quita restricciones de batería',
        'Busca TaskLog y selecciona "Sin restricciones". Sin esto, tu '
            'celular hará dormir la app y las notificaciones llegarán '
            'tarde o no llegarán.',
      );
    } catch (e) {
      debugPrint(
          '[NotifSetup] openManufacturerBatterySettings error: $e');
    }
  }

  // ─────────────────────────── flag de onboarding ─────────────────────────

  Future<bool> hasCompletedOnboarding() async {
    if (kIsWeb) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (e) {
      debugPrint('[NotifSetup] hasCompletedOnboarding error: $e');
      return false;
    }
  }

  Future<void> markOnboardingCompleted() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
    } catch (e) {
      debugPrint('[NotifSetup] markOnboardingCompleted error: $e');
    }
  }

  /// Útil si el usuario quiere volver a ver el onboarding manualmente
  /// (desde la pantalla de ajustes de notificaciones).
  Future<void> resetOnboarding() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
    } catch (e) {
      debugPrint('[NotifSetup] resetOnboarding error: $e');
    }
  }
}
