import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/reporte.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

/// Pantalla principal: mapa con los reportes activos.
/// Esta es la Fase 1 del proyecto (consulta y reporte ciudadano);
/// la Fase 2 (mapas de calor estadísticos) se construye encima de
/// esta misma colección de Firestore, ya con suficientes reportes.
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  static const _centroAcapulco = CameraPosition(
    target: LatLng(acapulcoLat, acapulcoLng),
    zoom: 12.5,
  );

  Set<Marker> _marcadoresDesdeReportes(List<Reporte> reportes) {
    return reportes.map((r) {
      return Marker(
        markerId: MarkerId(r.id!),
        position: LatLng(r.ubicacion.latitude, r.ubicacion.longitude),
        infoWindow: InfoWindow(
          title: nombreTipoReporte[r.tipo] ?? r.tipo,
          snippet: r.colonia,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(reporte: r),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AcaSafe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _authService.cerrarSesion(),
          ),
        ],
      ),
      body: StreamBuilder<List<Reporte>>(
        stream: _firestoreService.reportesRecientes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar reportes: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return GoogleMap(
            initialCameraPosition: _centroAcapulco,
            markers: _marcadoresDesdeReportes(snapshot.data!),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewReportScreen()),
          );
        },
        icon: const Icon(Icons.add_alert),
        label: const Text('Reportar'),
      ),
    );
  }
}
