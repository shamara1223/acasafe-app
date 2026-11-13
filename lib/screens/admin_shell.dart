import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_map_screen.dart';

/// Interfaz del rol admin: cuatro secciones con barra de navegación.
/// El mapa es la misma [HomeMapScreen] que ven los ciudadanos.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene vivas todas las secciones, así el mapa
      // conserva zoom, filtros y vista al cambiar de pestaña.
      body: IndexedStack(
        index: _indice,
        children: const [
          _SeccionProximamente(titulo: 'Panel', icono: Icons.dashboard),
          HomeMapScreen(),
          _SeccionProximamente(titulo: 'Reportes', icono: Icons.list_alt),
          _SeccionProximamente(titulo: 'Informes', icono: Icons.bar_chart),
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

  const _SeccionProximamente({required this.titulo, required this.icono});

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
          ],
        ),
      ),
    );
  }
}
