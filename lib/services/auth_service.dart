import 'package:firebase_auth/firebase_auth.dart';

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

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Cierra sesión y borra los recordatorios programados, para que quien
  /// entre después en este teléfono no reciba los avisos de otra cuenta.
  Future<void> signOut() async {
    await NotificationService.instance.cancelarTodo();
    await _auth.signOut();
  }
}
