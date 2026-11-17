import 'package:flutter/material.dart';

import '../models/periodo_estadisticas.dart';
import 'admin/informes_screen.dart';
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
  // La versión cambia en cada envío para que Informes lo vuelva a
  // preseleccionar aunque sea el mismo periodo.
  PeriodoEstadisticas? _periodoInforme;
  int _versionInforme = 0;

  void _irAInformes(PeriodoEstadisticas periodo) {
    setState(() {
      _periodoInforme = periodo;
      _versionInforme++;
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
          InformesScreen(
            periodoInicial: _periodoInforme,
            versionPeriodo: _versionInforme,
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
