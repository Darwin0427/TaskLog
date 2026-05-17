import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // Arrancamos sin esperar a Firebase: la UI ya puede pintar el splash
  // morado mientras Firebase termina de inicializarse en background.
  runApp(const GestorTareasApp());
}

class GestorTareasApp extends StatelessWidget {
  const GestorTareasApp({super.key});

  /// Inicializa Firebase, configura caché offline y locales en español.
  /// Si algo falla, retorna el mensaje de error para mostrarlo en el splash.
  Future<String?> _bootstrap() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Caché offline:
      // - Mobile (Android/iOS): viene habilitado por defecto, pero igual
      //   subimos el tamaño máximo del caché a "sin límite".
      // - Web: hay que habilitar persistencia explícitamente.
      if (kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } else {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      await initializeDateFormatting('es');
      return null;
    } catch (e) {
      return 'No se pudo iniciar: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<String?>(
        future: _bootstrap(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SplashScreen(message: 'Cargando...');
          }
          if (snap.data != null) {
            return SplashScreen(message: snap.data);
          }
          return const AuthGate();
        },
      ),
    );
  }
}
