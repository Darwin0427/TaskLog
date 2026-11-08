import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/preferencias_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // El tema elegido se lee antes de pintar, para que el splash no
  // parpadee entre claro y oscuro. Es una lectura local y rápida.
  await ThemeController.instance.cargar();
  await PreferenciasService.instance.cargar();
  // No esperamos a Firebase: la UI ya puede pintar el splash mientras
  // Firebase termina de inicializarse en background.
  runApp(const GestorTareasApp());
}

class GestorTareasApp extends StatefulWidget {
  const GestorTareasApp({super.key});

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  /// Se crea una sola vez: cambiar de tema reconstruye la app, y sin esto
  /// Firebase se volvería a inicializar.
  late final Future<String?> _arranque = _bootstrap();

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

      // Notificaciones locales. Si falla, no es fatal — la app funciona
      // igual, solo que sin recordatorios.
      try {
        await NotificationService.instance.initialize();
      } catch (e) {
        debugPrint('NotificationService init falló: $e');
      }

      return null;
    } catch (e) {
      return 'No se pudo iniciar: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, modo, _) => _app(modo),
    );
  }

  Widget _app(ThemeMode modo) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'TaskLog',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: modo,
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
        future: _arranque,
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
