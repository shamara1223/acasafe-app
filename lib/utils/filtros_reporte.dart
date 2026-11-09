import '../models/reporte.dart';

/// Franja del día según la hora de `fechaHora` (hora local del dispositivo).
enum FranjaHoraria {
  todas('Todas'),
  madrugada('Madrugada (0–6)'),
  manana('Mañana (6–12)'),
  tarde('Tarde (12–18)'),
  noche('Noche (18–24)');

  final String etiqueta;
  const FranjaHoraria(this.etiqueta);

  bool incluye(DateTime fecha) {
    final h = fecha.hour;
    switch (this) {
      case FranjaHoraria.todas:
        return true;
      case FranjaHoraria.madrugada:
        return h < 6;
      case FranjaHoraria.manana:
        return h >= 6 && h < 12;
      case FranjaHoraria.tarde:
        return h >= 12 && h < 18;
      case FranjaHoraria.noche:
        return h >= 18;
    }
  }
}

/// Qué tan atrás en el tiempo se muestran reportes.
enum PeriodoReporte {
  ultimas24h('Últimas 24 h', Duration(hours: 24)),
  ultimos7dias('Últimos 7 días', Duration(days: 7)),
  ultimos30dias('Últimos 30 días', Duration(days: 30)),
  todo('Todo', null);

  final String etiqueta;
  final Duration? duracion; // null = sin límite
  const PeriodoReporte(this.etiqueta, this.duracion);
}

/// Filtros del mapa. Se aplican del lado del cliente sobre el stream de
/// FirestoreService.reportesRecientes(), así no hacen falta índices
/// compuestos nuevos en Firestore.
class FiltrosReporte {
  final Set<CategoriaReporte> categorias;
  final FranjaHoraria franja;
  final PeriodoReporte periodo;

  const FiltrosReporte({
    required this.categorias,
    this.franja = FranjaHoraria.todas,
    this.periodo = PeriodoReporte.todo,
  });

  /// Sin filtros: todas las categorías, todas las horas, todo el periodo.
  factory FiltrosReporte.inicial() =>
      FiltrosReporte(categorias: CategoriaReporte.values.toSet());

  /// true si algún filtro está recortando reportes.
  bool get estaActivo =>
      categorias.length != CategoriaReporte.values.length ||
      franja != FranjaHoraria.todas ||
      periodo != PeriodoReporte.todo;

  FiltrosReporte copyWith({
    Set<CategoriaReporte>? categorias,
    FranjaHoraria? franja,
    PeriodoReporte? periodo,
  }) {
    return FiltrosReporte(
      categorias: categorias ?? this.categorias,
      franja: franja ?? this.franja,
      periodo: periodo ?? this.periodo,
    );
  }

  List<Reporte> aplicar(List<Reporte> reportes, {DateTime? ahora}) {
    final duracion = periodo.duracion;
    final desde =
        duracion == null ? null : (ahora ?? DateTime.now()).subtract(duracion);
    return reportes.where((r) {
      if (!categorias.contains(r.categoria)) return false;
      if (!franja.incluye(r.fechaHora)) return false;
      if (desde != null && r.fechaHora.isBefore(desde)) return false;
      return true;
    }).toList();
  }
}
