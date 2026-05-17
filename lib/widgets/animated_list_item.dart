import 'package:flutter/material.dart';

/// Envuelve un item de lista con una animación de entrada (fade + slide
/// vertical). Ideal para usar dentro de `ListView` con `StreamBuilder` —
/// donde no podemos usar `AnimatedList` directamente porque la lista se
/// reconstruye completa en cada cambio del stream.
///
/// Usa `key` con un identificador único (ej. el doc.id) para que Flutter
/// reuse el state cuando el item ya existía y dispare la animación
/// solo cuando es nuevo.
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
    );
  }
}
