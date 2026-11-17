import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../utils/constants.dart';

/// Etiqueta con el estado de moderación de un reporte: ícono y nombre en
/// el color del estado, sobre un fondo suave del mismo color.
class EtiquetaEstado extends StatelessWidget {
  final EstadoReporte estado;

  const EtiquetaEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final info = infoEstado[estado]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icono, size: 14, color: info.color),
          const SizedBox(width: 4),
          Text(
            info.nombre,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje centrado con ícono, para los estados vacío y de error.
class MensajeCentrado extends StatelessWidget {
  final IconData icono;
  final String texto;

  const MensajeCentrado({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
