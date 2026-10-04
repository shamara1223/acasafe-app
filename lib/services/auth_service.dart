import 'package:firebase_auth/firebase_auth.dart';

/// Capa delgada sobre FirebaseAuth. Las pantallas no deberían llamar a
/// FirebaseAuth directamente, siempre a través de este servicio —
/// así, si luego cambiamos el método de login, solo se toca este archivo.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get usuarioActual => _auth.currentUser;

  Future<UserCredential> registrarse({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> iniciarSesion({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> cerrarSesion() {
    return _auth.signOut();
  }
}
