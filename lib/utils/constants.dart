import 'package:flutter/material.dart';

import '../models/reporte.dart';

/// Tipos específicos de reporte que el usuario puede elegir en el
/// formulario. La clave es el valor que se guarda en Firestore (campo
/// `tipo`) — si alguien agrega un tipo nuevo, agréguenlo aquí primero.
const Map<String, CategoriaReporte> tiposDeReporte = {
  'bache': CategoriaReporte.infraestructura,
  'poste_caido': CategoriaReporte.infraestructura,
  'alumbrado_fallando': CategoriaReporte.infraestructura,
  'semaforo_dañado': CategoriaReporte.infraestructura,
  'robo': CategoriaReporte.seguridad,
  'asalto': CategoriaReporte.seguridad,
  'riña': CategoriaReporte.seguridad,
  'inundacion': CategoriaReporte.clima,
  'derrumbe': CategoriaReporte.clima,
  'arbol_caido': CategoriaReporte.clima,
  'otro': CategoriaReporte.otro,
};

/// Nombre legible para mostrar en la UI (la clave de arriba es la que
/// se guarda en la base de datos, esta es la que ve el usuario).
const Map<String, String> nombreTipoReporte = {
  'bache': 'Bache',
  'poste_caido': 'Poste caído',
  'alumbrado_fallando': 'Alumbrado público fallando',
  'semaforo_dañado': 'Semáforo dañado',
  'robo': 'Robo',
  'asalto': 'Asalto',
  'riña': 'Riña / disturbio',
  'inundacion': 'Inundación',
  'derrumbe': 'Derrumbe',
  'arbol_caido': 'Árbol caído',
  'otro': 'Otro',
};

/// Color por categoría, usado tanto en los marcadores del mapa como
/// en las etiquetas de la lista de reportes.
Color colorPorCategoria(CategoriaReporte categoria) {
  switch (categoria) {
    case CategoriaReporte.infraestructura:
      return Colors.orange;
    case CategoriaReporte.seguridad:
      return Colors.red;
    case CategoriaReporte.clima:
      return Colors.blue;
    case CategoriaReporte.otro:
      return Colors.grey;
  }
}

/// Centro aproximado de Acapulco de Juárez, para centrar el mapa al abrir
/// la app antes de obtener la ubicación real del usuario.
const double acapulcoLat = 16.8531;
const double acapulcoLng = -99.8237;
