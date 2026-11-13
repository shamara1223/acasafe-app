// Tests del contenido del panel "Resumen reciente". Se prueba
// ResumenRecienteContenido, que recibe los reportes ya descargados y no
// depende de Firebase.

import 'package:acasafe/models/reporte.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:acasafe/widgets/resumen_reciente.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Reporte _reporte(
  CategoriaReporte categoria,
  String tipo,
  String colonia,
  DateTime fechaHora,
) {
  return Reporte(
    tipo: tipo,
    categoria: categoria,
    colonia: colonia,
    ubicacion: const GeoPoint(acapulcoLat, acapulcoLng),
    descripcion: 'Prueba',
    fechaHora: fechaHora,
    usuarioId: 'test',
  );
}

void main() {
  final ahora = DateTime(2026, 11, 12, 12);

  setUpAll(() => initializeDateFormatting());

  Future<void> mostrar(
    WidgetTester tester,
    List<Reporte> reportes, {
    ValueChanged<Reporte>? onAbrirReporte,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResumenRecienteContenido(
              reportes: reportes,
              ahora: ahora,
              onAbrirReporte: onAbrirReporte ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra total, categoría, colonia, recientes y hallazgos',
      (tester) async {
    Reporte? abierto;
    final reportes = [
      for (final hora in [19, 20, 21, 22])
        _reporte(CategoriaReporte.delictivo, 'robo', 'Progreso',
            DateTime(2026, 11, 10, hora)),
      _reporte(CategoriaReporte.infraestructura, 'bache', 'Centro',
          DateTime(2026, 11, 11, 9)),
      // Más viejo que 7 días: no cuenta.
      _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Costa Azul',
          DateTime(2026, 10, 20, 20)),
    ];
    await mostrar(tester, reportes, onAbrirReporte: (r) => abierto = r);

    expect(find.text('5'), findsOneWidget);
    expect(find.text('reportes en los últimos 7 días'), findsOneWidget);
    expect(find.text('Categoría más reportada'), findsOneWidget);
    expect(find.text('Delictivo'), findsOneWidget);
    expect(find.text('Colonia con más reportes'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);

    // Solo los 3 más recientes, del más nuevo al más viejo.
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Bache'), findsOneWidget);
    expect(find.text('Robo'), findsNWidgets(2));

    // Máximo 2 hallazgos.
    expect(find.byIcon(Icons.lightbulb_outline), findsNWidgets(2));
    expect(
      find.text('Basado en reportes ciudadanos; no son cifras oficiales.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Bache'));
    expect(abierto?.tipo, 'bache');
  });

  testWidgets('sin reportes recientes muestra el aviso y la nota',
      (tester) async {
    await mostrar(tester, [
      _reporte(CategoriaReporte.social, 'ruido_excesivo', 'Costa Azul',
          DateTime(2026, 10, 20, 20)),
    ]);

    expect(find.text('No hay reportes en los últimos 7 días.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(
      find.text('Basado en reportes ciudadanos; no son cifras oficiales.'),
      findsOneWidget,
    );
  });

  testWidgets('con pocos reportes no inventa colonia ni hallazgos',
      (tester) async {
    await mostrar(tester, [
      _reporte(CategoriaReporte.ambiental, 'basura_acumulada',
          'Acapulco de Juárez', DateTime(2026, 11, 11, 9)),
    ]);

    expect(find.text('reporte en los últimos 7 días'), findsOneWidget);
    expect(find.text('Sin colonia identificada'), findsOneWidget);
    expect(find.textContaining('Colonia no identificada'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
  });
}
