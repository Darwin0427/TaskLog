import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'calendar/calendar_screen.dart';
import 'forms/crear_nota_screen.dart';
import 'forms/crear_tarea_screen.dart';
import 'grades/grades_screen.dart';
import 'tasks/tasks_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _index = 0;
  bool _fabOpen = false;
  late final AnimationController _fabAnim;

  static const _tabs = <Widget>[
    TasksScreen(),
    CalendarScreen(),
    GradesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _fabOpen = !_fabOpen;
      if (_fabOpen) {
        _fabAnim.forward();
      } else {
        _fabAnim.reverse();
      }
    });
  }

  void _closeFab() {
    if (_fabOpen) _toggleFab();
  }

  Future<void> _openCrearTarea() async {
    _closeFab();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CrearTareaScreen()),
    );
  }

  Future<void> _openCrearNota() async {
    _closeFab();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CrearNotaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _tabs),
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeFab,
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MiniFab(
            visible: _fabOpen,
            anim: _fabAnim,
            label: 'Nueva nota',
            icon: Icons.note_add_outlined,
            onTap: _openCrearNota,
            heroTag: 'fab_nota',
          ),
          const SizedBox(height: 12),
          _MiniFab(
            visible: _fabOpen,
            anim: _fabAnim,
            label: 'Nueva tarea',
            icon: Icons.add_task,
            onTap: _openCrearTarea,
            heroTag: 'fab_tarea',
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: _toggleFab,
            backgroundColor: AppColors.primary,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 220),
              turns: _fabOpen ? 0.125 : 0,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          _closeFab();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Calificaciones',
          ),
        ],
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  final bool visible;
  final AnimationController anim;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String heroTag;

  const _MiniFab({
    required this.visible,
    required this.anim,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => IgnorePointer(
        ignoring: !visible,
        child: Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 16),
            child: child,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(label),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: onTap,
            backgroundColor: AppColors.primary,
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
