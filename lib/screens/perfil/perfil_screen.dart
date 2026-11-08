import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_setup_service.dart';
import '../../services/preferencias_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../utils/error_messages.dart';
import '../../utils/promedios.dart';
import '../../widgets/ios_ui.dart';
import '../notifications/onboarding_notificaciones_screen.dart';

/// Abre Perfil y ajustes como hoja que sube desde abajo.
Future<void> abrirPerfil(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PerfilScreen(),
    ),
  );
}

const String _versionApp = '1.0.0';

/// Perfil y ajustes: cuenta, estadísticas, notificaciones, apariencia,
/// semestre, ayuda, cerrar sesión y eliminar cuenta.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Future<bool> _permiso = _leerPermiso();

  Future<bool> _leerPermiso() =>
      NotificationSetupService.instance.hasNotificationPermission();

  Future<void> _tocarNotificaciones() async {
    final permitido = await _permiso;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const OnboardingNotificacionesScreen(allowSkip: true),
        ),
      );
    } else if (permitido) {
      await AwesomeNotifications().showNotificationConfigPage();
    } else {
      await NotificationSetupService.instance.requestNotificationPermission();
    }
    if (mounted) setState(() => _permiso = _leerPermiso());
  }

  Future<void> _editarNombre() async {
    final user = FirebaseAuth.instance.currentUser;
    final ctrl = TextEditingController(text: user?.displayName ?? '');
    final nuevo = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tu nombre'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            placeholder: 'Nombre y apellido',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.trim().isEmpty) return;
    try {
      await AuthService.instance.actualizarNombre(nuevo);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _editarSemestre() async {
    final actual = PreferenciasService.instance.semestre.value;
    final partes = actual.split('-');
    var anio = int.tryParse(partes.first) ?? DateTime.now().year;
    var periodo = partes.length > 1 ? (int.tryParse(partes[1]) ?? 1) : 1;
    final anios = [for (var a = DateTime.now().year - 4; a <= DateTime.now().year + 2; a++) a];
    if (!anios.contains(anio)) anio = DateTime.now().year;

    final elegido = await abrirHojaMedia<String>(
      context,
      StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EncabezadoHoja(
                titulo: 'Semestre actual',
                onConfirmar: () => Navigator.of(ctx).pop('$anio-$periodo'),
              ),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController: FixedExtentScrollController(
                          initialItem: anios.indexOf(anio),
                        ),
                        onSelectedItemChanged: (i) => anio = anios[i],
                        children: [
                          for (final a in anios)
                            Center(
                              child: Text(
                                '$a',
                                style: TextStyle(
                                  color: TaskLogPalette.of(ctx).texto,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController: FixedExtentScrollController(
                          initialItem: periodo == 2 ? 1 : 0,
                        ),
                        onSelectedItemChanged: (i) => periodo = i + 1,
                        children: [
                          for (final t in const ['Primero (1)', 'Segundo (2)'])
                            Center(
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: TaskLogPalette.of(ctx).texto,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (elegido != null) {
      await PreferenciasService.instance.cambiarSemestre(elegido);
    }
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmarIOS(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: 'Tus datos quedan guardados en tu cuenta.',
      accion: 'Cerrar sesión',
    );
    if (!ok) return;
    if (mounted) Navigator.of(context).pop();
    await AuthService.instance.signOut();
  }

  Future<void> _eliminarCuenta() async {
    final ok = await confirmarIOS(
      context,
      titulo: '¿Eliminar tu cuenta?',
      mensaje:
          'Se borrarán para siempre tu cuenta, tus tareas, apuntes, materias '
          'y evaluaciones. Esto no se puede deshacer.',
      accion: 'Continuar',
    );
    if (!ok || !mounted) return;

    final ctrl = TextEditingController();
    final password = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Confirma con tu contraseña'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            obscureText: true,
            placeholder: 'Contraseña',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty || !mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );
    try {
      await AuthService.instance.eliminarCuenta(password: password);
      if (!mounted) return;
      // Cierra el indicador y el perfil; AuthGate vuelve al login.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showErrorSnackBar(context, e);
    }
  }

  void _ayuda() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ayuda'),
        content: const Text(
          '\n• Usa el botón + para crear tareas, materias o apuntes según la '
          'pestaña.\n'
          '• Toca el círculo de una tarea para completarla.\n'
          '• En Materias registra tus evaluaciones con su porcentaje para '
          'ver tu nota y cuánto necesitas.\n'
          '• Los recordatorios llegan como notificación aunque la app esté '
          'cerrada.',
          textAlign: TextAlign.left,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final nombre = (user?.displayName ?? '').trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: BotonCirculo(
                icono: Icons.close_rounded,
                tooltip: 'Cerrar',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 4),
            const Center(child: AvatarUsuario(tamano: 76)),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _editarNombre,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Agrega tu nombre' : nombre,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: nombre.isEmpty ? p.acento : p.texto,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, size: 16, color: p.texto2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                user?.email ?? '',
                style: TextStyle(fontSize: 15, color: p.texto2),
              ),
            ),
            const SizedBox(height: 18),
            const _Estadisticas(),
            const SizedBox(height: 22),
            GrupoIOS(
              sangriaSeparador: 58,
              children: [
                FutureBuilder<bool>(
                  future: _permiso,
                  builder: (context, snap) {
                    final ok = snap.data ?? false;
                    return FilaIOS(
                      leading: const IconoCuadrado(
                        icono: Icons.notifications_rounded,
                        color: Color(0xFFFF3B30),
                      ),
                      titulo: 'Notificaciones',
                      valor: snap.hasData
                          ? (ok ? 'Activadas' : 'Desactivadas')
                          : null,
                      chevron: true,
                      onTap: _tocarNotificaciones,
                    );
                  },
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance,
                  builder: (context, modo, _) => FilaIOS(
                    leading: const IconoCuadrado(
                      icono: Icons.dark_mode_rounded,
                      color: Color(0xFF5E5CE6),
                    ),
                    titulo: 'Apariencia',
                    valor: ThemeController.nombre(modo),
                    chevron: true,
                    onTap: () => mostrarSelectorTema(context),
                  ),
                ),
                const FilaIOS(
                  leading: IconoCuadrado(
                    icono: Icons.star_rounded,
                    color: Color(0xFF34C759),
                  ),
                  titulo: 'Escala de notas',
                  valor: '0 – 5',
                ),
                ValueListenableBuilder<String>(
                  valueListenable: PreferenciasService.instance.semestre,
                  builder: (context, semestre, _) => FilaIOS(
                    leading: const IconoCuadrado(
                      icono: Icons.calendar_month_rounded,
                      color: Color(0xFFFF9500),
                    ),
                    titulo: 'Semestre',
                    valor: semestre,
                    chevron: true,
                    onTap: _editarSemestre,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            GrupoIOS(
              sangriaSeparador: 58,
              children: [
                FilaIOS(
                  leading: const IconoCuadrado(
                    icono: Icons.help_rounded,
                    color: Color(0xFF0A84FF),
                  ),
                  titulo: 'Ayuda',
                  chevron: true,
                  onTap: _ayuda,
                ),
                FilaIOS(
                  leading: const IconoCuadrado(
                    icono: Icons.info_rounded,
                    color: Color(0xFF8E8E93),
                  ),
                  titulo: 'Acerca de TaskLog',
                  chevron: true,
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'TaskLog',
                    applicationVersion: _versionApp,
                    applicationLegalese:
                        'Tus tareas, apuntes y notas del semestre en un solo '
                        'lugar.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            GrupoIOS(
              children: [
                FilaIOS(
                  tituloWidget: Center(
                    child: Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  onTap: _cerrarSesion,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _eliminarCuenta,
                child: Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'TaskLog $_versionApp',
                style: TextStyle(fontSize: 12, color: p.texto2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de tres cifras: materias, tareas completadas y promedio general.
class _Estadisticas extends StatelessWidget {
  const _Estadisticas();

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService.instance.watchSubjects(),
      builder: (context, s1) => StreamBuilder<List<TaskItem>>(
        stream: FirestoreService.instance.watchTasks(),
        builder: (context, s2) => StreamBuilder<List<GradeItem>>(
          stream: FirestoreService.instance.watchAllGradeItems(),
          builder: (context, s3) {
            final materias = s1.data?.length ?? 0;
            final hechas =
                (s2.data ?? const <TaskItem>[]).where((t) => t.completada).length;
            final prom = promedioGeneral(
              resumirPorMateria(s3.data ?? const <GradeItem>[]).values,
            );
            Widget celda(String valor, String etiqueta, Color color) =>
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: p.grupo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          valor,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          etiqueta,
                          style: TextStyle(fontSize: 12, color: p.texto2),
                        ),
                      ],
                    ),
                  ),
                );
            return Row(
              children: [
                celda('$materias', 'materias', p.acento),
                const SizedBox(width: 10),
                celda('$hechas', 'completadas', AppColors.lowPriority),
                const SizedBox(width: 10),
                celda(prom == null ? '–' : prom.toStringAsFixed(1),
                    'promedio', AppColors.mediumPriority),
              ],
            );
          },
        ),
      ),
    );
  }
}
