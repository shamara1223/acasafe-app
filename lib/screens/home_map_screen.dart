import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/reporte.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/filtros_reporte.dart';
import '../widgets/capa_calor.dart';
import '../widgets/resumen_reciente.dart';
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

  // A partir de este ancho el resumen se muestra como panel lateral.
  static const double _anchoPanelLateral = 840;

  static const double _altoBotonReportar = 60;
  static const double _altoLeyendaPlegada = 36;

  FiltrosReporte _filtros = FiltrosReporte.inicial();
  bool _leyendaAbierta = false;
  bool _resumenAbierto = false;

  // Se actualiza en cada build (LayoutBuilder); lo usan los toques para
  // saber si el resumen y la leyenda comparten espacio.
  bool _esAncho = false;
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
              onTap: () => setState(() {
                _leyendaAbierta = !_leyendaAbierta;
                // En celular, abrir la leyenda pliega el resumen (ver
                // _alternarResumen).
                if (_leyendaAbierta && !_esAncho) _resumenAbierto = false;
              }),
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

  void _abrirReporte(Reporte r) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportDetailScreen(reporte: r)),
    );
  }

  void _alternarResumen() {
    setState(() {
      _resumenAbierto = !_resumenAbierto;
      // En celular el resumen y la leyenda comparten espacio: al abrir
      // uno se pliega la otra para que no se encimen.
      if (_resumenAbierto && !_esAncho) _leyendaAbierta = false;
    });
  }

  // Barra "Resumen reciente": plegada por defecto, se abre con un toque.
  // - En celular se despliega ahí mismo, debajo del contador, con
  //   scroll interno si no cabe.
  // - En pantallas anchas solo es el botón; el contenido va en el panel
  //   lateral (ver _panelLateralResumen).
  Widget _resumenDesplegable(bool esAncho) {
    final tema = Theme.of(context);
    final abiertoAqui = _resumenAbierto && !esAncho;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          color: tema.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                expanded: _resumenAbierto,
                child: InkWell(
                  onTap: _alternarResumen,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      // Plegado es un chip compacto; abierto ocupa todo
                      // el ancho del panel.
                      mainAxisSize:
                          abiertoAqui ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights,
                          size: 20,
                          color: tema.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        if (abiertoAqui)
                          Expanded(child: _tituloResumen(conAclaracion: true))
                        else
                          _tituloResumen(conAclaracion: false),
                        const SizedBox(width: 4),
                        Icon(
                          _resumenAbierto
                              ? (esAncho
                                  ? Icons.chevron_right
                                  : Icons.expand_less)
                              : (esAncho
                                  ? Icons.chevron_left
                                  : Icons.expand_more),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (abiertoAqui) ...[
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: ResumenReciente(onAbrirReporte: _abrirReporte),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Título del resumen. Con el panel abierto lleva una línea que aclara
  // de qué periodo son los datos y que no siguen los filtros del mapa
  // (el resumen hace su propia consulta).
  Widget _tituloResumen({required bool conAclaracion}) {
    final tema = Theme.of(context);
    const titulo = Text(
      'Resumen reciente',
      style: TextStyle(fontWeight: FontWeight.bold),
    );
    if (!conAclaracion) return titulo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titulo,
        Text(
          'Últimos 7 días · No aplica los filtros del mapa',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Panel lateral del resumen para pantallas anchas (tablet, escritorio).
  // Va junto al mapa, no encima, así no tapa ningún control.
  Widget _panelLateralResumen() {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surface,
      elevation: 4,
      child: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(Icons.insights, color: tema.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: _tituloResumen(conAclaracion: true)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar resumen',
                    onPressed: _alternarResumen,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ResumenReciente(onAbrirReporte: _abrirReporte),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón principal de la pantalla: grande y siempre visible. Usa el
  // color primario del tema (verde azulado intenso) con texto blanco, que
  // no es el color de ninguna categoría de reporte.
  Widget _botonReportar() {
    final colores = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewReportScreen()),
        );
      },
      style: FilledButton.styleFrom(
        backgroundColor: colores.primary,
        foregroundColor: colores.onPrimary,
        minimumSize: const Size(0, _altoBotonReportar),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 6,
        shadowColor: Colors.black54,
        shape: const StadiumBorder(
          side: BorderSide(color: Colors.white, width: 2),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      icon: const Icon(Icons.add_alert, size: 26),
      label: const Text('Reportar incidente'),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final esAncho = constraints.maxWidth >= _anchoPanelLateral;
          _esAncho = esAncho;
          // Margen del sistema abajo (barra de inicio del iPhone).
          final margenInferior = MediaQuery.paddingOf(context).bottom;

          // El mapa siempre es el primer hijo del Row, así conserva su
          // estado aunque se abra o cierre el panel lateral.
          return Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _mapaConCapas(esAncho, margenInferior),
                    ),
                    // Fuera del StreamBuilder: el botón de reportar está
                    // visible aunque los reportes sigan cargando.
                    // En celular va centrado abajo; en pantallas anchas,
                    // en la esquina inferior derecha.
                    if (esAncho)
                      Positioned(
                        right: 16,
                        bottom: 16 + margenInferior,
                        child: _botonReportar(),
                      )
                    else
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16 + margenInferior,
                        child: Center(child: _botonReportar()),
                      ),
                  ],
                ),
              ),
              if (esAncho && _resumenAbierto) _panelLateralResumen(),
            ],
          );
        },
      ),
    );
  }

  Widget _mapaConCapas(bool esAncho, double margenInferior) {
    return StreamBuilder<List<Reporte>>(
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

        // En celular la leyenda va arriba del botón de reportar (que
        // ocupa el centro); en pantallas anchas, a su misma altura.
        final bajoLeyenda =
            margenInferior + (esAncho ? 12 : 16 + _altoBotonReportar + 12);

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
            // Columna superior: selector, contador y "Resumen reciente".
            // Su límite inferior deja libres la leyenda (plegada) y el
            // botón de reportar, para que el resumen abierto no los tape.
            // La Column solo recibe toques sobre sus hijos; el resto del
            // mapa sigue respondiendo.
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              bottom: bajoLeyenda + (esAncho ? 0 : _altoLeyendaPlegada + 8),
              child: Column(
                children: [
                  _selectorVista(),
                  const SizedBox(height: 8),
                  _contador(visibles.length, _reportes.length),
                  const SizedBox(height: 8),
                  Flexible(child: _resumenDesplegable(esAncho)),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: bajoLeyenda,
              child: _leyenda(),
            ),
          ],
        );
      },
    );
  }
}
