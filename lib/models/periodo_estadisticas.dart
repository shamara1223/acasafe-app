import 'package:intl/intl.dart';

/// Opciones del selector de periodo del panel del administrador.
enum TipoPeriodo {
  ultimos7('Últimos 7 días', 7),
  ultimos30('Últimos 30 días', 30),
  ultimos90('Últimos 90 días', 90),
  todo('Todo el historial', null),
  personalizado('Personalizado', null);

  final String etiqueta;
  final int? dias; // null = no es un periodo de N días
  const TipoPeriodo(this.etiqueta, this.dias);
}

/// Intervalo [desde, hasta): incluye `desde`, excluye `hasta`. Es el
/// formato que esperan EstadisticasService y reportesEnRango().
class RangoFechas {
  final DateTime desde;
  final DateTime hasta;

  const RangoFechas(this.desde, this.hasta);
}

/// Periodo elegido en el panel del administrador. También es lo que el
/// panel le pasa a la pestaña Informes al pedir un informe.
class PeriodoEstadisticas {
  final TipoPeriodo tipo;

  /// Solo para [TipoPeriodo.personalizado]: primer y último día, ambos
  /// incluidos.
  final DateTime? primerDia;
  final DateTime? ultimoDia;

  const PeriodoEstadisticas(this.tipo)
      : assert(tipo != TipoPeriodo.personalizado),
        primerDia = null,
        ultimoDia = null;

  const PeriodoEstadisticas.personalizado(
    DateTime this.primerDia,
    DateTime this.ultimoDia,
  ) : tipo = TipoPeriodo.personalizado;

  /// Fechas concretas del periodo.
  ///
  /// "Todo el historial" va desde el día del reporte más antiguo
  /// ([primerReporte]) hasta ahora; si hay algún reporte fechado después
  /// de [ahora] (reloj adelantado en el teléfono que lo envió), el rango
  /// se extiende para incluirlo ([ultimoReporte]).
  RangoFechas rango(
    DateTime ahora, {
    DateTime? primerReporte,
    DateTime? ultimoReporte,
  }) {
    switch (tipo) {
      case TipoPeriodo.ultimos7:
      case TipoPeriodo.ultimos30:
      case TipoPeriodo.ultimos90:
        return RangoFechas(ahora.subtract(Duration(days: tipo.dias!)), ahora);
      case TipoPeriodo.todo:
        final desde = primerReporte == null
            ? ahora.subtract(const Duration(days: 30))
            : DateTime(
                primerReporte.year,
                primerReporte.month,
                primerReporte.day,
              );
        final hasta = ultimoReporte != null && !ultimoReporte.isBefore(ahora)
            ? ultimoReporte.add(const Duration(seconds: 1))
            : ahora;
        return RangoFechas(desde, hasta);
      case TipoPeriodo.personalizado:
        return RangoFechas(
          DateTime(primerDia!.year, primerDia!.month, primerDia!.day),
          // El último día cuenta completo.
          DateTime(ultimoDia!.year, ultimoDia!.month, ultimoDia!.day + 1),
        );
    }
  }

  /// Nombre para mostrar: "Últimos 30 días", "1 oct 2026 – 15 oct 2026".
  String get nombre {
    if (tipo != TipoPeriodo.personalizado) return tipo.etiqueta;
    final formato = DateFormat('d MMM y', 'es_MX');
    return '${formato.format(primerDia!)} – ${formato.format(ultimoDia!)}';
  }

  /// Inicio de las frases de hallazgos ("Del 1 oct 2026 al 15 oct 2026,
  /// la colonia…"). null en los periodos de N días: ahí
  /// EstadisticasService arma solo "En los últimos N días".
  String? get etiquetaFrase {
    switch (tipo) {
      case TipoPeriodo.ultimos7:
      case TipoPeriodo.ultimos30:
      case TipoPeriodo.ultimos90:
        return null;
      case TipoPeriodo.todo:
        return 'En todo el historial';
      case TipoPeriodo.personalizado:
        final formato = DateFormat('d MMM y', 'es_MX');
        return 'Del ${formato.format(primerDia!)} al '
            '${formato.format(ultimoDia!)}';
    }
  }
}
