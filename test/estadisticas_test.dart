// Tests de las estadísticas y los hallazgos automáticos. Son funciones
// puras, así que no hace falta inicializar Firebase.

import 'package:acasafe/models/estadisticas_reportes.dart';
import 'package:acasafe/models/reporte.dart';
import 'package:acasafe/services/estadisticas_service.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:acasafe/utils/filtros_reporte.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Reporte _reporte(
  CategoriaReporte categoria,
  String tipo,
  String colonia,
  DateTime fechaHora, {
  EstadoReporte estado = EstadoReporte.pendiente,
}) {
  return Reporte(
    tipo: tipo,
    categoria: categoria,
    colonia: colonia,
    ubicacion: const GeoPoint(acapulcoLat, acapulcoLng),
    descripcion: 'Prueba',
    fechaHora: fechaHora,
    estado: estado,
    usuarioId: 'test',
  );
}

void main() {
  const servicio = EstadisticasService();

  // Jueves 12 de noviembre de 2026 a mediodía; periodo de 30 días.
  final hasta = DateTime(2026, 11, 12, 12);
  final desde = hasta.subtract(const Duration(days: 30)); // 13 oct, 12:00

  // 9 reportes en el periodo, 6 en el periodo anterior y 1 más viejo.
  final reportes = [
    // Delictivos en Progreso, de noche.
    _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
        DateTime(2026, 11, 7, 22)), // sábado
    _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
        DateTime(2026, 11, 7, 23)), // sábado
    _reporte(CategoriaReporte.delictivo, 'robo', ' Progreso ',
        DateTime(2026, 11, 6, 22)), // viernes; con espacios de más
    _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
        DateTime(2026, 11, 5, 22)), // jueves
    _reporte(CategoriaReporte.delictivo, 'asalto', 'Centro',
        DateTime(2026, 11, 3, 10)), // martes
    _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
        DateTime(2026, 11, 2, 9)), // lunes
    _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
        DateTime(2026, 11, 2, 10)), // lunes
    // Sin colonia exacta.
    _reporte(CategoriaReporte.ambiental, 'basura_acumulada',
        'Acapulco de Juárez', DateTime(2026, 11, 1, 15)), // domingo
    _reporte(CategoriaReporte.otro, 'otro', '', DateTime(2026, 10, 20, 3),
        estado: EstadoReporte.verificado), // martes
    // Periodo anterior (13 sep – 13 oct).
    for (var i = 0; i < 6; i++)
      _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Costa Azul',
          DateTime(2026, 10, 1 + i, 20)),
    // Fuera de ambos periodos: se ignora.
    _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Costa Azul',
        DateTime(2026, 8, 1, 20)),
  ];

  group('EstadisticasService.calcular', () {
    final stats = servicio.calcular(reportes, desde: desde, hasta: hasta);

    test('total y % de cambio contra el periodo anterior', () {
      expect(stats.total, 9);
      expect(stats.totalAnterior, 6);
      expect(stats.cambioPorcentual, closeTo(50, 0.001));
    });

    test('sin periodo anterior no hay % de cambio', () {
      final soloActuales = reportes
          .where((r) => !r.fechaHora.isBefore(desde))
          .toList();
      final s = servicio.calcular(soloActuales, desde: desde, hasta: hasta);
      expect(s.totalAnterior, 0);
      expect(s.cambioPorcentual, isNull);
    });

    test('el límite del periodo incluye `desde` y excluye `hasta`', () {
      final s = servicio.calcular(
        [
          _reporte(CategoriaReporte.otro, 'otro', 'Centro', desde),
          _reporte(CategoriaReporte.otro, 'otro', 'Centro', hasta),
        ],
        desde: desde,
        hasta: hasta,
      );
      expect(s.total, 1);
    });

    test('conteo por categoría, tipo y estado', () {
      expect(stats.porCategoria[CategoriaReporte.delictivo], 5);
      expect(stats.porCategoria[CategoriaReporte.infraestructura], 2);
      expect(stats.porCategoria[CategoriaReporte.ambiental], 1);
      expect(stats.porCategoria[CategoriaReporte.otro], 1);
      // Las categorías sin reportes aparecen con 0.
      expect(stats.porCategoria[CategoriaReporte.social], 0);
      expect(stats.porCategoria[CategoriaReporte.riesgoNatural], 0);

      // Ordenado del más al menos frecuente.
      expect(stats.porTipo.keys.first, 'robo');
      expect(stats.porTipo, {
        'robo': 4,
        'bache': 2,
        'asalto': 1,
        'basura_acumulada': 1,
        'otro': 1,
      });

      expect(stats.porEstado[EstadoReporte.pendiente], 8);
      expect(stats.porEstado[EstadoReporte.verificado], 1);
      expect(stats.porEstado[EstadoReporte.falso], 0);
    });

    test('top colonias excluye la colonia no identificada', () {
      expect(stats.topColonias.map((c) => c.colonia), ['Progreso', 'Centro']);
      expect(stats.topColonias.map((c) => c.conteo), [4, 3]);
      expect(stats.sinColonia, 2);
    });

    test('top colonias por categoría', () {
      final delictivo = stats.topColoniasPorCategoria[CategoriaReporte.delictivo]!;
      expect(delictivo.map((c) => c.colonia), ['Progreso', 'Centro']);
      expect(delictivo.map((c) => c.conteo), [4, 1]);
      // Su único reporte no tiene colonia identificada.
      expect(stats.topColoniasPorCategoria[CategoriaReporte.ambiental], isEmpty);
      expect(stats.topColoniasPorCategoria[CategoriaReporte.social], isEmpty);
    });

    test('limiteColonias recorta el ranking', () {
      final s = servicio.calcular(reportes,
          desde: desde, hasta: hasta, limiteColonias: 1);
      expect(s.topColonias, hasLength(1));
      expect(s.topColonias.first.colonia, 'Progreso');
    });

    test('coloniaIdentificada trata vacío y el valor por defecto como null', () {
      expect(servicio.coloniaIdentificada(''), isNull);
      expect(servicio.coloniaIdentificada('   '), isNull);
      expect(servicio.coloniaIdentificada('Acapulco de Juárez'), isNull);
      expect(servicio.coloniaIdentificada(' acapulco de juárez '), isNull);
      expect(servicio.coloniaIdentificada(' Centro '), 'Centro');
    });

    test('conteo por franja horaria, día de la semana y hora pico', () {
      expect(stats.porFranja, {
        FranjaHoraria.madrugada: 1,
        FranjaHoraria.manana: 3,
        FranjaHoraria.tarde: 1,
        FranjaHoraria.noche: 4,
      });
      expect(stats.porDiaSemana, {
        DateTime.monday: 2,
        DateTime.tuesday: 2,
        DateTime.wednesday: 0,
        DateTime.thursday: 1,
        DateTime.friday: 1,
        DateTime.saturday: 2,
        DateTime.sunday: 1,
      });
      expect(stats.horaPico, 22);
    });

    test('tendencia por día en periodos cortos, con ceros incluidos', () {
      expect(stats.granularidad, GranularidadTendencia.dia);
      // Del 13 de octubre al 12 de noviembre, ambos incluidos.
      expect(stats.tendencia, hasLength(31));
      expect(stats.tendencia.first.inicio, DateTime(2026, 10, 13));
      expect(stats.tendencia.last.inicio, DateTime(2026, 11, 12));
      final sabado = stats.tendencia
          .firstWhere((p) => p.inicio == DateTime(2026, 11, 7));
      expect(sabado.conteo, 2);
      expect(
        stats.tendencia.fold<int>(0, (suma, p) => suma + p.conteo),
        stats.total,
      );
    });

    test('tendencia por semana en periodos largos', () {
      final desde90 = hasta.subtract(const Duration(days: 90));
      final s = servicio.calcular(reportes, desde: desde90, hasta: hasta);
      expect(s.granularidad, GranularidadTendencia.semana);
      expect(s.tendencia, hasLength(13)); // 91 días de calendario / 7
      expect(
        s.tendencia[1].inicio.difference(s.tendencia[0].inicio).inDays,
        7,
      );
      expect(
        s.tendencia.fold<int>(0, (suma, p) => suma + p.conteo),
        s.total,
      );
    });

    test('sin reportes regresa todo en cero', () {
      final s = servicio.calcular(const [], desde: desde, hasta: hasta);
      expect(s.total, 0);
      expect(s.cambioPorcentual, isNull);
      expect(s.topColonias, isEmpty);
      expect(s.porTipo, isEmpty);
      expect(s.horaPico, isNull);
      expect(s.porCategoria.values.every((n) => n == 0), isTrue);
      expect(s.tendencia.every((p) => p.conteo == 0), isTrue);
    });
  });

  group('EstadisticasService.generarHallazgos', () {
    test('genera las frases esperadas, ordenadas por relevancia', () {
      final hallazgos =
          servicio.generarHallazgos(reportes, desde: desde, hasta: hasta);
      expect(hallazgos, [
        'En los últimos 30 días se registraron 9 reportes, un 50 % más que '
            'en el periodo anterior (6).',
        'En los últimos 30 días, la colonia Progreso concentró el 80 % de '
            'los reportes delictivos, principalmente de noche.',
        'En los últimos 30 días, Progreso fue la colonia con más reportes: '
            '4 de 9 (44 %).',
        'En los últimos 30 días, el 44 % de los reportes ocurrió de noche.',
        'En los últimos 30 días, el tipo de incidencia con más reportes fue '
            '«Robo» (4 de 9).',
      ]);
    });

    test('no genera frases con menos de 3 reportes de respaldo', () {
      final pocos = [
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 7, 22)),
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 7, 23)),
      ];
      expect(
        servicio.generarHallazgos(pocos, desde: desde, hasta: hasta),
        isEmpty,
      );

      // Con un tercer reporte en otra colonia sigue sin haber 3 que
      // respalden una frase sobre Progreso.
      final dispersos = [
        ...pocos,
        _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Centro',
            DateTime(2026, 11, 3, 10)),
      ];
      final hallazgos =
          servicio.generarHallazgos(dispersos, desde: desde, hasta: hasta);
      expect(hallazgos.where((f) => f.contains('Progreso')), isEmpty);
    });

    test('sin reportes no hay hallazgos', () {
      expect(
        servicio.generarHallazgos(const [], desde: desde, hasta: hasta),
        isEmpty,
      );
    });

    test('la colonia no identificada nunca aparece en una frase', () {
      final sinColonia = [
        for (var i = 0; i < 5; i++)
          _reporte(CategoriaReporte.delictivo, 'robo', 'Acapulco de Juárez',
              DateTime(2026, 11, 7, 18 + i)),
      ];
      final hallazgos =
          servicio.generarHallazgos(sinColonia, desde: desde, hasta: hasta);
      expect(hallazgos, isNotEmpty);
      expect(hallazgos.where((f) => f.contains('colonia')), isEmpty);
      expect(hallazgos.where((f) => f.contains('Acapulco')), isEmpty);
    });

    test('omite "principalmente…" si ninguna franja domina', () {
      final repartidos = [
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 7, 2)),
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 6, 8)),
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 5, 14)),
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 4, 20)),
      ];
      final hallazgos =
          servicio.generarHallazgos(repartidos, desde: desde, hasta: hasta);
      expect(
        hallazgos,
        contains('En los últimos 30 días, la colonia Progreso concentró el '
            '100 % de los reportes delictivos.'),
      );
    });

    test('máximo 5 frases y nunca dice "peligrosa"', () {
      // Datos que disparan 7 candidatos: 2 de colonia por categoría,
      // colonia general, cambio, franja, día de la semana y tipo.
      final muchos = [
        for (final hora in [19, 20, 21, 22, 23])
          _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
              DateTime(2026, 11, 7, hora)), // sábado
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 10, 31, 20)), // sábado
        for (final dia in [DateTime(2026, 11, 9), DateTime(2026, 11, 2), DateTime(2026, 10, 26)])
          _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
              dia.add(const Duration(hours: 9))), // lunes
        for (var i = 0; i < 3; i++)
          _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Costa Azul',
              DateTime(2026, 10, 1 + i, 20)), // periodo anterior
      ];
      final hallazgos =
          servicio.generarHallazgos(muchos, desde: desde, hasta: hasta);
      expect(hallazgos, hasLength(EstadisticasService.maximoHallazgos));
      for (final frase in hallazgos) {
        expect(frase.toLowerCase(), isNot(contains('peligros')));
        expect(frase, startsWith('En los últimos 30 días'));
      }
      expect(
        hallazgos.where((f) => f.contains('con más reportes')),
        isNotEmpty,
      );
    });

    test('la etiqueta del periodo se adapta o se puede reemplazar', () {
      final ayer = hasta.subtract(const Duration(hours: 24));
      final recientes = [
        for (var i = 0; i < 4; i++)
          _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
              DateTime(2026, 11, 11, 19 + i)),
      ];
      final ultimas24h =
          servicio.generarHallazgos(recientes, desde: ayer, hasta: hasta);
      expect(ultimas24h, isNotEmpty);
      expect(ultimas24h.first, startsWith('En las últimas 24 horas'));

      final conEtiqueta = servicio.generarHallazgos(
        recientes,
        desde: ayer,
        hasta: hasta,
        etiquetaPeriodo: 'Ayer',
      );
      expect(conEtiqueta.first, startsWith('Ayer'));
    });
  });
}
