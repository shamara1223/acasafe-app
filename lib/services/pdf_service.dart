import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/estadisticas_reportes.dart';
import '../models/opciones_informe.dart';
import '../models/periodo_estadisticas.dart';
import '../models/reporte.dart';
import '../utils/constants.dart';
import '../utils/filtros_reporte.dart';

/// Fuente Roboto (normal y negrita) para el PDF. Va como asset del
/// proyecto: las fuentes estándar de PDF no traen acentos ni ñ, y así no
/// hay que descargarla en cada generación.
class FuentesInforme {
  final pw.Font normal;
  final pw.Font negrita;

  const FuentesInforme(this.normal, this.negrita);

  static FuentesInforme? _cargadas;

  /// Lee las fuentes de los assets una sola vez por sesión. Un pw.Font
  /// se puede reutilizar en varios documentos.
  static Future<FuentesInforme> cargar() async {
    final previas = _cargadas;
    if (previas != null) return previas;
    final normal = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final negrita = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _cargadas = FuentesInforme(pw.Font.ttf(normal), pw.Font.ttf(negrita));
  }
}

/// Arma el informe PDF a partir de [DatosInforme] (que ya trae las
/// estadísticas calculadas con EstadisticasService). Funciona igual en
/// web y en móvil: el paquete pdf es Dart puro.
class PdfService {
  const PdfService();

  /// Tope de renglones de la tabla detallada, para que un historial muy
  /// grande no genere un PDF de cientos de páginas.
  static const maximoFilasTabla = 1000;

  static const _marca = PdfColor.fromInt(0xFF00796B); // teal 700
  static const _marcaSuave = PdfColor.fromInt(0xFFE0F2F1); // teal 50
  static const _gris = PdfColors.grey700;
  static const _grisClaro = PdfColors.grey300;

  /// acasafe_informe_2026-11-16.pdf
  static String nombreArchivo(DateTime fecha) =>
      'acasafe_informe_${DateFormat('yyyy-MM-dd').format(fecha)}.pdf';

  /// Genera el PDF. [fuentes] es para tests; si es null se cargan de los
  /// assets.
  Future<Uint8List> generar(
    DatosInforme datos, {
    required String correoAdmin,
    required DateTime generadoEl,
    FuentesInforme? fuentes,
  }) async {
    final f = fuentes ?? await FuentesInforme.cargar();
    final opciones = datos.opciones;

    final doc = pw.Document(
      title: opciones.tituloFinal,
      author: correoAdmin,
      creator: 'AcaSafe',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
          theme: _tema(f),
        ),
        maxPages: 1000,
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  'AcaSafe · ${opciones.tituloFinal}',
                  style: const pw.TextStyle(fontSize: 8, color: _gris),
                ),
              ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'AcaSafe · Generado el ${_fechaHora(generadoEl)}',
                style: const pw.TextStyle(fontSize: 8, color: _gris),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _gris),
              ),
            ],
          ),
        ),
        build: (context) => [
          _encabezado(datos, correoAdmin, generadoEl),
          if (datos.total == 0)
            _seccion('Sin reportes', [
              pw.Text(
                'No hay reportes que cumplan los criterios en este periodo. '
                'Prueba con un periodo más amplio u otras categorías.',
              ),
            ])
          else
            for (final s in SeccionInforme.values)
              if (opciones.secciones.contains(s)) ..._contenido(s, datos),
          _notaMetodologica(datos),
        ],
      ),
    );

    return doc.save();
  }

  static pw.ThemeData _tema(FuentesInforme f) {
    final tema = pw.ThemeData.withFont(base: f.normal, bold: f.negrita);
    return tema.copyWith(
      defaultTextStyle: tema.defaultTextStyle.copyWith(fontSize: 10),
    );
  }

  // -------------------------------------------------------------------
  // Encabezado y nota
  // -------------------------------------------------------------------

  pw.Widget _encabezado(
    DatosInforme datos,
    String correoAdmin,
    DateTime generadoEl,
  ) {
    final opciones = datos.opciones;
    final categorias = opciones.todasLasCategorias
        ? 'Todas'
        : (opciones.categorias.toList()..sort((a, b) => a.index - b.index))
            .map((c) => infoCategoria[c]!.nombre)
            .join(', ');

    pw.TableRow fila(String etiqueta, String valor) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                etiqueta,
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(valor),
            ),
          ],
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AcaSafe',
          style: const pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _marca,
          ),
        ),
        pw.Text(
          'Reportes ciudadanos de Acapulco de Juárez',
          style: const pw.TextStyle(fontSize: 9, color: _gris),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          opciones.tituloFinal,
          style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _marcaSuave,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(150),
              1: pw.FlexColumnWidth(),
            },
            children: [
              fila('Periodo', '${opciones.periodo.nombre} '
                  '(${_rangoTexto(datos.rango)})'),
              fila('Fecha de generación', _fechaHora(generadoEl)),
              fila('Generado por', correoAdmin),
              fila('Categorías', categorias),
              fila(
                'Reportes falsos',
                opciones.incluirFalsos ? 'Incluidos' : 'Excluidos',
              ),
              fila('Reportes que cumplen', '${datos.total}'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _notaMetodologica(DatosInforme datos) {
    final stats = datos.stats;
    final puntos = [
      'Los datos provienen de reportes enviados por la ciudadanía a través '
          'de AcaSafe. No son cifras oficiales y no todos los reportes han '
          'sido verificados.',
      'Los reportes sin colonia identificada no se incluyen en los '
          'rankings de colonias'
          '${stats.sinColonia > 0 ? ' (${_reportes(stats.sinColonia)} en este periodo)' : ''}.',
      'Un mayor número de reportes en una zona no implica necesariamente '
          'mayor riesgo: también puede reflejar mayor participación.',
      'El porcentaje de cambio compara contra el periodo anterior del mismo '
          'largo, con los mismos filtros.',
      datos.opciones.incluirFalsos
          ? 'Se incluyen los reportes que un administrador marcó como falsos.'
          : 'Se excluyen los reportes que un administrador marcó como falsos.',
    ];
    return _seccion('Nota metodológica', [
      for (final p in puntos) _vineta(p, tamano: 9),
    ]);
  }

  // -------------------------------------------------------------------
  // Secciones
  // -------------------------------------------------------------------

  List<pw.Widget> _contenido(SeccionInforme seccion, DatosInforme datos) {
    final stats = datos.stats;
    switch (seccion) {
      case SeccionInforme.resumen:
        return [_seccion(seccion.titulo, _resumen(datos))];
      case SeccionInforme.categorias:
        return [
          _seccion(seccion.titulo, [
            _grafica([
              for (final c in CategoriaReporte.values)
                _Barra(
                  infoCategoria[c]!.nombre,
                  stats.porCategoria[c]!,
                  _colorCategoria(c),
                ),
            ]),
            pw.SizedBox(height: 8),
            _tabla(
              ['Categoría', 'Reportes', '%'],
              [
                for (final c in _categoriasOrdenadas(stats))
                  [
                    infoCategoria[c]!.nombre,
                    '${stats.porCategoria[c]}',
                    _pct(stats.porCategoria[c]!, stats.total),
                  ],
              ],
              numericas: {1, 2},
            ),
          ]),
        ];
      case SeccionInforme.tipos:
        final tipos = stats.porTipo.entries.take(10).toList();
        return [
          _seccion(seccion.titulo, [
            _subtitulo('Los ${tipos.length} tipos con más reportes'),
            _tabla(
              ['#', 'Tipo', 'Categoría', 'Reportes', '%'],
              [
                for (var i = 0; i < tipos.length; i++)
                  [
                    '${i + 1}',
                    nombreTipoReporte[tipos[i].key] ?? tipos[i].key,
                    _categoriaDeTipo(tipos[i].key),
                    '${tipos[i].value}',
                    _pct(tipos[i].value, stats.total),
                  ],
              ],
              numericas: {0, 3, 4},
            ),
          ]),
        ];
      case SeccionInforme.colonias:
        return [_seccion(seccion.titulo, _colonias(stats))];
      case SeccionInforme.horario:
        return [_seccion(seccion.titulo, _horario(stats))];
      case SeccionInforme.tendencia:
        return [_seccion(seccion.titulo, _tendencia(stats))];
      case SeccionInforme.moderacion:
        return [
          _seccion(seccion.titulo, [
            _grafica([
              for (final e in EstadoReporte.values)
                _Barra(
                  infoEstado[e]!.nombre,
                  stats.porEstado[e]!,
                  _pdfColor(infoEstado[e]!.color.toARGB32()),
                ),
            ]),
            pw.SizedBox(height: 8),
            _tabla(
              ['Estado', 'Reportes', '%'],
              [
                for (final e in EstadoReporte.values)
                  [
                    infoEstado[e]!.nombre,
                    '${stats.porEstado[e]}',
                    _pct(stats.porEstado[e]!, stats.total),
                  ],
              ],
              numericas: {1, 2},
            ),
          ]),
        ];
      case SeccionInforme.hallazgos:
        return [
          _seccion(seccion.titulo, [
            if (datos.hallazgos.isEmpty)
              pw.Text(
                'No hay suficientes reportes en este periodo para generar '
                'hallazgos.',
              )
            else
              for (final h in datos.hallazgos) _vineta(h),
          ]),
        ];
      case SeccionInforme.tabla:
        return _tablaDetallada(datos);
    }
  }

  List<pw.Widget> _resumen(DatosInforme datos) {
    final stats = datos.stats;
    final categoria = _categoriasOrdenadas(stats).first;
    final franja = stats.porFranja.keys.reduce(
      (a, b) => stats.porFranja[b]! > stats.porFranja[a]! ? b : a,
    );
    final colonia = stats.topColonias.isEmpty ? null : stats.topColonias.first;

    return [
      pw.Text(
        '${_rangoFrase(datos.rango)} se registraron '
        '${_reportes(stats.total)} que cumplen los criterios del informe. '
        '${_textoCambio(datos)}',
      ),
      pw.SizedBox(height: 8),
      _tabla(
        ['Indicador', 'Valor'],
        [
          ['Total de reportes', '${stats.total}'],
          [
            'Periodo anterior',
            datos.opciones.periodo.tipo == TipoPeriodo.todo
                ? 'No aplica'
                : _reportes(stats.totalAnterior),
          ],
          [
            'Categoría más reportada',
            '${infoCategoria[categoria]!.nombre} '
                '(${_reportes(stats.porCategoria[categoria]!)})',
          ],
          [
            'Colonia con más reportes',
            colonia == null
                ? 'Sin colonia identificada'
                : '${colonia.colonia} (${_reportes(colonia.conteo)})',
          ],
          [
            'Franja horaria con más reportes',
            '${franja.etiqueta} (${_reportes(stats.porFranja[franja]!)})',
          ],
          [
            'Pendientes de moderar',
            '${stats.porEstado[EstadoReporte.pendiente]}',
          ],
          ['Verificados', '${stats.porEstado[EstadoReporte.verificado]}'],
        ],
        anchos: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
      ),
    ];
  }

  List<pw.Widget> _colonias(EstadisticasReportes stats) {
    final colonias = stats.topColonias;
    return [
      if (colonias.isEmpty)
        pw.Text('Ningún reporte del periodo tiene colonia identificada.')
      else ...[
        _grafica(
          [
            for (final c in colonias)
              _Barra(_corto(c.colonia, 12), c.conteo, _marca),
          ],
          anguloEtiquetas: colonias.length > 5,
        ),
        pw.SizedBox(height: 8),
        _tabla(
          ['#', 'Colonia', 'Reportes', 'Desglose por categoría'],
          [
            for (var i = 0; i < colonias.length; i++)
              [
                '${i + 1}',
                colonias[i].colonia,
                '${colonias[i].conteo}',
                colonias[i]
                    .porCategoria
                    .entries
                    .map((e) => '${infoCategoria[e.key]!.nombre} ${e.value}')
                    .join(' · '),
              ],
          ],
          numericas: {0, 2},
          anchos: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(55),
            3: pw.FlexColumnWidth(5),
          },
        ),
      ],
      if (stats.sinColonia > 0) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          '${_reportes(stats.sinColonia)} sin colonia identificada '
          '${stats.sinColonia == 1 ? 'no entra' : 'no entran'} en el ranking.',
          style: const pw.TextStyle(fontSize: 8, color: _gris),
        ),
      ],
    ];
  }

  List<pw.Widget> _horario(EstadisticasReportes stats) {
    const franjasCortas = {
      FranjaHoraria.madrugada: 'Madrugada',
      FranjaHoraria.manana: 'Mañana',
      FranjaHoraria.tarde: 'Tarde',
      FranjaHoraria.noche: 'Noche',
    };
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const colorFranja = PdfColor.fromInt(0xFF5C6BC0); // indigo 400
    const colorDia = PdfColor.fromInt(0xFF26A69A); // teal 400

    return [
      if (stats.horaPico != null)
        _subtitulo('Hora con más reportes: ${stats.horaPico}:00–'
            '${stats.horaPico! + 1}:00'),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Por franja horaria',
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                _grafica([
                  for (final f in stats.porFranja.keys)
                    _Barra(franjasCortas[f]!, stats.porFranja[f]!, colorFranja),
                ]),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Por día de la semana',
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                _grafica([
                  for (var d = 1; d <= 7; d++)
                    _Barra(
                      dias[d - 1].substring(0, 3),
                      stats.porDiaSemana[d]!,
                      colorDia,
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      _tabla(
        ['Franja horaria', 'Reportes', '%'],
        [
          for (final f in stats.porFranja.keys)
            [
              f.etiqueta,
              '${stats.porFranja[f]}',
              _pct(stats.porFranja[f]!, stats.total),
            ],
        ],
        numericas: {1, 2},
      ),
    ];
  }

  List<pw.Widget> _tendencia(EstadisticasReportes stats) {
    final porDia = stats.granularidad == GranularidadTendencia.dia;
    final formato = DateFormat('d MMM', 'es_MX');
    final puntos = stats.tendencia;
    PuntoTendencia? pico;
    for (final p in puntos) {
      if (pico == null || p.conteo > pico.conteo) pico = p;
    }
    // Unas 8 fechas en el eje X, para que no se encimen.
    final cadaCuantos = (puntos.length / 8).ceil().clamp(1, 1 << 30);

    return [
      _subtitulo(porDia ? 'Reportes por día' : 'Reportes por semana'),
      _grafica(
        [
          for (var i = 0; i < puntos.length; i++)
            _Barra(
              i % cadaCuantos == 0 ? formato.format(puntos[i].inicio) : '',
              puntos[i].conteo,
              _marca,
            ),
        ],
        mostrarValores: puntos.length <= 31,
      ),
      if (pico != null && pico.conteo > 0) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          '${porDia ? 'Día' : 'Semana'} con más reportes: '
          '${porDia ? '' : 'semana del '}'
          '${DateFormat("d 'de' MMMM 'de' y", 'es_MX').format(pico.inicio)} '
          '(${_reportes(pico.conteo)}).',
        ),
      ],
    ];
  }

  List<pw.Widget> _tablaDetallada(DatosInforme datos) {
    final formato = DateFormat('dd/MM/yy HH:mm');
    final filas = datos.reportes.take(maximoFilasTabla).toList();
    return [
      _seccion(SeccionInforme.tabla.titulo, [
        _subtitulo(
          datos.reportes.length > maximoFilasTabla
              ? 'Los $maximoFilasTabla reportes más recientes de '
                  '${datos.reportes.length}'
              : '${_reportes(filas.length)}, del más reciente al más antiguo',
        ),
      ]),
      _tabla(
        ['Fecha', 'Categoría', 'Tipo', 'Colonia', 'Estado', 'Descripción'],
        [
          for (final r in filas)
            [
              formato.format(r.fechaHora),
              infoCategoria[r.categoria]!.nombre,
              nombreTipoReporte[r.tipo] ?? r.tipo,
              r.colonia.trim().isEmpty ? 'Sin colonia' : r.colonia.trim(),
              infoEstado[r.estado]!.nombre,
              _corto(r.descripcion.replaceAll(RegExp(r'\s+'), ' '), 160),
            ],
        ],
        tamano: 7.5,
        anchos: const {
          0: pw.FixedColumnWidth(58),
          1: pw.FixedColumnWidth(62),
          2: pw.FixedColumnWidth(70),
          3: pw.FixedColumnWidth(72),
          4: pw.FixedColumnWidth(48),
          5: pw.FlexColumnWidth(),
        },
      ),
    ];
  }

  // -------------------------------------------------------------------
  // Piezas reutilizables
  // -------------------------------------------------------------------

  /// Título de sección y su contenido. El título va pegado al primer
  /// elemento ([pw.Inseparable]) para que nunca quede solo al pie de una
  /// página; el resto del contenido sí se puede pasar a la siguiente.
  pw.Widget _seccion(String titulo, List<pw.Widget> contenido) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 18),
              pw.Text(
                titulo,
                style: const pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _marca,
                ),
              ),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, bottom: 8),
                height: 1,
                color: _grisClaro,
              ),
              if (contenido.isNotEmpty) contenido.first,
            ],
          ),
        ),
        ...contenido.skip(1),
      ],
    );
  }

  pw.Widget _subtitulo(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          texto,
          style: const pw.TextStyle(fontSize: 9, color: _gris),
        ),
      );

  pw.Widget _vineta(String texto, {double tamano = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('•  ', style: pw.TextStyle(fontSize: tamano)),
          pw.Expanded(
            child: pw.Text(texto, style: pw.TextStyle(fontSize: tamano)),
          ),
        ],
      ),
    );
  }

  pw.Widget _tabla(
    List<String> encabezados,
    List<List<String>> filas, {
    Set<int> numericas = const {},
    Map<int, pw.TableColumnWidth>? anchos,
    double tamano = 9,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _grisClaro, width: 0.5),
        bottom: pw.BorderSide(color: _grisClaro, width: 0.5),
      ),
      headerStyle: pw.TextStyle(
        fontSize: tamano,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _marca),
      headerAlignment: pw.Alignment.centerLeft,
      headerAlignments: {for (final i in numericas) i: pw.Alignment.centerRight},
      cellStyle: pw.TextStyle(fontSize: tamano),
      cellAlignments: {for (final i in numericas) i: pw.Alignment.centerRight},
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: anchos,
    );
  }

  /// Gráfica de barras verticales con el paquete pdf. Las barras se
  /// agrupan en un conjunto de datos por color para que cada una conserve
  /// el suyo (por ejemplo, el de su categoría).
  pw.Widget _grafica(
    List<_Barra> barras, {
    double alto = 160,
    bool mostrarValores = true,
    bool anguloEtiquetas = false,
  }) {
    final maximo = barras.fold<int>(0, (m, b) => b.valor > m ? b.valor : m);
    final intervalo = maximo <= 4 ? 1 : (maximo / 4).ceil();
    final tope = (maximo ~/ intervalo + 1) * intervalo;
    final n = barras.length;
    // Un eje fijo necesita al menos dos valores; con una sola barra se
    // agrega uno vacío a cada lado para que quede centrada.
    final valoresX = n == 1 ? [-1, 0, 1] : [for (var i = 0; i < n; i++) i];
    final ancho = (380 / n * 0.6).clamp(2.0, 28.0);

    final porColor = <int, List<pw.PointChartValue>>{};
    final colores = <int, PdfColor>{};
    for (var i = 0; i < n; i++) {
      final clave = barras[i].color.toInt();
      colores[clave] = barras[i].color;
      (porColor[clave] ??= [])
          .add(pw.PointChartValue(i.toDouble(), barras[i].valor.toDouble()));
    }

    const estiloEje = pw.TextStyle(fontSize: 7, color: _gris);
    return pw.SizedBox(
      height: alto,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis<int>(
            valoresX,
            format: (v) {
              final i = v.toInt();
              return i >= 0 && i < n ? barras[i].etiqueta : '';
            },
            textStyle: estiloEje,
            marginStart: 18,
            marginEnd: 18,
            ticks: true,
            angle: anguloEtiquetas ? 0.6 : 0,
          ),
          yAxis: pw.FixedAxis<int>(
            [for (var v = 0; v <= tope; v += intervalo) v],
            format: (v) => '${v.toInt()}',
            textStyle: estiloEje,
            divisions: true,
            divisionsColor: _grisClaro,
            divisionsWidth: 0.5,
          ),
        ),
        datasets: [
          for (final e in porColor.entries)
            pw.BarDataSet<pw.PointChartValue>(
              color: colores[e.key]!,
              width: ancho,
              data: e.value,
              valuePosition: pw.ValuePosition.top,
              buildValue: mostrarValores
                  ? (context, valor) => pw.Text(
                        '${valor.y.toInt()}',
                        style: const pw.TextStyle(fontSize: 7),
                      )
                  : null,
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Formatos
  // -------------------------------------------------------------------

  static PdfColor _pdfColor(int argb) => PdfColor.fromInt(argb);

  static PdfColor _colorCategoria(CategoriaReporte c) =>
      _pdfColor(colorPorCategoria(c).toARGB32());

  /// Categorías de más a menos reportes (con empate, el orden del enum).
  static List<CategoriaReporte> _categoriasOrdenadas(
    EstadisticasReportes stats,
  ) {
    return CategoriaReporte.values.toList()
      ..sort((a, b) {
        final porConteo = stats.porCategoria[b]!.compareTo(stats.porCategoria[a]!);
        return porConteo != 0 ? porConteo : a.index - b.index;
      });
  }

  static String _categoriaDeTipo(String tipo) {
    final c = tiposDeReporte[tipo];
    return c == null ? '—' : infoCategoria[c]!.nombre;
  }

  String _textoCambio(DatosInforme datos) {
    if (datos.opciones.periodo.tipo == TipoPeriodo.todo) return '';
    final cambio = datos.stats.cambioPorcentual;
    if (cambio == null) {
      return 'No hubo reportes en el periodo anterior para comparar.';
    }
    final redondeado = cambio.round();
    if (redondeado == 0) return 'Es la misma cantidad que en el periodo anterior.';
    return 'Esto es ${redondeado.abs()} % '
        '${redondeado > 0 ? 'más' : 'menos'} que en el periodo anterior '
        '(${_reportes(datos.stats.totalAnterior)}).';
  }

  static String _pct(int n, int total) =>
      total == 0 ? '0 %' : '${(n * 100 / total).toStringAsFixed(1)} %';

  static String _reportes(int n) => n == 1 ? '1 reporte' : '$n reportes';

  static String _corto(String texto, int maximo) =>
      texto.length <= maximo ? texto : '${texto.substring(0, maximo - 1)}…';

  static String _fechaHora(DateTime fecha) =>
      DateFormat("d 'de' MMMM 'de' y, HH:mm", 'es_MX').format(fecha);

  /// "Del 1 nov 2026 al 30 nov 2026", para inicio de frase.
  static String _rangoFrase(RangoFechas rango) {
    final formato = DateFormat('d MMM y', 'es_MX');
    final ultimo = rango.hasta.subtract(const Duration(milliseconds: 1));
    return 'Del ${formato.format(rango.desde)} al ${formato.format(ultimo)}';
  }

  /// "1 nov 2026 – 30 nov 2026". [RangoFechas.hasta] no se incluye, así
  /// que el último día es el anterior a ese instante.
  static String _rangoTexto(RangoFechas rango) {
    final formato = DateFormat('d MMM y', 'es_MX');
    final ultimo = rango.hasta.subtract(const Duration(milliseconds: 1));
    return '${formato.format(rango.desde)} – ${formato.format(ultimo)}';
  }
}

class _Barra {
  final String etiqueta;
  final int valor;
  final PdfColor color;

  const _Barra(this.etiqueta, this.valor, this.color);
}
