import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/notification_setup_service.dart';
import '../widgets/ios_ui.dart';
import '../widgets/tasklog_tab_bar.dart';
import 'calendar/calendar_screen.dart';
import 'forms/crear_materia_screen.dart';
import 'forms/crear_nota_screen.dart';
import 'forms/crear_tarea_screen.dart';
import 'grades/grades_screen.dart';
import 'notes/apuntes_screen.dart';
import 'notifications/onboarding_notificaciones_screen.dart';
import 'tasks/tasks_screen.dart';

/// Marco principal: cuatro pestañas (Tareas · Calendario · Materias ·
/// Apuntes) en una barra flotante, con el botón «+» a su derecha.
///
/// El «+» crea lo que corresponde a la pestaña abierta: tarea en Tareas y
/// Calendario, materia en Materias y apunte en Apuntes.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _tabs = <Widget>[
    TasksScreen(),
    CalendarScreen(),
    GradesScreen(),
    ApuntesScreen(),
  ];

  static const _items = <TabBarItem>[
    TabBarItem(
      label: 'Tareas',
      icon: Icons.checklist_rounded,
      selectedIcon: Icons.checklist_rounded,
    ),
    TabBarItem(
      label: 'Calendario',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
    ),
    TabBarItem(
      label: 'Materias',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
    ),
    TabBarItem(
      label: 'Apuntes',
      icon: Icons.edit_note_rounded,
      selectedIcon: Icons.edit_note_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Después del primer frame: permiso de notificaciones (y onboarding en
    // Android) + sincronización de recordatorios.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepararNotificaciones());
    });
  }

  /// Primero el permiso/onboarding (en iOS, sin permiso no se puede
  /// programar nada) y después la sincronización de recordatorios.
  ///
  /// La sincronización reprograma los recordatorios más cercanos. En iOS es
  /// lo que rellena el cupo de 64 a medida que se van disparando los
  /// anteriores, y también los recupera tras reinstalar la app.
  Future<void> _prepararNotificaciones() async {
    await _maybeShowNotificationsOnboarding();
    await FirestoreService.instance.sincronizarRecordatorios(soloCache: false);
  }

  Future<void> _maybeShowNotificationsOnboarding() async {
    // Ojo: es best-effort. Si algo falla (ej. web), simplemente no se
    // muestra el onboarding — la app sigue funcionando.
    try {
      final setup = NotificationSetupService.instance;
      final already = await setup.hasCompletedOnboarding();
      if (already) return;
      final isRestrictive = await setup.isRestrictiveManufacturer();
      if (!isRestrictive) {
        // En dispositivos no restrictivos, solo pedimos el permiso de
        // notificaciones base sin todo el flujo.
        await setup.requestNotificationPermission();
        await setup.markOnboardingCompleted();
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const OnboardingNotificacionesScreen(allowSkip: true),
        ),
      );
    } catch (_) {
      // Silencioso — no bloqueamos al usuario si algo falla en el setup.
    }
  }

  String get _accionMas => switch (_index) {
        2 => 'Nueva materia',
        3 => 'Nuevo apunte',
        _ => 'Nueva tarea',
      };

  Future<void> _crear() async {
    final Widget pantalla = switch (_index) {
      2 => const CrearMateriaScreen(),
      3 => const CrearNotaScreen(),
      1 => CrearTareaScreen(fechaInicial: CalendarScreen.diaElegido.value),
      _ => const CrearTareaScreen(),
    };
    await abrirFormulario<void>(context, pantalla);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La barra flota encima del contenido; el teclado no la mueve.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: _tabs),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TaskLogTabBar(
              items: _items,
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              onAdd: _crear,
              addTooltip: _accionMas,
            ),
          ),
        ],
      ),
    );
  }
}
