import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reporte.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

class ReportDetailScreen extends StatelessWidget {
  final Reporte reporte;

  const ReportDetailScreen({super.key, required this.reporte});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final formatoFecha = DateFormat('d MMM yyyy, HH:mm', 'es_MX');

    return Scaffold(
      appBar: AppBar(title: Text(nombreTipoReporte[reporte.tipo] ?? reporte.tipo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reporte.fotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(reporte.fotoUrl!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Chip(
            label: Text(reporte.colonia),
            avatar: const Icon(Icons.location_on, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            formatoFecha.format(reporte.fechaHora),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(reporte.descripcion, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('¿Esta información sigue vigente?',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => firestoreService.votar(
                    reporteId: reporte.id!,
                    esUtil: true,
                  ),
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text('Sí (${reporte.votosUtil})'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => firestoreService.votar(
                    reporteId: reporte.id!,
                    esUtil: false,
                  ),
                  icon: const Icon(Icons.thumb_down_outlined),
                  label: Text('No (${reporte.votosFalso})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
