import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoría general del reporte. Sirve para agrupar tipos específicos
/// y para elegir el ícono/color en el mapa.
enum CategoriaReporte {
  delictivo, // robo, asalto, riña, vandalismo, actividad sospechosa
  social, // ruido, consumo en vía pública, bloqueos, persona extraviada
  ambiental, // basura, quemas, contaminación de agua/playa, tala ilegal
  infraestructura, // bache, poste caído, alumbrado, semáforo
  riesgoNatural, // inundación, derrumbe, árbol caído
  otro,
}

/// Convierte el texto guardado en Firestore a [CategoriaReporte].
/// Los reportes viejos usan 'seguridad' y 'clima' (categorías que ya no
/// existen); se mapean a las nuevas para que no truene la lectura.
/// Cualquier otro valor desconocido cae en [CategoriaReporte.otro].
CategoriaReporte categoriaDesdeTexto(String? valor) {
  switch (valor) {
    case 'seguridad':
      return CategoriaReporte.delictivo;
    case 'clima':
      return CategoriaReporte.riesgoNatural;
  }
  return CategoriaReporte.values.firstWhere(
    (c) => c.name == valor,
    orElse: () => CategoriaReporte.otro,
  );
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
      categoria: categoriaDesdeTexto(map['categoria'] as String?),
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
