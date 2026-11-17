import '../models/estadisticas_reportes.dart';
import '../models/reporte.dart';
import '../utils/constants.dart';
import '../utils/filtros_reporte.dart';

/// Estadísticas y hallazgos sobre una lista de reportes.
///
/// Todo aquí son funciones puras: reciben los reportes ya descargados y
/// no tocan Firestore ni el reloj, así se pueden probar sin Firebase y
/// las usan igual el resumen del ciudadano y el panel del administrador.
///
/// Uso típico (para que el % de cambio tenga datos, la consulta debe
/// traer también el periodo anterior):
///
///   final inicio = estadisticas.inicioPeriodoAnterior(desde, hasta);
///   firestore.reportesEnRango(inicio, hasta) → calcular(reportes, ...)
class EstadisticasService {
  const EstadisticasService();

  /// Mínimo de reportes que deben respaldar una frase de hallazgo.
  static const minimoParaHallazgo = 3;

  /// Máximo de frases que regresa [generarHallazgos].
  static const maximoHallazgos = 5;

  /// Hasta este largo de periodo la tendencia va por día; más largo,
  /// por semana.
  static const _maximoTendenciaPorDia = Duration(days: 31);

  /// Inicio del periodo anterior del mismo largo que [desde, hasta).
  DateTime inicioPeriodoAnterior(DateTime desde, DateTime hasta) {
    return desde.subtract(hasta.difference(desde));
  }

  /// Colonia lista para agrupar, o null si no está identificada (vacía
  /// o el valor por defecto 'Acapulco de Juárez').
  String? coloniaIdentificada(String colonia) {
    final limpia = colonia.trim();
    if (limpia.isEmpty) return null;
    if (limpia.toLowerCase() == coloniaPorDefecto.toLowerCase()) return null;
    return limpia;
  }

  /// Calcula las estadísticas del periodo [desde, hasta).
  ///
  /// [reportes] puede traer reportes de fuera del periodo: los del
  /// periodo anterior se usan para el % de cambio y el resto se ignora.
  /// No filtra por estado; cuenta lo que recibe.
  EstadisticasReportes calcular(
    List<Reporte> reportes, {
    required DateTime desde,
    required DateTime hasta,
    int limiteColonias = 5,
  }) {
    final actuales = _enRango(reportes, desde, hasta);
    final totalAnterior =
        _enRango(reportes, inicioPeriodoAnterior(desde, hasta), desde).length;

    final porCategoria = {for (final c in CategoriaReporte.values) c: 0};
    final porEstado = {for (final e in EstadoReporte.values) e: 0};
    final porFranja = {
      for (final f in FranjaHoraria.values)
        if (f != FranjaHoraria.todas) f: 0,
    };
    final porDiaSemana = {for (var d = 1; d <= 7; d++) d: 0};
    final porTipo = <String, int>{};
    final porHora = <int, int>{};
    final porColonia = <String, int>{};
    final porColoniaYCategoria = {
      for (final c in CategoriaReporte.values) c: <String, int>{},
    };
    var sinColonia = 0;

    for (final r in actuales) {
      porCategoria[r.categoria] = porCategoria[r.categoria]! + 1;
      porEstado[r.estado] = porEstado[r.estado]! + 1;
      porTipo[r.tipo] = (porTipo[r.tipo] ?? 0) + 1;
      final franja = franjaDe(r.fechaHora);
      porFranja[franja] = porFranja[franja]! + 1;
      porDiaSemana[r.fechaHora.weekday] = porDiaSemana[r.fechaHora.weekday]! + 1;
      porHora[r.fechaHora.hour] = (porHora[r.fechaHora.hour] ?? 0) + 1;

      final colonia = coloniaIdentificada(r.colonia);
      if (colonia == null) {
        sinColonia++;
      } else {
        porColonia[colonia] = (porColonia[colonia] ?? 0) + 1;
        final deCategoria = porColoniaYCategoria[r.categoria]!;
        deCategoria[colonia] = (deCategoria[colonia] ?? 0) + 1;
      }
    }

    final porDia = hasta.difference(desde) <= _maximoTendenciaPorDia;

    return EstadisticasReportes(
      desde: desde,
      hasta: hasta,
      total: actuales.length,
      totalAnterior: totalAnterior,
      cambioPorcentual: totalAnterior == 0
          ? null
          : (actuales.length - totalAnterior) / totalAnterior * 100,
      porCategoria: porCategoria,
      porTipo: Map.fromEntries(_ordenadoPorConteo(porTipo)),
      porEstado: porEstado,
      topColonias: _topColonias(
        porColonia,
        limiteColonias,
        desglose: porColoniaYCategoria,
      ),
      topColoniasPorCategoria: {
        for (final c in CategoriaReporte.values)
          c: _topColonias(porColoniaYCategoria[c]!, limiteColonias),
      },
      sinColonia: sinColonia,
      porFranja: porFranja,
      porDiaSemana: porDiaSemana,
      // Con empate gana la hora más temprana.
      horaPico: porHora.isEmpty ? null : _ordenadoPorConteo(porHora).first.key,
      granularidad:
          porDia ? GranularidadTendencia.dia : GranularidadTendencia.semana,
      tendencia: _tendencia(actuales, desde, hasta, diasPorPunto: porDia ? 1 : 7),
    );
  }

  /// Franja horaria (madrugada, mañana, tarde o noche) de una fecha.
  FranjaHoraria franjaDe(DateTime fecha) {
    return FranjaHoraria.values.firstWhere(
      (f) => f != FranjaHoraria.todas && f.incluye(fecha),
    );
  }

  /// Frases en español con lo más notable del periodo [desde, hasta),
  /// de la más a la menos relevante (máximo [maximoHallazgos]).
  ///
  /// Reglas:
  /// - Cada frase necesita al menos [minimoParaHallazgo] reportes que la
  ///   respalden; con pocos datos la lista puede salir vacía.
  /// - Las frases describen cantidad de reportes ("con más reportes"),
  ///   nunca califican a una colonia como peligrosa: más reportes no
  ///   significa más riesgo, también puede ser más participación.
  /// - Relevancia = reportes que respaldan la frase × qué tan marcado es
  ///   el patrón (su proporción), para que un patrón concentrado pese
  ///   más que uno apenas visible.
  ///
  /// [etiquetaPeriodo] reemplaza el inicio de las frases ("En los
  /// últimos 30 días"); sirve cuando el periodo no termina hoy, por
  /// ejemplo 'En octubre'.
  List<String> generarHallazgos(
    List<Reporte> reportes, {
    required DateTime desde,
    required DateTime hasta,
    String? etiquetaPeriodo,
  }) {
    final stats = calcular(reportes, desde: desde, hasta: hasta);
    if (stats.total < minimoParaHallazgo &&
        stats.totalAnterior < minimoParaHallazgo) {
      return const [];
    }
    final actuales = _enRango(reportes, desde, hasta);
    final periodo = etiquetaPeriodo ?? _etiquetaPeriodo(desde, hasta);
    final candidatos = <_Hallazgo>[];

    // 1. Colonia que concentra los reportes de una categoría (máx. 2).
    final porCategoria = <_Hallazgo>[];
    for (final c in CategoriaReporte.values) {
      final top = stats.topColoniasPorCategoria[c]!;
      if (top.isEmpty) continue;
      final lider = top.first;
      final proporcion = lider.conteo / stats.porCategoria[c]!;
      if (lider.conteo < minimoParaHallazgo || proporcion < 0.25) continue;

      // "principalmente de noche": solo si al menos la mitad de esos
      // reportes (y no menos de 3) cae en la misma franja.
      final franjas = <FranjaHoraria, int>{};
      for (final r in actuales) {
        if (r.categoria == c && coloniaIdentificada(r.colonia) == lider.colonia) {
          final f = franjaDe(r.fechaHora);
          franjas[f] = (franjas[f] ?? 0) + 1;
        }
      }
      final franjaLider = _ordenadoPorConteo(franjas).first;
      final conFranja = franjaLider.value >= minimoParaHallazgo &&
          franjaLider.value * 2 >= lider.conteo;

      porCategoria.add(_Hallazgo(
        lider.conteo * proporcion,
        '$periodo, la colonia ${lider.colonia} concentró el '
        '${_porcentaje(proporcion)} de los reportes ${_deCategoria[c]}'
        '${conFranja ? ', principalmente ${_enFranja[franjaLider.key]}' : ''}.',
      ));
    }
    porCategoria.sort(_porRelevancia);
    candidatos.addAll(porCategoria.take(2));

    // 2. Colonia con más reportes en general.
    if (stats.topColonias.isNotEmpty) {
      final lider = stats.topColonias.first;
      if (lider.conteo >= minimoParaHallazgo) {
        final proporcion = lider.conteo / stats.total;
        candidatos.add(_Hallazgo(
          lider.conteo * proporcion,
          '$periodo, ${lider.colonia} fue la colonia con más reportes: '
          '${lider.conteo} de ${stats.total} (${_porcentaje(proporcion)}).',
        ));
      }
    }

    // 3. Cambio contra el periodo anterior (si cambió al menos 10 %).
    final cambio = stats.cambioPorcentual;
    if (cambio != null &&
        stats.totalAnterior >= minimoParaHallazgo &&
        cambio.abs() >= 10) {
      final magnitud = cambio.abs() > 100 ? 1.0 : cambio.abs() / 100;
      final mayor = stats.total > stats.totalAnterior
          ? stats.total
          : stats.totalAnterior;
      candidatos.add(_Hallazgo(
        mayor * magnitud,
        '$periodo se ${stats.total == 1 ? 'registró' : 'registraron'} '
        '${_reportes(stats.total)}, un ${cambio.abs().round()} % '
        '${cambio > 0 ? 'más' : 'menos'} que en el periodo anterior '
        '(${stats.totalAnterior}).',
      ));
    }

    // 4. Franja horaria que concentra los reportes (al menos 40 %).
    if (stats.total > 0) {
      final franja = _ordenadoPorConteo(stats.porFranja).first;
      final proporcion = franja.value / stats.total;
      if (franja.value >= minimoParaHallazgo && proporcion >= 0.4) {
        candidatos.add(_Hallazgo(
          franja.value * proporcion,
          '$periodo, el ${_porcentaje(proporcion)} de los reportes ocurrió '
          '${_enFranja[franja.key]}.',
        ));
      }
    }

    // 5. Día de la semana con más reportes (al menos 25 %). Solo tiene
    //    sentido si el periodo cubre por lo menos una semana completa.
    if (stats.total > 0 && hasta.difference(desde) >= const Duration(days: 7)) {
      final dia = _ordenadoPorConteo(stats.porDiaSemana).first;
      final proporcion = dia.value / stats.total;
      if (dia.value >= minimoParaHallazgo && proporcion >= 0.25) {
        candidatos.add(_Hallazgo(
          dia.value * proporcion,
          '$periodo, el día de la semana con más reportes fue el '
          '${_diasSemana[dia.key - 1]} (${dia.value} de ${stats.total}).',
        ));
      }
    }

    // 6. Tipo de incidencia más frecuente (al menos 25 %).
    if (stats.porTipo.isNotEmpty) {
      final tipo = stats.porTipo.entries.first;
      final proporcion = tipo.value / stats.total;
      if (tipo.value >= minimoParaHallazgo && proporcion >= 0.25) {
        candidatos.add(_Hallazgo(
          tipo.value * proporcion,
          '$periodo, el tipo de incidencia con más reportes fue '
          '«${nombreTipoReporte[tipo.key] ?? tipo.key}» '
          '(${tipo.value} de ${stats.total}).',
        ));
      }
    }

    // El sort de Dart no es estable; con la misma relevancia se respeta
    // el orden en que se generaron los candidatos.
    final indices = List.generate(candidatos.length, (i) => i)
      ..sort((a, b) {
        final cmp = _porRelevancia(candidatos[a], candidatos[b]);
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    return indices
        .take(maximoHallazgos)
        .map((i) => candidatos[i].frase)
        .toList();
  }

  // ---------------------------------------------------------------------
  // Auxiliares
  // ---------------------------------------------------------------------

  List<Reporte> _enRango(List<Reporte> reportes, DateTime desde, DateTime hasta) {
    return reportes
        .where((r) => !r.fechaHora.isBefore(desde) && r.fechaHora.isBefore(hasta))
        .toList();
  }

  /// Entradas de mayor a menor conteo; con empate, por clave ascendente
  /// para que el resultado sea siempre el mismo.
  List<MapEntry<K, int>> _ordenadoPorConteo<K>(Map<K, int> conteos) {
    return conteos.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        final ka = a.key, kb = b.key;
        if (ka is Enum && kb is Enum) return ka.index.compareTo(kb.index);
        return (ka as Comparable).compareTo(kb);
      });
  }

  /// [desglose] (categoría → colonia → conteo) llena el desglose por
  /// categoría de cada colonia del ranking.
  List<ConteoColonia> _topColonias(
    Map<String, int> conteos,
    int limite, {
    Map<CategoriaReporte, Map<String, int>>? desglose,
  }) {
    return _ordenadoPorConteo(conteos).take(limite).map((e) {
      return ConteoColonia(
        e.key,
        e.value,
        porCategoria: desglose == null
            ? const {}
            : {
                for (final c in CategoriaReporte.values)
                  if ((desglose[c]![e.key] ?? 0) > 0) c: desglose[c]![e.key]!,
              },
      );
    }).toList();
  }

  /// Un punto por día (o por bloque de 7 días), empezando en el día de
  /// [desde]. El último bloque semanal puede quedar incompleto.
  List<PuntoTendencia> _tendencia(
    List<Reporte> actuales,
    DateTime desde,
    DateTime hasta, {
    required int diasPorPunto,
  }) {
    final puntos = <PuntoTendencia>[];
    var inicio = DateTime(desde.year, desde.month, desde.day);
    while (inicio.isBefore(hasta)) {
      // Se suma en días de calendario (no 24 h) para que un cambio de
      // horario no desfase los puntos.
      final fin = DateTime(inicio.year, inicio.month, inicio.day + diasPorPunto);
      final conteo = actuales
          .where((r) => !r.fechaHora.isBefore(inicio) && r.fechaHora.isBefore(fin))
          .length;
      puntos.add(PuntoTendencia(inicio, conteo));
      inicio = fin;
    }
    return puntos;
  }

  String _etiquetaPeriodo(DateTime desde, DateTime hasta) {
    final horas = hasta.difference(desde).inHours;
    if (horas <= 36) return 'En las últimas 24 horas';
    return 'En los últimos ${(horas / 24).round()} días';
  }

  String _porcentaje(double proporcion) => '${(proporcion * 100).round()} %';

  String _reportes(int n) => n == 1 ? '1 reporte' : '$n reportes';

  int _porRelevancia(_Hallazgo a, _Hallazgo b) =>
      b.relevancia.compareTo(a.relevancia);

  // "los reportes ___"
  static const _deCategoria = {
    CategoriaReporte.delictivo: 'delictivos',
    CategoriaReporte.social: 'sociales',
    CategoriaReporte.ambiental: 'ambientales',
    CategoriaReporte.infraestructura: 'de infraestructura vial',
    CategoriaReporte.riesgoNatural: 'de riesgo natural',
    CategoriaReporte.otro: 'de otro tipo',
  };

  // "ocurrió ___"
  static const _enFranja = {
    FranjaHoraria.madrugada: 'de madrugada',
    FranjaHoraria.manana: 'por la mañana',
    FranjaHoraria.tarde: 'por la tarde',
    FranjaHoraria.noche: 'de noche',
  };

  static const _diasSemana = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
}

class _Hallazgo {
  final double relevancia;
  final String frase;

  const _Hallazgo(this.relevancia, this.frase);
}
