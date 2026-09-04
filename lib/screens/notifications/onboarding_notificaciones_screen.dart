import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../services/notification_setup_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

/// Pantalla de onboarding que guía al usuario paso a paso para dejar
/// configuradas las notificaciones. Se muestra la primera vez que el
/// usuario abre la app con sesión, si el fabricante es restrictivo o si
/// falta algún permiso crítico. También es accesible manualmente desde
/// la sección "Ajustes de notificaciones".
class OnboardingNotificacionesScreen extends StatefulWidget {
  /// Si true, en el AppBar aparece un botón "Omitir" que cierra la
  /// pantalla sin marcar el onboarding como completado. Se usa la
  /// primera vez que se muestra automáticamente para no forzar.
  /// Cuando el usuario lo abre manualmente desde ajustes, se puede
  /// omitir siempre.
  final bool allowSkip;

  const OnboardingNotificacionesScreen({
    super.key,
    this.allowSkip = true,
  });

  @override
  State<OnboardingNotificacionesScreen> createState() =>
      _OnboardingNotificacionesScreenState();
}

class _OnboardingNotificacionesScreenState
    extends State<OnboardingNotificacionesScreen> {
  NotificationReadinessStatus? _status;
  bool _loading = true;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final s = await NotificationSetupService.instance.getStatus();
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
    });
  }

  Future<void> _finalize() async {
    await NotificationSetupService.instance.markOnboardingCompleted();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _sendTest() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      final ok = await NotificationService.instance.scheduleTestNotification(
        delay: const Duration(seconds: 15),
      );
      if (!mounted) return;
      if (ok) {
        showSuccessSnackBar(
          context,
          'Notificación programada. Cierra la app y espera 15 s.',
        );
      } else {
        showErrorSnackBar(
          context,
          'No se pudo programar. Revisa los permisos arriba.',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _requestNotifPermission() async {
    await NotificationSetupService.instance.requestNotificationPermission();
    await _refresh();
  }

  Future<void> _requestExactAlarm() async {
    await NotificationSetupService.instance.requestExactAlarmPermission();
    await _refresh();
  }

  Future<void> _requestBatteryExemption() async {
    await NotificationSetupService.instance
        .requestBatteryOptimizationExemption();
    await _refresh();
  }

  Future<void> _openAutoStart() async {
    await NotificationSetupService.instance.openAutoStartSettings();
    await _refresh();
  }

  Future<void> _openManufacturerBattery() async {
    await NotificationSetupService.instance
        .openManufacturerBatterySettings();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar notificaciones'),
        actions: [
          if (widget.allowSkip)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Omitir'),
            ),
        ],
      ),
      body: _loading || _status == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, _status!),
    );
  }

  Widget _buildBody(BuildContext context, NotificationReadinessStatus s) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(status: s),
          const SizedBox(height: 24),

          _StepCard(
            done: s.notificationPermission,
            icon: Icons.notifications_active_outlined,
            title: 'Permitir notificaciones',
            description:
                'Permiso básico del sistema para que TaskLog pueda mostrar '
                'notificaciones. Requerido en Android 13 o superior.',
            primaryLabel: 'Otorgar permiso',
            onPrimary: _requestNotifPermission,
            onVerify: _refresh,
          ),
          const SizedBox(height: 12),

          _StepCard(
            done: s.exactAlarmPermission,
            icon: Icons.alarm_outlined,
            title: 'Alarmas y recordatorios',
            description:
                'Permiso para programar notificaciones en el momento exacto. '
                'Sin esto, tus recordatorios pueden llegar minutos u horas tarde.',
            primaryLabel: 'Abrir ajustes',
            onPrimary: _requestExactAlarm,
            onVerify: _refresh,
          ),
          const SizedBox(height: 12),

          _StepCard(
            done: s.batteryOptimizationExempted,
            icon: Icons.battery_saver_outlined,
            title: 'Sin restricciones de batería',
            description:
                'Android detiene apps en background para ahorrar batería. Debemos '
                'excluir a TaskLog para que las notificaciones lleguen aunque la '
                'app esté cerrada.',
            primaryLabel: 'Otorgar exención',
            onPrimary: _requestBatteryExemption,
            onVerify: _refresh,
          ),

          if (s.isRestrictiveManufacturer) ...[
            const SizedBox(height: 12),
            _StepCard(
              done: s.autoStartEnabled,
              icon: Icons.play_circle_outline,
              title: 'Activar autoinicio',
              description:
                  'Tu celular (${_capitalize(s.manufacturer)}) cierra apps al '
                  'apagar la pantalla, salvo que estén marcadas como "autoiniciables". '
                  'Busca TaskLog en la lista y activa el switch.',
              primaryLabel: 'Abrir autoinicio',
              onPrimary: _openAutoStart,
              onVerify: _refresh,
              hint: 'No podemos detectar cuando lo activas — al volver a esta '
                  'pantalla, toca "Verificar" o baja para refrescar.',
            ),
            const SizedBox(height: 12),
            _StepCard(
              done: s.manufacturerBatteryDisabled,
              icon: Icons.battery_charging_full_outlined,
              title: 'Restricciones específicas del fabricante',
              description:
                  'Además del ahorro de batería estándar, ${_capitalize(s.manufacturer)} '
                  'tiene su propio sistema. Selecciona TaskLog y márcala como '
                  '"Sin restricciones".',
              primaryLabel: 'Abrir ajustes',
              onPrimary: _openManufacturerBattery,
              onVerify: _refresh,
              hint: 'Tampoco podemos detectar este cambio — usa el botón de '
                  'abajo para confirmar que las notificaciones ya llegan.',
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            'Prueba en vivo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Programa una notificación a 15 segundos, cierra la app y espera. '
            'Si llega, la configuración funciona.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),

          FilledButton.tonalIcon(
            onPressed: _sendingTest ? null : _sendTest,
            icon: _sendingTest
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _sendingTest
                  ? 'Programando...'
                  : 'Programar notificación de prueba (15 s)',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _finalize,
            icon: const Icon(Icons.check),
            label: Text(
              s.isFullyReady
                  ? 'Listo, ya funciona'
                  : 'Guardar y salir',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: s.isFullyReady
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: s.isFullyReady
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          if (!s.isFullyReady) ...[
            const SizedBox(height: 12),
            Text(
              'Puedes salir aunque queden pasos pendientes — cuando quieras '
              'volver, entra desde el ícono de campana en Calificaciones.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ──────────────────────────────────────────────────────────────────────
// Header — resumen visual del estado
// ──────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final NotificationReadinessStatus status;
  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = status.isFullyReady;
    final color = ready
        ? Colors.green
        : (status.isRestrictiveManufacturer
            ? Colors.orange
            : AppColors.primary);

    final IconData icon;
    final String title;
    final String subtitle;

    if (ready) {
      icon = Icons.check_circle;
      title = '¡Todo listo!';
      subtitle = 'Las notificaciones deberían llegar sin problemas.';
    } else if (status.isRestrictiveManufacturer) {
      icon = Icons.warning_amber_rounded;
      title = 'Tu celular necesita ajustes';
      subtitle =
          '${_capitalize(status.manufacturer)} cierra apps en background '
          'de forma agresiva. Configura estos pasos para asegurar que '
          'las notificaciones lleguen a tiempo.';
    } else {
      icon = Icons.notifications_outlined;
      title = 'Configurar notificaciones';
      subtitle =
          'Otorga los siguientes permisos para que TaskLog te avise a '
          'tiempo de tus tareas.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ──────────────────────────────────────────────────────────────────────
// Step card — un paso individual del onboarding
// ──────────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final bool done;
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onVerify;

  /// Nota adicional para pasos que no podemos verificar programáticamente.
  final String? hint;

  const _StepCard({
    required this.done,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onVerify,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = done ? Colors.green : Colors.orange;
    final statusIcon = done ? Icons.check_circle : Icons.pending_outlined;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!done) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onPrimary,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: Text(primaryLabel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onVerify,
                    tooltip: 'Verificar',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
