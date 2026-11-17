// Tests de las secciones Panel y Reportes del administrador. Se prueban
// los widgets de contenido (PanelContenido, ReportesAdminContenido), que
// reciben los reportes ya descargados y no dependen de Firebase.

import 'package:acasafe/models/periodo_estadisticas.dart';
import 'package:acasafe/models/reporte.dart';
import 'package:acasafe/screens/admin/panel_screen.dart';
import 'package:acasafe/screens/admin/reportes_admin_screen.dart';
import 'package:acasafe/services/estadisticas_service.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:acasafe/utils/filtros_reportes_admin.dart';
import 'package:acasafe/widgets/etiqueta_estado.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Reporte _reporte(
  CategoriaReporte categoria,
  String tipo,
  String colonia,
  DateTime fechaHora, {
  EstadoReporte estado = EstadoReporte.pendiente,
  String descripcion = 'Prueba',
  String? id,
}) {
  return Reporte(
    id: id,
    tipo: tipo,
    categoria: categoria,
    colonia: colonia,
    ubicacion: const GeoPoint(acapulcoLat, acapulcoLng),
    descripcion: descripcion,
    fechaHora: fechaHora,
    estado: estado,
    usuarioId: 'usuario-1',
  );
}

void main() {
  final ahora = DateTime(2026, 11, 12, 12);

  // Del más reciente al más antiguo, como llegan de Firestore.
  final reportes = [
    _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
        DateTime(2026, 11, 11, 9),
        id: 'r1', descripcion: 'Bache enorme frente al mercado'),
    for (final hora in [19, 20, 21, 22])
      _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
          DateTime(2026, 11, 7, hora),
          id: 'robo-$hora', estado: EstadoReporte.verificado),
    _reporte(CategoriaReporte.riesgoNatural, 'inundacion', 'Costa Azul',
        DateTime(2026, 11, 3, 15),
        id: 'r6', descripcion: 'Calle inundada', estado: EstadoReporte.resuelto),
    _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Acapulco de Juárez',
        DateTime(2026, 10, 20, 23),
        id: 'r7', estado: EstadoReporte.falso),
    _reporte(CategoriaReporte.ambiental, 'basura_acumulada', 'Progreso',
        DateTime(2026, 6, 1, 8),
        id: 'r8'),
  ];

  setUpAll(() => initializeDateFormatting());

  group('PeriodoEstadisticas', () {
    test('los periodos de N días terminan ahora', () {
      final rango =
          const PeriodoEstadisticas(TipoPeriodo.ultimos30).rango(ahora);
      expect(rango.hasta, ahora);
      expect(rango.desde, ahora.subtract(const Duration(days: 30)));
      expect(
        const PeriodoEstadisticas(TipoPeriodo.ultimos30).etiquetaFrase,
        isNull,
      );
    });

    test('todo el historial empieza el día del primer reporte', () {
      const periodo = PeriodoEstadisticas(TipoPeriodo.todo);
      final rango = periodo.rango(
        ahora,
        primerReporte: DateTime(2026, 6, 1, 8),
        ultimoReporte: DateTime(2026, 11, 11, 9),
      );
      expect(rango.desde, DateTime(2026, 6, 1));
      expect(rango.hasta, ahora);
      expect(periodo.etiquetaFrase, 'En todo el historial');

      // Un reporte fechado después de "ahora" también entra.
      final futuro = DateTime(2026, 11, 12, 13);
      final extendido = periodo.rango(ahora, ultimoReporte: futuro);
      expect(extendido.hasta.isAfter(futuro), isTrue);
    });

    test('el rango personalizado incluye completo el último día', () {
      final periodo = PeriodoEstadisticas.personalizado(
        DateTime(2026, 10, 1, 17),
        DateTime(2026, 10, 15),
      );
      final rango = periodo.rango(ahora);
      expect(rango.desde, DateTime(2026, 10, 1));
      expect(rango.hasta, DateTime(2026, 10, 16));
      expect(periodo.etiquetaFrase, startsWith('Del 1 oct'));
      expect(periodo.nombre, contains('–'));
    });
  });

  test('topColonias trae el desglose por categoría', () {
    final stats = const EstadisticasService().calcular(
      reportes,
      desde: DateTime(2026, 1, 1),
      hasta: ahora,
      limiteColonias: 10,
    );
    final progreso = stats.topColonias.first;
    expect(progreso.colonia, 'Progreso');
    expect(progreso.conteo, 5);
    expect(progreso.porCategoria, {
      CategoriaReporte.delictivo: 4,
      CategoriaReporte.ambiental: 1,
    });
    // En los rankings por categoría no hace falta el desglose.
    expect(
      stats.topColoniasPorCategoria[CategoriaReporte.delictivo]!.first
          .porCategoria,
      isEmpty,
    );
  });

  group('FiltrosReportesAdmin', () {
    test('sin filtros regresa todo', () {
      const filtros = FiltrosReportesAdmin();
      expect(filtros.estaActivo, isFalse);
      expect(filtros.aplicar(reportes), hasLength(reportes.length));
    });

    test('busca en tipo, colonia y descripción, sin acentos ni mayúsculas',
        () {
      List<Reporte> buscar(String texto) =>
          FiltrosReportesAdmin(texto: texto).aplicar(reportes);

      expect(buscar('ROBO'), hasLength(4)); // tipo
      expect(buscar('inundacion'), hasLength(1)); // nombre con acento
      expect(buscar('costa azul'), hasLength(1)); // colonia
      expect(buscar('mercado'), hasLength(1)); // descripción
      expect(buscar('ruido_excesivo'), hasLength(1)); // clave del tipo
      expect(buscar('bache centro'), hasLength(1)); // varias palabras
      expect(buscar('bache progreso'), isEmpty);
      expect(buscar('   '), hasLength(reportes.length));
    });

    test('filtra por categoría, estado y fechas', () {
      expect(
        const FiltrosReportesAdmin(categoria: CategoriaReporte.delictivo)
            .aplicar(reportes),
        hasLength(4),
      );
      expect(
        const FiltrosReportesAdmin(estado: EstadoReporte.pendiente)
            .aplicar(reportes),
        hasLength(2),
      );
      // Ambos días del rango cuentan completos.
      final porFechas = FiltrosReportesAdmin(
        primerDia: DateTime(2026, 11, 3),
        ultimoDia: DateTime(2026, 11, 7),
      );
      expect(porFechas.estaActivo, isTrue);
      expect(porFechas.aplicar(reportes), hasLength(5));
      // Los filtros se combinan.
      expect(
        const FiltrosReportesAdmin(
          texto: 'progreso',
          estado: EstadoReporte.pendiente,
        ).aplicar(reportes),
        hasLength(1),
      );
    });
  });

  group('PanelContenido', () {
    // Busca un valor dentro de la tarjeta del indicador con esa
    // etiqueta (los mismos números salen también en los ejes de las
    // gráficas).
    Finder enIndicador(String etiqueta, String valor) {
      return find.descendant(
        of: find.widgetWithText(Card, etiqueta),
        matching: find.text(valor),
      );
    }

    Future<void> mostrar(
      WidgetTester tester,
      Size pantalla, {
      ValueChanged<PeriodoEstadisticas>? onGenerarInforme,
    }) async {
      tester.view.physicalSize = pantalla;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanelContenido(
              reportes: reportes,
              ahora: ahora,
              onGenerarInforme: onGenerarInforme ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Un desbordamiento de layout hace fallar el test, así que estos dos
    // casos también comprueban que el panel cabe en cada tamaño.
    testWidgets('se dibuja en celular (una columna)', (tester) async {
      await mostrar(tester, const Size(390, 844));

      expect(find.text('Total de reportes'), findsOneWidget);
      // Últimos 30 días: 7 reportes; pendientes en todo el sistema: 2.
      expect(enIndicador('Total de reportes', '7'), findsOneWidget);
      expect(enIndicador('Pendientes de moderar', '2'), findsOneWidget);
      expect(find.text('Hallazgos automáticos'), findsOneWidget);

      // Las gráficas están más abajo, dentro del scroll.
      await tester.scrollUntilVisible(find.text('Top 10 colonias'), 300);
      expect(find.byType(BarChart, skipOffstage: false), findsNWidgets(3));
      expect(find.byType(LineChart, skipOffstage: false), findsOneWidget);
      expect(find.byType(PieChart, skipOffstage: false), findsOneWidget);
    });

    testWidgets('se dibuja en pantalla ancha (varias columnas)',
        (tester) async {
      await mostrar(tester, const Size(1400, 900));

      // Los 5 indicadores caben en una sola fila.
      final total = tester.getTopLeft(find.text('Total de reportes'));
      final franja =
          tester.getTopLeft(find.text('Franja horaria con más reportes'));
      expect(franja.dy, total.dy);
      expect(franja.dx, greaterThan(total.dx));
      expect(find.text('Delictivo'), findsOneWidget); // categoría top
    });

    testWidgets('cambiar de periodo recalcula los indicadores',
        (tester) async {
      await mostrar(tester, const Size(1400, 900));

      await tester.tap(find.text('Últimos 7 días'));
      await tester.pumpAndSettle();
      expect(enIndicador('Total de reportes', '5'), findsOneWidget);

      await tester.tap(find.text('Todo el historial'));
      await tester.pumpAndSettle();
      expect(enIndicador('Total de reportes', '8'), findsOneWidget);
      expect(find.text('Reportes por semana'), findsOneWidget);
    });

    testWidgets('un periodo sin reportes muestra el estado vacío',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanelContenido(
              reportes: [reportes.last], // solo el de junio
              ahora: ahora,
              onGenerarInforme: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No hay reportes en este periodo'),
          findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
      // El pendiente sigue contando: es de todo el sistema.
      expect(enIndicador('Total de reportes', '0'), findsOneWidget);
      expect(enIndicador('Pendientes de moderar', '1'), findsOneWidget);
    });

    testWidgets('"Generar informe PDF" manda el periodo elegido',
        (tester) async {
      PeriodoEstadisticas? enviado;
      await mostrar(
        tester,
        const Size(1400, 900),
        onGenerarInforme: (p) => enviado = p,
      );

      await tester.tap(find.text('Últimos 90 días'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar informe PDF'));

      expect(enviado?.tipo, TipoPeriodo.ultimos90);
    });
  });

  group('ReportesAdminContenido', () {
    Future<void> mostrar(
      WidgetTester tester,
      Size pantalla, {
      CambiarEstado? onCambiarEstado,
    }) async {
      tester.view.physicalSize = pantalla;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportesAdminContenido(
              reportes: reportes,
              onCambiarEstado: onCambiarEstado ?? (_, __) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('una columna en celular y varias en pantalla ancha',
        (tester) async {
      await mostrar(tester, const Size(390, 844));
      expect(find.text('8 reportes'), findsOneWidget);
      expect(find.byType(EtiquetaEstado), findsWidgets);
      final enCelular = tester.getTopLeft(find.text('Bache'));
      final segundoEnCelular = tester.getTopLeft(find.text('Robo').first);
      expect(segundoEnCelular.dy, greaterThan(enCelular.dy));

      await mostrar(tester, const Size(1400, 900));
      final enAncho = tester.getTopLeft(find.text('Bache'));
      final segundoEnAncho = tester.getTopLeft(find.text('Robo').first);
      expect(segundoEnAncho.dy, enAncho.dy);
    });

    testWidgets('la búsqueda filtra y avisa cuando no hay resultados',
        (tester) async {
      await mostrar(tester, const Size(1400, 900));

      await tester.enterText(find.byType(TextField), 'inundación');
      await tester.pumpAndSettle();
      expect(find.text('1 de 8 reportes'), findsOneWidget);
      expect(find.text('Inundación'), findsOneWidget);
      expect(find.text('Bache'), findsNothing);

      await tester.enterText(find.byType(TextField), 'no existe');
      await tester.pumpAndSettle();
      expect(find.textContaining('Ningún reporte coincide'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('8 reportes'), findsOneWidget);
    });

    testWidgets('cambiar el estado pide confirmación y guarda',
        (tester) async {
      Reporte? cambiado;
      EstadoReporte? nuevoEstado;
      await mostrar(
        tester,
        const Size(390, 844),
        onCambiarEstado: (r, e) async {
          cambiado = r;
          nuevoEstado = e;
        },
      );

      await tester.tap(find.text('Bache'));
      await tester.pumpAndSettle();
      expect(find.text('Bache enorme frente al mercado'), findsOneWidget);
      expect(find.text('ID del reporte'), findsOneWidget);

      // Cancelar no guarda nada.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Verificado'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cambiar el estado?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(cambiado, isNull);

      // Confirmar sí guarda.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Verificado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar estado').last);
      await tester.pumpAndSettle();

      expect(cambiado?.id, 'r1');
      expect(nuevoEstado, EstadoReporte.verificado);
      expect(find.text('Estado cambiado a Verificado.'), findsOneWidget);
      final etiqueta =
          tester.widget<EtiquetaEstado>(find.byType(EtiquetaEstado));
      expect(etiqueta.estado, EstadoReporte.verificado);
    });

    testWidgets('si falla el guardado, avisa y conserva el estado',
        (tester) async {
      await mostrar(
        tester,
        const Size(390, 844),
        onCambiarEstado: (_, __) async => throw Exception('permission-denied'),
      );

      await tester.tap(find.text('Bache'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Falso'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dejará de mostrarse en el mapa'),
          findsOneWidget);
      await tester.tap(find.text('Cambiar estado').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo cambiar el estado'),
          findsOneWidget);
      final etiqueta =
          tester.widget<EtiquetaEstado>(find.byType(EtiquetaEstado));
      expect(etiqueta.estado, EstadoReporte.pendiente);
    });
  });
}
