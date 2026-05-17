import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Traduce excepciones técnicas de Firebase a mensajes en español
/// que el usuario pueda entender.
String friendlyErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está habilitado.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';
      case 'network-request-failed':
        return 'No hay conexión a internet. Verifica tu WiFi o datos.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión para esta acción.';
      default:
        return error.message ?? 'Error de autenticación.';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
        return 'Sin conexión al servidor. Tus cambios se guardarán cuando vuelva.';
      case 'permission-denied':
        return 'No tienes permiso para esta acción.';
      case 'not-found':
        return 'El recurso no existe (puede que lo hayan eliminado).';
      case 'deadline-exceeded':
        return 'La operación tardó demasiado. Intenta de nuevo.';
      case 'cancelled':
        return 'Operación cancelada.';
      default:
        return error.message ?? 'Error de Firebase.';
    }
  }

  // Caso genérico.
  final msg = error.toString();
  // Limpiamos prefijos tipo "Exception: " o "Error: " que no aportan.
  return msg
      .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
      .replaceFirst('PlatformException', 'Error de plataforma');
}

/// Muestra un SnackBar de error con el mensaje amigable.
void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(friendlyErrorMessage(error))),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
}

/// Muestra un SnackBar de éxito breve.
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
}
