import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/logo_tasklog.dart';

/// Arranque: solo el ícono y el nombre, como recomienda Apple. Si algo
/// falla al iniciar, muestra el mensaje debajo.
class SplashScreen extends StatelessWidget {
  final String? message;
  const SplashScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final esError = message != null && message != 'Cargando...';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoTaskLog(tamano: 96),
            const SizedBox(height: 16),
            Text(
              'TaskLog',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: p.texto,
              ),
            ),
            if (esError) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.texto2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
