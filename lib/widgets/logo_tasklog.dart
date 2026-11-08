import 'package:flutter/material.dart';

/// Ícono de TaskLog (glifo «TL» sobre el degradado morado) con esquinas
/// de ícono de iOS.
class LogoTaskLog extends StatelessWidget {
  final double tamano;
  const LogoTaskLog({super.key, this.tamano = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * 0.225),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E62E5).withValues(alpha: 0.35),
            blurRadius: tamano * 0.3,
            offset: Offset(0, tamano * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tamano * 0.225),
        child: Image.asset(
          'assets/branding/icono_app.png',
          width: tamano,
          height: tamano,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
