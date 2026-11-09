import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../utils/constants.dart';

/// Capa de mapa de calor para flutter_map: una capa por categoría, cada
/// una con su color de [colorPorCategoria].
///
/// Cada reporte se dibuja como un círculo con degradado radial (color
/// semitransparente en el centro → transparente en el borde). Como los
/// círculos se dibujan uno encima de otro, la opacidad se acumula: donde
/// hay más reportes juntos la mancha queda más intensa y opaca.
///
/// Se dibuja con un CustomPainter (sin dart:io) para que funcione igual en
/// Flutter Web, Android e iOS. Con ~200 reportes son ~200 círculos por
/// cuadro, que se pintan sin problema al mover el mapa.
class CapaCalor extends StatelessWidget {
  /// Reportes agrupados por categoría (ya filtrados).
  final Map<CategoriaReporte, List<LatLng>> puntosPorCategoria;

  const CapaCalor({super.key, required this.puntosPorCategoria});

  /// Radio de cada mancha en metros. A zoom de colonia se respeta tal
  /// cual; a zoom de ciudad se agranda hasta [_radioMinPx] para que las
  /// manchas sigan viéndose y se mezclen entre sí.
  static const double radioMetros = 300;
  static const double _radioMinPx = 20;
  static const double _radioMaxPx = 80;

  /// Cuántos píxeles mide [radioMetros] con el zoom actual, acotado entre
  /// [_radioMinPx] y [_radioMaxPx].
  static double radioEnPixeles(MapCamera camera) {
    final centro = camera.center;
    final norte = const Distance().offset(centro, radioMetros, 0);
    final px = (camera.getOffsetFromOrigin(centro) -
            camera.getOffsetFromOrigin(norte))
        .distance;
    return px.clamp(_radioMinPx, _radioMaxPx).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // MapCamera.of hace que la capa se redibuje al mover o hacer zoom.
    final camera = MapCamera.of(context);
    final radio = radioEnPixeles(camera);
    final tamano = Size(camera.size.x, camera.size.y);

    return MobileLayerTransformer(
      child: Stack(
        children: [
          for (final entrada in puntosPorCategoria.entries)
            if (entrada.value.isNotEmpty)
              CustomPaint(
                size: tamano,
                isComplex: true,
                painter: _PintorCalor(
                  puntos: entrada.value,
                  color: colorPorCategoria(entrada.key),
                  camera: camera,
                  radio: radio,
                ),
              ),
        ],
      ),
    );
  }
}

class _PintorCalor extends CustomPainter {
  final List<LatLng> puntos;
  final Color color;
  final MapCamera camera;
  final double radio;

  _PintorCalor({
    required this.puntos,
    required this.color,
    required this.camera,
    required this.radio,
  });

  // Opacidad en el centro de un solo reporte. Con varios encimados se
  // acumula: 1 reporte ≈ 30 %, 3 ≈ 66 %, 6 ≈ 88 %.
  static const double _alfaCentro = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    // Un solo shader centrado en el origen; para cada punto se traslada
    // el canvas en lugar de crear un degradado nuevo por reporte.
    final pincel = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        radio,
        [
          color.withValues(alpha: _alfaCentro),
          color.withValues(alpha: _alfaCentro * 0.45),
          color.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );

    final limites = (Offset.zero & size).inflate(radio);
    for (final punto in puntos) {
      final centro = camera.getOffsetFromOrigin(punto);
      if (!limites.contains(centro)) continue; // fuera de pantalla
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.drawCircle(Offset.zero, radio, pincel);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorCalor anterior) =>
      anterior.camera != camera ||
      anterior.puntos != puntos ||
      anterior.color != color ||
      anterior.radio != radio;
}
