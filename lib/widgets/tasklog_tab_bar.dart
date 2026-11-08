import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Una pestaña de la barra inferior.
class TabBarItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const TabBarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Barra de pestañas flotante estilo iOS 26: una cápsula de vidrio con las
/// pestañas y, a su derecha, el botón «+» redondo.
///
/// Flutter no tiene el "vidrio líquido" nativo de Apple; se imita con
/// desenfoque del fondo + transparencia + un borde muy fino.
class TaskLogTabBar extends StatelessWidget {
  final List<TabBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final String addTooltip;

  const TaskLogTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.addTooltip,
  });

  /// Alto de la barra, sin contar el margen inferior del sistema. Las
  /// listas de cada pestaña dejan al menos este espacio al final.
  static const double alto = 64;

  /// Espacio que una lista debe dejar al final para que su último elemento
  /// no quede tapado por la barra.
  static double espacioInferior(BuildContext context) =>
      alto + 24 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _Vidrio(
                radio: alto / 2,
                dark: dark,
                child: SizedBox(
                  height: alto,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _Pestana(
                              item: items[i],
                              seleccionada: i == currentIndex,
                              acento: p.acento,
                              colorInactivo: p.texto,
                              fondoSeleccion: dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.06),
                              onTap: () {
                                if (i != currentIndex) {
                                  HapticFeedback.selectionClick();
                                }
                                onTap(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _BotonMas(onTap: onAdd, tooltip: addTooltip),
          ],
        ),
      ),
    );
  }
}

class _Vidrio extends StatelessWidget {
  final Widget child;
  final double radio;
  final bool dark;

  const _Vidrio({
    required this.child,
    required this.radio,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borde,
              color: dark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.72),
              border: Border.all(
                width: 0.5,
                color: dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  final TabBarItem item;
  final bool seleccionada;
  final Color acento;
  final Color colorInactivo;
  final Color fondoSeleccion;
  final VoidCallback onTap;

  const _Pestana({
    required this.item,
    required this.seleccionada,
    required this.acento,
    required this.colorInactivo,
    required this.fondoSeleccion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = seleccionada ? acento : colorInactivo;
    return Semantics(
      button: true,
      selected: seleccionada,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: seleccionada ? fondoSeleccion : Colors.transparent,
            borderRadius: BorderRadius.circular(TaskLogTabBar.alto / 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                seleccionada ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonMas extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const _BotonMas({required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: TaskLogTabBar.alto - 4,
            height: TaskLogTabBar.alto - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
