import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';
import 'notification_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Crea la cuenta y guarda el nombre como nombre visible del usuario.
  Future<UserCredential> register({
    required String email,
    required String password,
    String? nombre,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final n = nombre?.trim() ?? '';
    if (n.isNotEmpty) {
      await cred.user?.updateDisplayName(n);
      await cred.user?.reload();
    }
    return cred;
  }

  /// Envía el correo de Firebase para crear una contraseña nueva.
  Future<void> enviarRecuperacion(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> actualizarNombre(String nombre) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(nombre.trim());
    await user.reload();
  }

  /// Elimina la cuenta y TODOS sus datos (tareas, apuntes, materias y
  /// evaluaciones). Apple exige que esto se pueda hacer desde la app.
  ///
  /// Firebase pide haber iniciado sesión hace poco para borrar una cuenta,
  /// por eso se vuelve a verificar con la contraseña antes.
  Future<void> eliminarCuenta({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
    await FirestoreService.instance.borrarTodosLosDatos();
    await NotificationService.instance.cancelarTodo();
    await user.delete();
  }

  /// Cierra sesión y borra los recordatorios programados, para que quien
  /// entre después en este teléfono no reciba los avisos de otra cuenta.
  Future<void> signOut() async {
    await NotificationService.instance.cancelarTodo();
    await _auth.signOut();
  }
}
