import 'package:flutter/material.dart';

import '../models/reporte.dart';

/// Tipos específicos de reporte que el usuario puede elegir en el
/// formulario. La clave es el valor que se guarda en Firestore (campo
/// `tipo`) — si alguien agrega un tipo nuevo, agréguenlo aquí primero.
/// El orden de este mapa es el orden en que aparecen en el formulario.
const Map<String, CategoriaReporte> tiposDeReporte = {
  // Delictivo
  'robo': CategoriaReporte.delictivo,
  'asalto': CategoriaReporte.delictivo,
  'riña': CategoriaReporte.delictivo,
  'vandalismo': CategoriaReporte.delictivo,
  'actividad_sospechosa': CategoriaReporte.delictivo,
  // Social
  'ruido_excesivo': CategoriaReporte.social,
  'consumo_via_publica': CategoriaReporte.social,
  'bloqueo_manifestacion': CategoriaReporte.social,
  'persona_extraviada': CategoriaReporte.social,
  // Ambiental
  'basura_acumulada': CategoriaReporte.ambiental,
  'quema_basura': CategoriaReporte.ambiental,
  'contaminacion_agua_playa': CategoriaReporte.ambiental,
  'tala_ilegal': CategoriaReporte.ambiental,
  // Infraestructura vial
  'bache': CategoriaReporte.infraestructura,
  'poste_caido': CategoriaReporte.infraestructura,
  'alumbrado_fallando': CategoriaReporte.infraestructura,
  'semaforo_dañado': CategoriaReporte.infraestructura,
  // Riesgo natural
  'inundacion': CategoriaReporte.riesgoNatural,
  'derrumbe': CategoriaReporte.riesgoNatural,
  'arbol_caido': CategoriaReporte.riesgoNatural,
  // Otro
  'otro': CategoriaReporte.otro,
};

/// Nombre legible para mostrar en la UI (la clave de arriba es la que
/// se guarda en la base de datos, esta es la que ve el usuario).
const Map<String, String> nombreTipoReporte = {
  'robo': 'Robo',
  'asalto': 'Asalto',
  'riña': 'Riña / disturbio',
  'vandalismo': 'Vandalismo',
  'actividad_sospechosa': 'Actividad sospechosa',
  'ruido_excesivo': 'Ruido excesivo',
  'consumo_via_publica': 'Consumo en vía pública',
  'bloqueo_manifestacion': 'Bloqueo / manifestación',
  'persona_extraviada': 'Persona extraviada',
  'basura_acumulada': 'Basura acumulada',
  'quema_basura': 'Quema de basura',
  'contaminacion_agua_playa': 'Contaminación de agua o playa',
  'tala_ilegal': 'Tala ilegal',
  'bache': 'Bache',
  'poste_caido': 'Poste caído',
  'alumbrado_fallando': 'Alumbrado público fallando',
  'semaforo_dañado': 'Semáforo dañado',
  'inundacion': 'Inundación',
  'derrumbe': 'Derrumbe',
  'arbol_caido': 'Árbol caído',
  'otro': 'Otro',
};

/// Tipos que pertenecen a una categoría, en el orden de [tiposDeReporte].
/// Lo usa el formulario para mostrar solo los tipos de la categoría elegida.
List<String> tiposDeCategoria(CategoriaReporte categoria) {
  return tiposDeReporte.entries
      .where((e) => e.value == categoria)
      .map((e) => e.key)
      .toList();
}

/// Nombre legible e ícono de una categoría.
class InfoCategoria {
  final String nombre;
  final IconData icono;

  const InfoCategoria(this.nombre, this.icono);
}

/// Nombre e ícono de cada categoría, para el formulario, los marcadores
/// del mapa, la leyenda y los filtros.
const Map<CategoriaReporte, InfoCategoria> infoCategoria = {
  CategoriaReporte.delictivo: InfoCategoria('Delictivo', Icons.local_police),
  CategoriaReporte.social: InfoCategoria('Social', Icons.groups),
  CategoriaReporte.ambiental: InfoCategoria('Ambiental', Icons.eco),
  CategoriaReporte.infraestructura:
      InfoCategoria('Infraestructura vial', Icons.construction),
  CategoriaReporte.riesgoNatural: InfoCategoria('Riesgo natural', Icons.flood),
  CategoriaReporte.otro: InfoCategoria('Otro', Icons.help_outline),
};

/// Color por categoría, usado tanto en los marcadores del mapa como
/// en las etiquetas de la lista de reportes.
Color colorPorCategoria(CategoriaReporte categoria) {
  switch (categoria) {
    case CategoriaReporte.delictivo:
      return Colors.red;
    case CategoriaReporte.social:
      return Colors.purple;
    case CategoriaReporte.ambiental:
      return Colors.green;
    case CategoriaReporte.infraestructura:
      return Colors.orange;
    case CategoriaReporte.riesgoNatural:
      return Colors.blue;
    case CategoriaReporte.otro:
      return Colors.grey;
  }
}

/// Nombre legible, ícono y color de un estado de moderación.
class InfoEstado {
  final String nombre;
  final IconData icono;
  final Color color;

  const InfoEstado(this.nombre, this.icono, this.color);
}

/// Nombre, ícono y color de cada estado, para las etiquetas de la lista
/// de reportes del admin y la gráfica de distribución por estado.
/// Son tonos oscuros para que el texto de ese color se lea sobre blanco.
const Map<EstadoReporte, InfoEstado> infoEstado = {
  EstadoReporte.pendiente:
      InfoEstado('Pendiente', Icons.hourglass_empty, Color(0xFFB26A00)),
  EstadoReporte.verificado:
      InfoEstado('Verificado', Icons.verified, Color(0xFF2E7D32)),
  EstadoReporte.falso: InfoEstado('Falso', Icons.block, Color(0xFFC62828)),
  EstadoReporte.resuelto:
      InfoEstado('Resuelto', Icons.task_alt, Color(0xFF1565C0)),
};

/// Valor que se guarda en `colonia` cuando no se pudo detectar la colonia
/// exacta. Las estadísticas lo tratan como "colonia no identificada".
const String coloniaPorDefecto = 'Acapulco de Juárez';

/// Centro aproximado de Acapulco de Juárez, para centrar el mapa al abrir
/// la app antes de obtener la ubicación real del usuario.
const double acapulcoLat = 16.8531;
const double acapulcoLng = -99.8237;
