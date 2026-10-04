import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reporte.dart';

/// Todo el acceso a la colección `reportes` pasa por aquí.
/// Mantener las queries centralizadas facilita, más adelante, exportar
/// los mismos filtros a un script de Python para el análisis de la Fase 2
/// (mapas de calor, porcentajes por zona/horario).
class FirestoreService {
  final CollectionReference<Map<String, dynamic>> _reportes =
      FirebaseFirestore.instance.collection('reportes');

  Future<String> crearReporte(Reporte reporte) async {
    final doc = await _reportes.add(reporte.toMap());
    return doc.id;
  }

  /// Reportes recientes para pintar en el mapa principal.
  /// Por defecto solo trae los 'verificado' y 'pendiente' (no los
  /// marcados como 'falso'), para no saturar el mapa con ruido.
  Stream<List<Reporte>> reportesRecientes({int limite = 200}) {
    return _reportes
        .where('estado', whereIn: ['pendiente', 'verificado'])
        .orderBy('fechaHora', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Reporte.fromMap(d.id, d.data())).toList());
  }

  /// Reportes de una colonia específica — útil para la pantalla de
  /// detalle por zona y, después, para alimentar las estadísticas.
  Stream<List<Reporte>> reportesPorColonia(String colonia) {
    return _reportes
        .where('colonia', isEqualTo: colonia)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Reporte.fromMap(d.id, d.data())).toList());
  }

  Future<void> votar({
    required String reporteId,
    required bool esUtil,
  }) {
    final campo = esUtil ? 'votosUtil' : 'votosFalso';
    return _reportes.doc(reporteId).update({
      campo: FieldValue.increment(1),
    });
  }

  Future<void> actualizarEstado({
    required String reporteId,
    required EstadoReporte nuevoEstado,
  }) {
    return _reportes.doc(reporteId).update({'estado': nuevoEstado.name});
  }
}
