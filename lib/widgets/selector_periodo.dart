import 'package:flutter/material.dart';

import '../models/periodo_estadisticas.dart';
import '../utils/selector_fechas.dart';

/// Chips para elegir el periodo de las estadísticas: 7, 30 o 90 días,
/// todo el historial o un rango personalizado (abre el calendario).
/// Lo comparten el Panel y la sección Informes del administrador.
class SelectorPeriodo extends StatelessWidget {
  final PeriodoEstadisticas periodo;
  final ValueChanged<PeriodoEstadisticas> onCambio;

  /// Solo para tests: fija el "hoy" del calendario.
  final DateTime? hoy;

  /// Widgets extra al final de la fila (ej. el botón de informe).
  final List<Widget> acciones;

  const SelectorPeriodo({
    super.key,
    required this.periodo,
    required this.onCambio,
    this.hoy,
    this.acciones = const [],
  });

  Future<void> _elegirRangoPersonalizado(BuildContext context) async {
    final actual = periodo.tipo == TipoPeriodo.personalizado
        ? DateTimeRange(start: periodo.primerDia!, end: periodo.ultimoDia!)
        : null;
    final rango = await elegirRangoFechas(context, inicial: actual, hoy: hoy);
    if (rango == null) return;
    onCambio(PeriodoEstadisticas.personalizado(rango.start, rango.end));
  }

  @override
  Widget build(BuildContext context) {
    final esPersonalizado = periodo.tipo == TipoPeriodo.personalizado;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tipo in TipoPeriodo.values)
          if (tipo != TipoPeriodo.personalizado)
            ChoiceChip(
              label: Text(tipo.etiqueta),
              selected: periodo.tipo == tipo,
              onSelected: (_) => onCambio(PeriodoEstadisticas(tipo)),
            ),
        ChoiceChip(
          avatar: const Icon(Icons.date_range, size: 18),
          showCheckmark: false,
          // Con un rango elegido el chip muestra las fechas.
          label: Text(
            esPersonalizado ? periodo.nombre : TipoPeriodo.personalizado.etiqueta,
          ),
          selected: esPersonalizado,
          onSelected: (_) => _elegirRangoPersonalizado(context),
        ),
        ...acciones,
      ],
    );
  }
}
