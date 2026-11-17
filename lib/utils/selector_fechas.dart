import 'package:flutter/material.dart';

/// Abre el selector de rango de fechas de Material con los textos en
/// español. Regresa null si el usuario cancela.
///
/// Los nombres de meses y días dentro del calendario salen en inglés
/// porque la app todavía no incluye flutter_localizations (pide una
/// versión más nueva de intl que la del proyecto).
Future<DateTimeRange?> elegirRangoFechas(
  BuildContext context, {
  DateTimeRange? inicial,
  DateTime? hoy,
}) {
  final ahora = hoy ?? DateTime.now();
  final ultimoDia = DateTime(ahora.year, ahora.month, ahora.day);
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: ultimoDia,
    currentDate: ultimoDia,
    // Un rango guardado que termina después de hoy haría fallar al
    // selector; en ese caso se abre sin selección.
    initialDateRange:
        inicial != null && !inicial.end.isAfter(ultimoDia) ? inicial : null,
    helpText: 'Elige el periodo',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    saveText: 'Aceptar',
    fieldStartLabelText: 'Fecha inicial',
    fieldEndLabelText: 'Fecha final',
    fieldStartHintText: 'Fecha inicial',
    fieldEndHintText: 'Fecha final',
    errorFormatText: 'Formato de fecha no válido',
    errorInvalidText: 'Fecha fuera de rango',
    errorInvalidRangeText: 'Rango no válido',
  );
}
