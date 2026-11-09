import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/filtros_reporte.dart';
import '../widgets/capa_calor.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

/// Qué capa se dibuja encima del mapa base.
enum _VistaMapa { marcadores, calor }

/// Pantalla principal: mapa con los reportes activos.
class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  // Se crea una sola vez para que el StreamBuilder no se vuelva a
  // suscribir cada vez que cambian los filtros (setState).
  late final Stream<List<Reporte>> _streamReportes =
      _firestoreService.reportesRecientes();

  // Coordenadas iniciales (Acapulco)
  static const _centroAcapulco = LatLng(acapulcoLat, acapulcoLng);

  FiltrosReporte _filtros = FiltrosReporte.inicial();
  bool _leyendaAbierta = false;
  _VistaMapa _vista = _VistaMapa.marcadores;

  // Último lote recibido del stream; el bottom sheet de filtros lo usa
  // para mostrar el contador mientras está abierto.
  List<Reporte> _reportes = const [];

  // Reportes que pasan los filtros; el toque en el mapa de calor cuenta
  // sobre estos.
  List<Reporte> _visibles = const [];

  // Convertir los reportes a marcadores de flutter_map
  List<Marker> _marcadoresDesdeReportes(List<Reporte> reportes) {
    return reportes.map((r) {
      final color = colorPorCategoria(r.categoria);
      return Marker(
        point: LatLng(r.ubicacion.latitude, r.ubicacion.longitude),
        width: 34,
        height: 34,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(reporte: r),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 3),
              ],
            ),
            child: Icon(
              infoCategoria[r.categoria]!.icono,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }).toList();
  }

  // Agrupa los reportes por categoría para la capa de calor.
  Map<CategoriaReporte, List<LatLng>> _puntosPorCategoria(
    List<Reporte> reportes,
  ) {
    final puntos = <CategoriaReporte, List<LatLng>>{};
    for (final r in reportes) {
      puntos
          .putIfAbsent(r.categoria, () => [])
          .add(LatLng(r.ubicacion.latitude, r.ubicacion.longitude));
    }
    return puntos;
  }

  // En la vista de calor, al tocar el mapa se muestran los reportes
  // (ya filtrados) que hay en ~300 m alrededor del punto.
  void _mostrarResumenZona(LatLng punto) {
    const distancia = Distance();
    final conteo = <CategoriaReporte, int>{};
    for (final r in _visibles) {
      final metros = distancia(
        punto,
        LatLng(r.ubicacion.latitude, r.ubicacion.longitude),
      );
      if (metros <= CapaCalor.radioMetros) {
        conteo[r.categoria] = (conteo[r.categoria] ?? 0) + 1;
      }
    }
    final total = conteo.values.fold(0, (a, b) => a + b);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 1
                      ? '1 reporte en ~300 m'
                      : '$total reportes en ~300 m',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (total == 0)
                  const Text('No hay reportes cerca de este punto.')
                else
                  for (final c in CategoriaReporte.values)
                    if ((conteo[c] ?? 0) > 0)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: colorPorCategoria(c),
                          child: Icon(
                            infoCategoria[c]!.icono,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(infoCategoria[c]!.nombre),
                        trailing: Text(
                          '${conteo[c]}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                if (_filtros.estaActivo)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Solo se cuentan los reportes que pasan los filtros.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Selector entre la vista de marcadores y la de mapa de calor.
  Widget _selectorVista() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: SegmentedButton<_VistaMapa>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(
            value: _VistaMapa.marcadores,
            icon: Icon(Icons.place),
            label: Text('Marcadores'),
          ),
          ButtonSegment(
            value: _VistaMapa.calor,
            icon: Icon(Icons.blur_on),
            label: Text('Mapa de calor'),
          ),
        ],
        selected: {_vista},
        onSelectionChanged: (sel) => setState(() => _vista = sel.first),
      ),
    );
  }

  void _abrirFiltros() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        // StatefulBuilder para que el sheet se redibuje al cambiar un
        // filtro; cada cambio también se aplica de inmediato al mapa.
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void cambiar(FiltrosReporte nuevos) {
              setState(() => _filtros = nuevos);
              setSheetState(() {});
            }

            final visibles = _filtros.aplicar(_reportes).length;
            final tema = Theme.of(context).textTheme;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Filtros', style: tema.titleLarge),
                        ),
                        Text('$visibles de ${_reportes.length} reportes'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Categorías', style: tema.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CategoriaReporte.values.map((c) {
                        final color = colorPorCategoria(c);
                        final activa = _filtros.categorias.contains(c);
                        return FilterChip(
                          avatar: Icon(
                            infoCategoria[c]!.icono,
                            size: 18,
                            color: activa ? Colors.white : color,
                          ),
                          label: Text(infoCategoria[c]!.nombre),
                          selected: activa,
                          showCheckmark: false,
                          selectedColor: color,
                          labelStyle: TextStyle(
                            color: activa ? Colors.white : null,
                          ),
                          side: BorderSide(color: color),
                          onSelected: (sel) {
                            final categorias = {..._filtros.categorias};
                            sel ? categorias.add(c) : categorias.remove(c);
                            cambiar(_filtros.copyWith(categorias: categorias));
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Franja horaria', style: tema.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FranjaHoraria.values.map((f) {
                        return ChoiceChip(
                          label: Text(f.etiqueta),
                          selected: _filtros.franja == f,
                          onSelected: (_) =>
                              cambiar(_filtros.copyWith(franja: f)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Periodo', style: tema.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PeriodoReporte.values.map((p) {
                        return ChoiceChip(
                          label: Text(p.etiqueta),
                          selected: _filtros.periodo == p,
                          onSelected: (_) =>
                              cambiar(_filtros.copyWith(periodo: p)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _filtros.estaActivo
                              ? () => cambiar(FiltrosReporte.inicial())
                              : null,
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Limpiar filtros'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Listo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Contador flotante de reportes visibles, arriba del mapa.
  Widget _contador(int visibles, int total) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          _filtros.estaActivo
              ? 'Mostrando $visibles de $total reportes'
              : 'Mostrando $total reportes',
        ),
      ),
    );
  }

  // Leyenda plegable con el color e ícono de cada categoría.
  Widget _leyenda() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _leyendaAbierta = !_leyendaAbierta),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Leyenda',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Icon(
                    _leyendaAbierta ? Icons.expand_more : Icons.expand_less,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_leyendaAbierta && _vista == _VistaMapa.calor) ...[
              for (final c in CategoriaReporte.values)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [
                              colorPorCategoria(c).withValues(alpha: 0),
                              colorPorCategoria(c),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        infoCategoria[c]!.nombre,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'menos reportes → más reportes',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (_leyendaAbierta && _vista == _VistaMapa.marcadores)
              for (final c in CategoriaReporte.values)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: colorPorCategoria(c),
                        child: Icon(
                          infoCategoria[c]!.icono,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        infoCategoria[c]!.nombre,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AcaSafe'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filtros.estaActivo,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filtrar reportes',
            onPressed: _abrirFiltros,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _authService.cerrarSesion(),
          ),
        ],
      ),
      body: StreamBuilder<List<Reporte>>(
        stream: _streamReportes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar reportes: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          _reportes = snapshot.data!;
          final visibles = _filtros.aplicar(_reportes);
          _visibles = visibles;

          // ¡Aquí está el mapa de OpenStreetMap!
          return Stack(
            children: [
              // Al cambiar de vista solo cambia la última capa; el
              // FlutterMap es el mismo, así que conserva zoom y posición.
              FlutterMap(
                options: MapOptions(
                  initialCenter: _centroAcapulco,
                  initialZoom: 12.5,
                  onTap: (_, punto) {
                    if (_vista == _VistaMapa.calor) _mostrarResumenZona(punto);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.example.acasafe_app',
                  ),
                  if (_vista == _VistaMapa.marcadores)
                    MarkerLayer(
                      markers: _marcadoresDesdeReportes(visibles),
                    )
                  else
                    CapaCalor(
                      puntosPorCategoria: _puntosPorCategoria(visibles),
                    ),
                ],
              ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    _selectorVista(),
                    const SizedBox(height: 8),
                    _contador(visibles.length, _reportes.length),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _leyenda(),
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
