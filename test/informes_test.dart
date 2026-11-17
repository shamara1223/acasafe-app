// Tests de la sección Informes del administrador: el configurador
// (InformesContenido, sin Firebase) y la generación del PDF con
// PdfService, con datos de prueba y con un periodo vacío.

import 'dart:convert';
import 'dart:typed_data';

import 'package:acasafe/models/opciones_informe.dart';
import 'package:acasafe/models/periodo_estadisticas.dart';
import 'package:acasafe/models/reporte.dart';
import 'package:acasafe/screens/admin/informes_screen.dart';
import 'package:acasafe/services/pdf_service.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Reporte _reporte(
  CategoriaReporte categoria,
  String tipo,
  String colonia,
  DateTime fechaHora, {
  EstadoReporte estado = EstadoReporte.pendiente,
  String descripcion = 'Prueba con acentos: árbol, señal, pingüino',
}) {
  return Reporte(
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
  TestWidgetsFlutterBinding.ensureInitialized();

  final ahora = DateTime(2026, 11, 12, 12);

  // En los últimos 30 días: 6 reportes + 1 falso. En los últimos 7: 5.
  final reportes = [
    _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
        DateTime(2026, 11, 11, 9)),
    for (final hora in [19, 20, 21, 22])
      _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
          DateTime(2026, 11, 7, hora),
          estado: EstadoReporte.verificado),
    _reporte(CategoriaReporte.riesgoNatural, 'inundacion', 'Costa Azul',
        DateTime(2026, 11, 3, 15),
        estado: EstadoReporte.resuelto),
    _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Acapulco de Juárez',
        DateTime(2026, 10, 20, 23),
        estado: EstadoReporte.falso),
    _reporte(CategoriaReporte.ambiental, 'basura_acumulada', 'Progreso',
        DateTime(2026, 6, 1, 8)),
  ];

  late FuentesInforme fuentes;

  setUpAll(() async {
    await initializeDateFormatting();
    // Las fuentes salen de los assets declarados en pubspec.yaml.
    fuentes = await FuentesInforme.cargar();
  });

  group('OpcionesInforme y DatosInforme', () {
    test('por defecto: 30 días, todas las categorías y secciones, sin falsos',
        () {
      final opciones = OpcionesInforme();
      expect(opciones.periodo.tipo, TipoPeriodo.ultimos30);
      expect(opciones.todasLasCategorias, isTrue);
      expect(opciones.secciones, SeccionInforme.values.toSet());
      expect(opciones.incluirFalsos, isFalse);
      expect(opciones.tituloFinal, OpcionesInforme.tituloPorDefecto);
    });

    test('cuenta solo los reportes del periodo que cumplen los filtros', () {
      int total(OpcionesInforme o) =>
          DatosInforme.calcular(reportes, o, ahora: ahora).total;

      expect(total(OpcionesInforme()), 6);
      expect(total(OpcionesInforme(incluirFalsos: true)), 7);
      expect(
        total(OpcionesInforme(
          periodo: const PeriodoEstadisticas(TipoPeriodo.ultimos7),
        )),
        5,
      );
      expect(
        total(OpcionesInforme(categorias: {CategoriaReporte.delictivo})),
        4,
      );
      expect(total(OpcionesInforme(categorias: {})), 0);
      expect(
        total(OpcionesInforme(
          periodo: const PeriodoEstadisticas(TipoPeriodo.todo),
        )),
        7,
      );
    });

    test('la tabla detallada va del más reciente al más antiguo', () {
      final datos = DatosInforme.calcular(reportes, OpcionesInforme(),
          ahora: ahora);
      final fechas = datos.reportes.map((r) => r.fechaHora).toList();
      final ordenadas = [...fechas]..sort((a, b) => b.compareTo(a));
      expect(fechas, ordenadas);
    });
  });

  group('PdfService', () {
    const servicio = PdfService();

    Future<Uint8List> generar(OpcionesInforme opciones, List<Reporte> datos) {
      return servicio.generar(
        DatosInforme.calcular(datos, opciones, ahora: ahora),
        correoAdmin: 'admin@acasafe.mx',
        generadoEl: ahora,
        fuentes: fuentes,
      );
    }

    void esPdf(Uint8List bytes) {
      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      // La fuente Roboto va incrustada (para acentos y ñ).
      expect(latin1.decode(bytes).contains('Roboto'), isTrue);
    }

    test('nombre del archivo con la fecha', () {
      expect(
        PdfService.nombreArchivo(DateTime(2026, 11, 16, 18, 30)),
        'acasafe_informe_2026-11-16.pdf',
      );
    });

    test('genera el PDF con todas las secciones y datos de prueba', () async {
      esPdf(await generar(
        OpcionesInforme(titulo: 'Informe de señalización y baches'),
        reportes,
      ));
    });

    test('genera el PDF con solo algunas secciones y falsos incluidos',
        () async {
      esPdf(await generar(
        OpcionesInforme(
          incluirFalsos: true,
          categorias: {CategoriaReporte.delictivo, CategoriaReporte.social},
          secciones: {SeccionInforme.resumen, SeccionInforme.tabla},
        ),
        reportes,
      ));
    });

    test('genera el PDF con un periodo vacío', () async {
      final opciones = OpcionesInforme(
        periodo: PeriodoEstadisticas.personalizado(
          DateTime(2025, 1, 1),
          DateTime(2025, 1, 31),
        ),
      );
      expect(DatosInforme.calcular(reportes, opciones, ahora: ahora).total, 0);
      esPdf(await generar(opciones, reportes));
      // Y también sin ningún reporte en el sistema.
      esPdf(await generar(OpcionesInforme(), const []));
    });

    test('genera el PDF de un solo día (gráfica de una sola barra)', () async {
      esPdf(await generar(
        OpcionesInforme(
          periodo: PeriodoEstadisticas.personalizado(
            DateTime(2026, 11, 11),
            DateTime(2026, 11, 11),
          ),
        ),
        reportes,
      ));
    });

    test('la tabla detallada se reparte en varias páginas', () async {
      final muchos = [
        for (var i = 0; i < 400; i++)
          _reporte(
            CategoriaReporte.values[i % CategoriaReporte.values.length],
            'bache',
            'Colonia ${i % 15}',
            ahora.subtract(Duration(hours: i * 2 + 1)),
            descripcion: 'Descripción larga número $i. ' * 10,
          ),
      ];
      final bytes = await generar(
        OpcionesInforme(
          periodo: const PeriodoEstadisticas(TipoPeriodo.ultimos90),
        ),
        muchos,
      );
      esPdf(bytes);
      final paginas =
          RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(bytes)).length;
      expect(paginas, greaterThan(3));
    });
  });

  group('InformesContenido (configurador)', () {
    Finder boton(String texto) => find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );

    bool habilitado(WidgetTester tester, String texto) =>
        tester.widget<ButtonStyleButton>(boton(texto).first).onPressed != null;

    String conteo(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('conteo-informe')))
        .data!;

    Widget app({
      PeriodoEstadisticas? periodo,
      int version = 0,
      List<Reporte>? datos,
      GenerarPdf? generarPdf,
      DescargarPdf? descargarPdf,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: InformesContenido(
            reportes: datos ?? reportes,
            correoAdmin: 'admin@acasafe.mx',
            periodoInicial: periodo,
            versionPeriodo: version,
            ahora: ahora,
            generarPdf: generarPdf ?? (_) async => Uint8List(10),
            descargarPdf: descargarPdf ?? (_, __) async {},
          ),
        ),
      );
    }

    Future<void> mostrar(
      WidgetTester tester,
      Widget widget, {
      Size pantalla = const Size(400, 900),
    }) async {
      tester.view.physicalSize = pantalla;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    // Un desbordamiento de layout hace fallar el test, así que estos dos
    // casos comprueban que el configurador cabe en cada tamaño.
    testWidgets('se dibuja en celular y en pantalla ancha', (tester) async {
      await mostrar(tester, app());
      expect(find.text('1. Periodo'), findsOneWidget);
      for (final s in SeccionInforme.values) {
        expect(find.text(s.titulo), findsOneWidget);
      }
      expect(conteo(tester), '6');
      expect(habilitado(tester, 'Descargar PDF'), isTrue);
      expect(habilitado(tester, 'Vista previa'), isTrue);

      await mostrar(tester, app(), pantalla: const Size(1400, 900));
      // En pantalla ancha el resumen va a la derecha del formulario.
      expect(
        tester.getTopLeft(find.text('Generar')).dx,
        greaterThan(tester.getTopLeft(find.text('1. Periodo')).dx),
      );
    });

    testWidgets('usa el periodo que manda el Panel y lo actualiza',
        (tester) async {
      await mostrar(
        tester,
        app(periodo: const PeriodoEstadisticas(TipoPeriodo.ultimos7)),
      );
      expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Últimos 7 días'))
            .selected,
        isTrue,
      );
      expect(conteo(tester), '5');

      // El Panel manda otro periodo.
      await mostrar(
        tester,
        app(
          periodo: const PeriodoEstadisticas(TipoPeriodo.todo),
          version: 1,
        ),
      );
      expect(conteo(tester), '7');
    });

    testWidgets('los filtros cambian el conteo', (tester) async {
      await mostrar(tester, app());

      await tester.ensureVisible(
          find.text('Incluir reportes marcados como falsos'));
      await tester.tap(find.text('Incluir reportes marcados como falsos'));
      await tester.pumpAndSettle();
      expect(conteo(tester), '7');

      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Delictivo'));
      await tester.tap(find.widgetWithText(FilterChip, 'Delictivo'));
      await tester.pumpAndSettle();
      expect(conteo(tester), '3');
    });

    testWidgets('con 0 reportes o sin secciones deshabilita los botones',
        (tester) async {
      await mostrar(tester, app());

      // Sin categorías no cumple ningún reporte.
      await tester.tap(boton('Ninguna').first);
      await tester.pumpAndSettle();
      expect(conteo(tester), '0');
      expect(find.text('Elige al menos una categoría.'), findsOneWidget);
      expect(habilitado(tester, 'Descargar PDF'), isFalse);
      expect(habilitado(tester, 'Vista previa'), isFalse);

      await tester.tap(boton('Todas').first);
      await tester.pumpAndSettle();
      expect(habilitado(tester, 'Descargar PDF'), isTrue);

      // Sin secciones tampoco se puede generar.
      await tester.ensureVisible(boton('Ninguna').last);
      await tester.tap(boton('Ninguna').last);
      await tester.pumpAndSettle();
      expect(find.text('Elige al menos una sección.'), findsOneWidget);
      expect(habilitado(tester, 'Descargar PDF'), isFalse);
    });

    testWidgets('un periodo sin reportes avisa y deshabilita', (tester) async {
      await mostrar(
        tester,
        app(
          periodo: PeriodoEstadisticas.personalizado(
            DateTime(2025, 1, 1),
            DateTime(2025, 1, 31),
          ),
        ),
      );
      expect(conteo(tester), '0');
      expect(find.textContaining('Ningún reporte cumple'), findsOneWidget);
      expect(habilitado(tester, 'Descargar PDF'), isFalse);
    });

    testWidgets('"Descargar PDF" genera y descarga con el nombre del día',
        (tester) async {
      DatosInforme? generado;
      String? nombre;
      var generaciones = 0;
      await mostrar(
        tester,
        app(
          generarPdf: (datos) async {
            generado = datos;
            generaciones++;
            return Uint8List.fromList(utf8.encode('%PDF-prueba'));
          },
          descargarPdf: (bytes, n) async => nombre = n,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Informe de noviembre');
      await tester.pumpAndSettle();
      await tester.ensureVisible(boton('Descargar PDF'));
      await tester.tap(boton('Descargar PDF'));
      await tester.pumpAndSettle();

      expect(nombre, 'acasafe_informe_2026-11-12.pdf');
      expect(generado!.total, 6);
      expect(generado!.opciones.tituloFinal, 'Informe de noviembre');

      // Sin cambios, la segunda descarga reutiliza el mismo PDF.
      await tester.tap(boton('Descargar PDF'));
      await tester.pumpAndSettle();
      expect(generaciones, 1);
    });

    testWidgets('si falla la generación muestra el error', (tester) async {
      var descargas = 0;
      await mostrar(
        tester,
        app(
          generarPdf: (_) async => throw Exception('fallo'),
          descargarPdf: (_, __) async => descargas++,
        ),
      );
      await tester.ensureVisible(boton('Descargar PDF'));
      await tester.tap(boton('Descargar PDF'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo generar el PDF. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(descargas, 0);
      expect(habilitado(tester, 'Descargar PDF'), isTrue);
    });
  });
}
