import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol del usuario dentro de la app. Decide qué interfaz se muestra
/// después del login y qué permite hacer Firestore (ver firestore.rules).
enum RolUsuario {
  ciudadano, // puede consultar el mapa, reportar y votar
  admin, // además modera reportes (cambia su estado)
}

/// Convierte el texto guardado en Firestore a [RolUsuario].
/// Un valor desconocido o faltante se trata como [RolUsuario.ciudadano]:
/// ante la duda, siempre el rol con menos permisos.
RolUsuario rolDesdeTexto(Object? valor) {
  return RolUsuario.values.firstWhere(
    (r) => r.name == valor,
    orElse: () => RolUsuario.ciudadano,
  );
}

/// Documento `usuarios/{uid}` de Firestore.
class Usuario {
  final String uid;
  final String? email;
  final RolUsuario rol;
  final DateTime fechaRegistro;

  Usuario({
    required this.uid,
    this.email,
    this.rol = RolUsuario.ciudadano,
    required this.fechaRegistro,
  });

  bool get esAdmin => rol == RolUsuario.admin;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'rol': rol.name,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
    };
  }

  factory Usuario.fromMap(String uid, Map<String, dynamic> map) {
    final email = map['email'];
    return Usuario(
      uid: uid,
      email: email is String ? email : null,
      rol: rolDesdeTexto(map['rol']),
      fechaRegistro: _fechaDesdeValor(map['fechaRegistro']),
    );
  }

  // Acepta Timestamp (formato actual) y también texto ISO, por si quedó
  // algún documento con el formato anterior. Si falta, usa la fecha actual
  // para que la lectura no truene.
  static DateTime _fechaDesdeValor(Object? valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }
}
