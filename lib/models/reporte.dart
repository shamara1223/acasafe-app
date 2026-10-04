import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoría general del reporte. Sirve para agrupar tipos específicos
/// y para elegir el ícono/color en el mapa.
enum CategoriaReporte {
  infraestructura, // bache, poste caído, alumbrado, semáforo
  seguridad, // robo, asalto, riña
  clima, // inundación, derrumbe, árbol caído
  otro,
}

/// Estado del reporte dentro del flujo de moderación.
/// Por ahora el filtro anti-falsos es manual (un admin cambia el estado);
/// más adelante esto se puede automatizar con votos de la comunidad.
enum EstadoReporte {
  pendiente,
  verificado,
  falso,
  resuelto,
}

class Reporte {
  final String? id; // null hasta que se guarda en Firestore
  final String tipo; // ej. "bache", "poste_caido", "robo", "inundacion"
  final CategoriaReporte categoria;
  final String colonia;
  final GeoPoint ubicacion;
  final String descripcion;
  final String? fotoUrl;
  final DateTime fechaHora;
  final EstadoReporte estado;
  final String usuarioId;
  final int votosUtil;
  final int votosFalso;

  Reporte({
    this.id,
    required this.tipo,
    required this.categoria,
    required this.colonia,
    required this.ubicacion,
    required this.descripcion,
    this.fotoUrl,
    required this.fechaHora,
    this.estado = EstadoReporte.pendiente,
    required this.usuarioId,
    this.votosUtil = 0,
    this.votosFalso = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'categoria': categoria.name,
      'colonia': colonia,
      'ubicacion': ubicacion,
      'descripcion': descripcion,
      'fotoUrl': fotoUrl,
      'fechaHora': Timestamp.fromDate(fechaHora),
      'estado': estado.name,
      'usuarioId': usuarioId,
      'votosUtil': votosUtil,
      'votosFalso': votosFalso,
    };
  }

  factory Reporte.fromMap(String id, Map<String, dynamic> map) {
    return Reporte(
      id: id,
      tipo: map['tipo'] as String,
      categoria: CategoriaReporte.values.firstWhere(
        (c) => c.name == map['categoria'],
        orElse: () => CategoriaReporte.otro,
      ),
      colonia: map['colonia'] as String,
      ubicacion: map['ubicacion'] as GeoPoint,
      descripcion: map['descripcion'] as String,
      fotoUrl: map['fotoUrl'] as String?,
      fechaHora: (map['fechaHora'] as Timestamp).toDate(),
      estado: EstadoReporte.values.firstWhere(
        (e) => e.name == map['estado'],
        orElse: () => EstadoReporte.pendiente,
      ),
      usuarioId: map['usuarioId'] as String,
      votosUtil: (map['votosUtil'] as num?)?.toInt() ?? 0,
      votosFalso: (map['votosFalso'] as num?)?.toInt() ?? 0,
    );
  }
}
