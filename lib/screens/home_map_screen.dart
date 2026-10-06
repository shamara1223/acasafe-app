import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

/// Pantalla principal: mapa con los reportes activos.
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  // Coordenadas iniciales (Acapulco)
  static const _centroAcapulco = LatLng(acapulcoLat, acapulcoLng);

  // Convertir los reportes a marcadores de flutter_map
  List<Marker> _marcadoresDesdeReportes(List<Reporte> reportes) {
    return reportes.map((r) {
      return Marker(
        point: LatLng(r.ubicacion.latitude, r.ubicacion.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(reporte: r),
              ),
            );
          },
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }).toList();
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
          
          // ¡Aquí está el mapa de OpenStreetMap!
          return FlutterMap(
            options: const MapOptions(
              initialCenter: _centroAcapulco,
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.example.acasafe_app',
              ),
              MarkerLayer(
                markers: _marcadoresDesdeReportes(snapshot.data!),
              ),
            ],
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