import 'package:flutter/material.dart';

import '../models/periodo_estadisticas.dart';
import '../services/auth_service.dart';
import 'admin/panel_screen.dart';
import 'admin/reportes_admin_screen.dart';
import 'home_map_screen.dart';

/// Interfaz del rol admin: cuatro secciones con barra de navegación.
/// El mapa es la misma [HomeMapScreen] que ven los ciudadanos.
/// main.dart solo muestra esta pantalla a usuarios con rol admin, así que
/// Panel, Reportes e Informes no son alcanzables para un ciudadano.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _indiceInformes = 3;

  int _indice = 0;

  // Periodo que el panel mandó a Informes con "Generar informe PDF".
  PeriodoEstadisticas? _periodoInforme;

  void _irAInformes(PeriodoEstadisticas periodo) {
    setState(() {
      _periodoInforme = periodo;
      _indice = _indiceInformes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene vivas todas las secciones, así el mapa
      // conserva zoom, filtros y vista al cambiar de pestaña.
      body: IndexedStack(
        index: _indice,
        children: [
          PanelScreen(onGenerarInforme: _irAInformes),
          const HomeMapScreen(),
          const ReportesAdminScreen(),
          _SeccionProximamente(
            titulo: 'Informes',
            icono: Icons.bar_chart,
            detalle: _periodoInforme == null
                ? null
                : 'Periodo seleccionado: ${_periodoInforme!.nombre}',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Informes',
          ),
        ],
      ),
    );
  }
}

/// Sección todavía sin contenido. Incluye el botón de cerrar sesión para
/// que esté disponible desde cualquier pestaña (el mapa trae el suyo).
class _SeccionProximamente extends StatelessWidget {
  final String titulo;
  final IconData icono;

  /// Línea extra debajo de "Próximamente" (ej. el periodo elegido).
  final String? detalle;

  const _SeccionProximamente({
    required this.titulo,
    required this.icono,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Próximamente', style: tema.textTheme.titleLarge),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(detalle!, style: tema.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
