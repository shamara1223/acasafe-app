import '../models/reporte.dart';
import 'constants.dart';

/// Filtros de la lista de reportes del administrador. Se aplican del
/// lado del cliente sobre FirestoreService.todosLosReportes(), así no
/// hacen falta índices compuestos en Firestore.
class FiltrosReportesAdmin {
  /// Texto a buscar en tipo, colonia y descripción. Vacío = sin búsqueda.
  final String texto;

  /// null = todas las categorías.
  final CategoriaReporte? categoria;

  /// null = todos los estados.
  final EstadoReporte? estado;

  /// Primer y último día (ambos incluidos). null = sin límite.
  final DateTime? primerDia;
  final DateTime? ultimoDia;

  const FiltrosReportesAdmin({
    this.texto = '',
    this.categoria,
    this.estado,
    this.primerDia,
    this.ultimoDia,
  });

  /// true si algún filtro está recortando reportes.
  bool get estaActivo =>
      texto.trim().isNotEmpty ||
      categoria != null ||
      estado != null ||
      primerDia != null ||
      ultimoDia != null;

  List<Reporte> aplicar(List<Reporte> reportes) {
    // Cada palabra de la búsqueda debe aparecer en algún campo.
    final palabras = _normalizar(texto)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final desde = primerDia == null
        ? null
        : DateTime(primerDia!.year, primerDia!.month, primerDia!.day);
    final hasta = ultimoDia == null
        ? null
        : DateTime(ultimoDia!.year, ultimoDia!.month, ultimoDia!.day + 1);

    return reportes.where((r) {
      if (categoria != null && r.categoria != categoria) return false;
      if (estado != null && r.estado != estado) return false;
      if (desde != null && r.fechaHora.isBefore(desde)) return false;
      if (hasta != null && !r.fechaHora.isBefore(hasta)) return false;
      if (palabras.isEmpty) return true;

      // Se busca tanto en la clave del tipo ('poste_caido') como en su
      // nombre legible ('Poste caído').
      final contenido = _normalizar(
        '${r.tipo} ${nombreTipoReporte[r.tipo] ?? ''} '
        '${r.colonia} ${r.descripcion}',
      );
      return palabras.every(contenido.contains);
    }).toList();
  }

  /// Minúsculas y sin acentos, para que "inundacion" encuentre
  /// "Inundación".
  static String _normalizar(String texto) {
    const conAcento = 'áéíóúüñ';
    const sinAcento = 'aeiouun';
    final salida = StringBuffer();
    for (final letra in texto.toLowerCase().split('')) {
      final i = conAcento.indexOf(letra);
      salida.write(i == -1 ? letra : sinAcento[i]);
    }
    return salida.toString();
  }
}
