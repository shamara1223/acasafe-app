import '../utils/filtros_reporte.dart';
import 'reporte.dart';

/// Texto para mostrar cuando un reporte no tiene colonia exacta.
const String coloniaNoIdentificada = 'Colonia no identificada';

/// Cuántos reportes tiene una colonia.
class ConteoColonia {
  final String colonia;
  final int conteo;

  /// Desglose de [conteo] por categoría (solo las que tienen reportes).
  /// Solo viene lleno en [EstadisticasReportes.topColonias]; en los
  /// rankings por categoría queda vacío porque no hace falta.
  final Map<CategoriaReporte, int> porCategoria;

  const ConteoColonia(this.colonia, this.conteo, {this.porCategoria = const {}});
}

/// Si la tendencia está agrupada por día o por semana.
enum GranularidadTendencia { dia, semana }

/// Un punto de la gráfica de tendencia: cuántos reportes hubo en el día
/// (o en los 7 días) que empieza en [inicio].
class PuntoTendencia {
  final DateTime inicio;
  final int conteo;

  const PuntoTendencia(this.inicio, this.conteo);
}

/// Resumen estadístico de los reportes de un periodo [desde, hasta).
/// Lo calcula EstadisticasService.calcular(); aquí solo hay datos.
class EstadisticasReportes {
  final DateTime desde;
  final DateTime hasta;

  /// Reportes dentro del periodo.
  final int total;

  /// Reportes en el periodo anterior del mismo largo.
  final int totalAnterior;

  /// % de cambio contra el periodo anterior (25.0 = 25 % más).
  /// null si el periodo anterior no tuvo reportes (no hay contra qué
  /// comparar).
  final double? cambioPorcentual;

  /// Incluye todas las categorías, aunque tengan 0.
  final Map<CategoriaReporte, int> porCategoria;

  /// Solo los tipos que aparecen, del más al menos frecuente.
  final Map<String, int> porTipo;

  /// Incluye todos los estados, aunque tengan 0.
  final Map<EstadoReporte, int> porEstado;

  /// Colonias con más reportes. No incluye la "no identificada".
  final List<ConteoColonia> topColonias;

  /// Colonias con más reportes de cada categoría. No incluye la
  /// "no identificada"; una categoría sin colonias tiene lista vacía.
  final Map<CategoriaReporte, List<ConteoColonia>> topColoniasPorCategoria;

  /// Reportes sin colonia exacta ([coloniaNoIdentificada]).
  final int sinColonia;

  /// Madrugada, mañana, tarde y noche (sin [FranjaHoraria.todas]).
  final Map<FranjaHoraria, int> porFranja;

  /// Clave 1 = lunes … 7 = domingo (igual que DateTime.weekday).
  final Map<int, int> porDiaSemana;

  /// Hora del día (0–23) con más reportes; null si no hay reportes.
  final int? horaPico;

  final GranularidadTendencia granularidad;

  /// Del punto más antiguo al más reciente, con los ceros incluidos.
  final List<PuntoTendencia> tendencia;

  const EstadisticasReportes({
    required this.desde,
    required this.hasta,
    required this.total,
    required this.totalAnterior,
    required this.cambioPorcentual,
    required this.porCategoria,
    required this.porTipo,
    required this.porEstado,
    required this.topColonias,
    required this.topColoniasPorCategoria,
    required this.sinColonia,
    required this.porFranja,
    required this.porDiaSemana,
    required this.horaPico,
    required this.granularidad,
    required this.tendencia,
  });
}
