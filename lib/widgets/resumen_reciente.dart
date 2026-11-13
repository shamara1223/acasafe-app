import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/estadisticas_reportes.dart';
import '../models/reporte.dart';
import '../services/estadisticas_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

/// Contenido del panel "Resumen reciente" del mapa: estadísticas de los
/// últimos 7 días. Lo ven igual el ciudadano y el admin.
///
/// Este widget solo trae los datos de Firestore; lo que se dibuja está
/// en [ResumenRecienteContenido], que no depende de Firebase.
class ResumenReciente extends StatefulWidget {
  /// Se llama al tocar uno de los reportes más recientes.
  final ValueChanged<Reporte> onAbrirReporte;

  const ResumenReciente({super.key, required this.onAbrirReporte});

  @override
  State<ResumenReciente> createState() => _ResumenRecienteState();
}

class _ResumenRecienteState extends State<ResumenReciente> {
  // Se piden 14 días: los últimos 7 más los 7 anteriores, que los
  // hallazgos usan para comparar. El límite superior queda un día
  // adelante para que también lleguen los reportes creados mientras el
  // panel está abierto.
  late final Stream<List<Reporte>> _stream = () {
    final ahora = DateTime.now();
    return FirestoreService().reportesEnRango(
      ahora.subtract(ResumenRecienteContenido.periodo * 2),
      ahora.add(const Duration(days: 1)),
    );
  }();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reporte>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No se pudo cargar el resumen. Intenta más tarde.'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ResumenRecienteContenido(
          reportes: snapshot.data!,
          ahora: DateTime.now(),
          onAbrirReporte: widget.onAbrirReporte,
        );
      },
    );
  }
}

/// Dibuja el resumen de los 7 días anteriores a [ahora] a partir de una
/// lista de reportes ya descargada.
class ResumenRecienteContenido extends StatelessWidget {
  static const periodo = Duration(days: 7);
  static const _servicio = EstadisticasService();

  /// Puede traer reportes más viejos; los de los 7 días anteriores al
  /// periodo se usan para comparar y el resto se ignora.
  final List<Reporte> reportes;
  final DateTime ahora;
  final ValueChanged<Reporte> onAbrirReporte;

  const ResumenRecienteContenido({
    super.key,
    required this.reportes,
    required this.ahora,
    required this.onAbrirReporte,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final desde = ahora.subtract(periodo);
    final stats = _servicio.calcular(reportes, desde: desde, hasta: ahora);

    final nota = Text(
      'Basado en reportes ciudadanos; no son cifras oficiales.',
      style: tema.textTheme.bodySmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );

    if (stats.total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No hay reportes en los últimos 7 días.'),
          const SizedBox(height: 12),
          nota,
        ],
      );
    }

    // Categoría con más reportes; con empate gana la primera del enum.
    final categoria = CategoriaReporte.values.reduce(
      (a, b) => stats.porCategoria[b]! > stats.porCategoria[a]! ? b : a,
    );
    final colonia =
        stats.topColonias.isEmpty ? null : stats.topColonias.first;

    final recientes = reportes
        .where((r) => !r.fechaHora.isBefore(desde) && !r.fechaHora.isAfter(ahora))
        .toList()
      ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

    final hallazgos = _servicio
        .generarHallazgos(reportes, desde: desde, hasta: ahora)
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Total
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${stats.total}',
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stats.total == 1
                    ? 'reporte en los últimos 7 días'
                    : 'reportes en los últimos 7 días',
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Dato(
          etiqueta: 'Categoría más reportada',
          valor: infoCategoria[categoria]!.nombre,
          conteo: stats.porCategoria[categoria]!,
          avatar: CircleAvatar(
            radius: 16,
            backgroundColor: colorPorCategoria(categoria),
            child: Icon(
              infoCategoria[categoria]!.icono,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Dato(
          etiqueta: 'Colonia con más reportes',
          valor: colonia?.colonia ?? 'Sin colonia identificada',
          conteo: colonia?.conteo,
          avatar: CircleAvatar(
            radius: 16,
            backgroundColor: tema.colorScheme.secondaryContainer,
            child: Icon(
              Icons.location_on,
              size: 18,
              color: tema.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Más recientes', style: tema.textTheme.titleSmall),
        for (final r in recientes.take(3)) _filaReporte(context, r),
        if (hallazgos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Hallazgos', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final frase in hallazgos)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(frase, style: tema.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        nota,
      ],
    );
  }

  Widget _filaReporte(BuildContext context, Reporte r) {
    final formatoFecha = DateFormat('d MMM, HH:mm', 'es_MX');
    final colonia =
        _servicio.coloniaIdentificada(r.colonia) ?? coloniaNoIdentificada;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: colorPorCategoria(r.categoria),
        child: Icon(
          infoCategoria[r.categoria]!.icono,
          size: 16,
          color: Colors.white,
        ),
      ),
      title: Text(
        nombreTipoReporte[r.tipo] ?? r.tipo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$colonia · ${formatoFecha.format(r.fechaHora)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onAbrirReporte(r),
    );
  }
}

/// Fila "etiqueta / valor" del resumen, con un avatar a la izquierda y
/// el número de reportes a la derecha.
class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final int? conteo;
  final Widget avatar;

  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.conteo,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                valor,
                style: tema.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (conteo != null)
          Text(
            '$conteo',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
