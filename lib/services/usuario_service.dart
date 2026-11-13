import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/usuario.dart';

/// Todo el acceso a la colección `usuarios` pasa por aquí.
/// El documento `usuarios/{uid}` guarda el rol de cada cuenta.
class UsuarioService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference<Map<String, dynamic>> _usuarios =
      FirebaseFirestore.instance.collection('usuarios');

  /// Crea `usuarios/{uid}` con rol 'ciudadano' si todavía no existe.
  /// Cubre tanto a quien se acaba de registrar como a las cuentas que ya
  /// existían antes de que hubiera roles. Si el documento ya existe no
  /// lo toca (así nunca se pisa el rol de un admin).
  Future<void> asegurarDocumento(User user) async {
    final ref = _usuarios.doc(user.uid);
    final doc = await ref.get();
    if (doc.exists) return;
    await ref.set(_usuarioNuevo(user).toMap());
  }

  /// Usuario con sesión activa, con su rol, actualizado en tiempo real.
  /// Si no hay sesión el stream no emite nada.
  ///
  /// La primera vez que el servidor confirma que el documento no existe
  /// (registro nuevo o cuenta anterior a los roles) lo crea. Mientras
  /// tanto, y siempre que falte el documento, se emite como 'ciudadano'.
  Stream<Usuario> usuarioActual() async* {
    final user = _auth.currentUser;
    if (user == null) return;

    var creacionIntentada = false;
    await for (final snap in _usuarios.doc(user.uid).snapshots()) {
      final datos = snap.data();
      if (datos != null) {
        yield Usuario.fromMap(snap.id, datos);
        continue;
      }

      // Solo se crea cuando la respuesta viene del servidor: sin conexión
      // la caché puede decir "no existe" aunque el documento sí exista.
      if (!snap.metadata.isFromCache && !creacionIntentada) {
        creacionIntentada = true;
        // No se espera: al guardarse llega un nuevo snapshot con los datos.
        asegurarDocumento(user).catchError((Object e) {
          debugPrint('No se pudo crear usuarios/${user.uid}: $e');
        });
      }
      yield _usuarioNuevo(user);
    }
  }

  Usuario _usuarioNuevo(User user) {
    return Usuario(
      uid: user.uid,
      email: user.email,
      rol: RolUsuario.ciudadano,
      fechaRegistro: user.metadata.creationTime ?? DateTime.now(),
    );
  }
}
