import '../services/estadisticas_service.dart';
import 'estadisticas_reportes.dart';
import 'periodo_estadisticas.dart';
import 'reporte.dart';

/// Secciones que se pueden incluir en el informe PDF, en el orden en que
/// aparecen dentro del documento.
enum SeccionInforme {
  resumen('Resumen ejecutivo'),
  categorias('Distribución por categoría'),
  tipos('Tipos más reportados'),
  colonias('Colonias con más reportes'),
  horario('Análisis por franja horaria y día de la semana'),
  tendencia('Tendencia en el tiempo'),
  moderacion('Estado de moderación'),
  hallazgos('Hallazgos automáticos'),
  tabla('Tabla detallada de reportes');

  final String titulo;
  const SeccionInforme(this.titulo);
}

/// Lo que el administrador eligió en el configurador de Informes.
class OpcionesInforme {
  final PeriodoEstadisticas periodo;

  /// Categorías incluidas. Vacío = ningún reporte cumple.
  final Set<CategoriaReporte> categorias;

  /// Si se cuentan los reportes que un admin marcó como falsos.
  final bool incluirFalsos;

  final Set<SeccionInforme> secciones;

  /// Título escrito por el admin; vacío = [tituloPorDefecto].
  final String titulo;

  static const tituloPorDefecto = 'Informe de reportes ciudadanos';

  OpcionesInforme({
    this.periodo = const PeriodoEstadisticas(TipoPeriodo.ultimos30),
    Set<CategoriaReporte>? categorias,
    this.incluirFalsos = false,
    Set<SeccionInforme>? secciones,
    this.titulo = '',
  })  : categorias = categorias ?? CategoriaReporte.values.toSet(),
        secciones = secciones ?? SeccionInforme.values.toSet();

  OpcionesInforme copyWith({
    PeriodoEstadisticas? periodo,
    Set<CategoriaReporte>? categorias,
    bool? incluirFalsos,
    Set<SeccionInforme>? secciones,
    String? titulo,
  }) {
    return OpcionesInforme(
      periodo: periodo ?? this.periodo,
      categorias: categorias ?? this.categorias,
      incluirFalsos: incluirFalsos ?? this.incluirFalsos,
      secciones: secciones ?? this.secciones,
      titulo: titulo ?? this.titulo,
    );
  }

  bool get todasLasCategorias =>
      categorias.length == CategoriaReporte.values.length;

  String get tituloFinal =>
      titulo.trim().isEmpty ? tituloPorDefecto : titulo.trim();

  /// Reportes de las categorías elegidas (y sin falsos, si así se pidió),
  /// de cualquier fecha: el periodo se aplica en [DatosInforme.calcular]
  /// para que el periodo anterior sirva al % de cambio.
  List<Reporte> filtrar(List<Reporte> reportes) {
    return reportes
        .where((r) => categorias.contains(r.categoria))
        .where((r) => incluirFalsos || r.estado != EstadoReporte.falso)
        .toList();
  }
}

/// Todo lo que necesita el PDF, ya calculado con EstadisticasService.
/// También lo usa el configurador para saber cuántos reportes cumplen
/// los criterios.
class DatosInforme {
  final OpcionesInforme opciones;
  final RangoFechas rango;
  final EstadisticasReportes stats;
  final List<String> hallazgos;

  /// Reportes del periodo que cumplen los criterios, del más reciente al
  /// más antiguo (para la tabla detallada).
  final List<Reporte> reportes;

  const DatosInforme._({
    required this.opciones,
    required this.rango,
    required this.stats,
    required this.hallazgos,
    required this.reportes,
  });

  factory DatosInforme.calcular(
    List<Reporte> todos,
    OpcionesInforme opciones, {
    required DateTime ahora,
  }) {
    const servicio = EstadisticasService();
    final filtrados = opciones.filtrar(todos);

    DateTime? primero, ultimo;
    for (final r in filtrados) {
      if (primero == null || r.fechaHora.isBefore(primero)) primero = r.fechaHora;
      if (ultimo == null || r.fechaHora.isAfter(ultimo)) ultimo = r.fechaHora;
    }
    final rango = opciones.periodo
        .rango(ahora, primerReporte: primero, ultimoReporte: ultimo);

    final delPeriodo = filtrados
        .where((r) =>
            !r.fechaHora.isBefore(rango.desde) &&
            r.fechaHora.isBefore(rango.hasta))
        .toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

    return DatosInforme._(
      opciones: opciones,
      rango: rango,
      stats: servicio.calcular(
        filtrados,
        desde: rango.desde,
        hasta: rango.hasta,
        limiteColonias: 10,
      ),
      hallazgos: servicio.generarHallazgos(
        filtrados,
        desde: rango.desde,
        hasta: rango.hasta,
        etiquetaPeriodo: opciones.periodo.etiquetaFrase,
      ),
      reportes: delPeriodo,
    );
  }

  int get total => stats.total;
}
