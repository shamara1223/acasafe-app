import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/estadisticas_reportes.dart';
import '../models/reporte.dart';
import '../utils/constants.dart';

/// Gráficas del panel del administrador, hechas con fl_chart (dibuja en
/// canvas con Dart puro, así que funciona igual en web y en móvil).
/// Cada gráfica ocupa el espacio que le dé su padre: hay que ponerla
/// dentro de una caja con alto fijo.

/// Una barra de [GraficaBarras].
class DatoBarra {
  /// Nombre completo; sale en el tooltip al tocar la barra.
  final String nombre;

  /// Texto corto debajo de la barra. Si es null se usa [icono].
  final String? etiqueta;
  final IconData? icono;
  final int valor;
  final Color color;

  const DatoBarra({
    required this.nombre,
    this.etiqueta,
    this.icono,
    required this.valor,
    required this.color,
  });
}

/// Separación entre las líneas del eje Y para que queden ~4 divisiones
/// con números enteros.
double _intervaloY(int maximo) => maximo <= 4 ? 1 : (maximo / 4).ceilToDouble();

/// Tope del eje Y: el siguiente múltiplo del intervalo arriba del máximo,
/// para que la barra más alta no toque el borde.
double _topeY(int maximo) {
  final intervalo = _intervaloY(maximo);
  return ((maximo / intervalo).floor() + 1) * intervalo;
}

/// Números del eje Y (solo enteros).
AxisTitles _ejeY(BuildContext context, int maximo) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 32,
      interval: _intervaloY(maximo),
      getTitlesWidget: (valor, meta) {
        if (valor != valor.roundToDouble()) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: meta,
          child: Text(
            '${valor.toInt()}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
      },
    ),
  );
}

const _sinTitulos = AxisTitles(sideTitles: SideTitles(showTitles: false));

FlGridData _rejilla(BuildContext context, int maximo) {
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: _intervaloY(maximo),
    getDrawingHorizontalLine: (_) => FlLine(
      color: Theme.of(context).colorScheme.outlineVariant,
      strokeWidth: 1,
    ),
  );
}

/// Gráfica de barras verticales, una barra por dato.
class GraficaBarras extends StatelessWidget {
  final List<DatoBarra> datos;

  const GraficaBarras({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final maximo = datos.fold<int>(0, (m, d) => d.valor > m ? d.valor : m);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: _topeY(maximo),
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: _rejilla(context, maximo),
        barGroups: [
          for (var i = 0; i < datos.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: datos[i].valor.toDouble(),
                  color: datos[i].color,
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: _sinTitulos,
          rightTitles: _sinTitulos,
          leftTitles: _ejeY(context, maximo),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (valor, meta) {
                final i = valor.toInt();
                if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                final dato = datos[i];
                return SideTitleWidget(
                  meta: meta,
                  child: dato.etiqueta != null
                      ? Text(dato.etiqueta!, style: tema.textTheme.labelSmall)
                      : Icon(dato.icono, size: 18, color: dato.color),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => tema.colorScheme.inverseSurface,
            getTooltipItem: (grupo, indiceGrupo, barra, indiceBarra) {
              final dato = datos[indiceGrupo];
              return BarTooltipItem(
                '${dato.nombre}\n${dato.valor}',
                TextStyle(
                  color: tema.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Gráfica de línea con la tendencia de reportes por día o por semana.
class GraficaTendencia extends StatelessWidget {
  final List<PuntoTendencia> puntos;
  final GranularidadTendencia granularidad;

  const GraficaTendencia({
    super.key,
    required this.puntos,
    required this.granularidad,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.primary;
    final formato = DateFormat('d MMM', 'es_MX');
    final maximo = puntos.fold<int>(0, (m, p) => p.conteo > m ? p.conteo : m);
    // Unas 4 fechas en el eje X, para que no se encimen.
    final cadaCuantos = (puntos.length / 4).ceil().clamp(1, 1 << 30);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: _topeY(maximo),
        minX: 0,
        // Con un solo punto el eje X necesita algo de ancho.
        maxX: puntos.length > 1 ? (puntos.length - 1).toDouble() : 1,
        borderData: FlBorderData(show: false),
        gridData: _rejilla(context, maximo),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < puntos.length; i++)
                FlSpot(i.toDouble(), puntos[i].conteo.toDouble()),
            ],
            // Sin curvas: una curva suavizada puede bajar de cero.
            isCurved: false,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: puntos.length <= 31),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: _sinTitulos,
          rightTitles: _sinTitulos,
          leftTitles: _ejeY(context, maximo),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (valor, meta) {
                final i = valor.toInt();
                if (valor != i.toDouble() ||
                    i < 0 ||
                    i >= puntos.length ||
                    i % cadaCuantos != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    formato.format(puntos[i].inicio),
                    style: tema.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tema.colorScheme.inverseSurface,
            getTooltipItems: (tocados) {
              return tocados.map((t) {
                final punto = puntos[t.x.toInt()];
                final fecha = formato.format(punto.inicio);
                return LineTooltipItem(
                  '${granularidad == GranularidadTendencia.semana ? 'Semana del $fecha' : fecha}\n'
                  '${punto.conteo}',
                  TextStyle(
                    color: tema.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

/// Gráfica de dona con la distribución de reportes por estado.
class GraficaEstados extends StatelessWidget {
  final Map<EstadoReporte, int> porEstado;

  const GraficaEstados({super.key, required this.porEstado});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: 36,
        sectionsSpace: 2,
        sections: [
          for (final e in EstadoReporte.values)
            if ((porEstado[e] ?? 0) > 0)
              PieChartSectionData(
                value: porEstado[e]!.toDouble(),
                color: infoEstado[e]!.color,
                title: '${porEstado[e]}',
                radius: 48,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
        ],
      ),
    );
  }
}

/// Un renglón de la leyenda de una gráfica.
class DatoLeyenda {
  final String nombre;
  final int valor;
  final Color color;

  const DatoLeyenda(this.nombre, this.valor, this.color);
}

/// Leyenda de una gráfica: punto de color, nombre y cantidad.
class LeyendaGrafica extends StatelessWidget {
  final List<DatoLeyenda> datos;

  const LeyendaGrafica({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final d in datos)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: d.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                '${d.nombre} (${d.valor})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}
