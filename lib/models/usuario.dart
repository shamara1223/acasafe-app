class Usuario {
  final String uid;
  final String? nombre;
  final String? email;
  final DateTime fechaRegistro;
  final int reportesEnviados;

  Usuario({
    required this.uid,
    this.nombre,
    this.email,
    required this.fechaRegistro,
    this.reportesEnviados = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'fechaRegistro': fechaRegistro.toIso8601String(),
      'reportesEnviados': reportesEnviados,
    };
  }

  factory Usuario.fromMap(String uid, Map<String, dynamic> map) {
    return Usuario(
      uid: uid,
      nombre: map['nombre'] as String?,
      email: map['email'] as String?,
      fechaRegistro: DateTime.parse(map['fechaRegistro'] as String),
      reportesEnviados: (map['reportesEnviados'] as num?)?.toInt() ?? 0,
    );
  }
}
