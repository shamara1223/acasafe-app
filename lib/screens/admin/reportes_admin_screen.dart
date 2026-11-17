import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reporte.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/filtros_reportes_admin.dart';
import '../../utils/selector_fechas.dart';
import '../../widgets/etiqueta_estado.dart';

/// Guarda el nuevo estado de un reporte. Debe lanzar un error si falla.
typedef CambiarEstado = Future<void> Function(
  Reporte reporte,
  EstadoReporte nuevoEstado,
);

/// Sección "Reportes" del administrador: todos los reportes del sistema,
/// con búsqueda, filtros y cambio de estado. Solo se llega aquí desde
/// AdminShell, que main.dart muestra únicamente a usuarios con rol admin;
/// además, las reglas de Firestore rechazan el cambio de estado si quien
/// lo pide no es admin.
///
/// Este widget trae los datos de Firestore; lo que se dibuja está en
/// [ReportesAdminContenido], que no depende de Firebase.
class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key});

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen> {
  final _firestoreService = FirestoreService();

  // Se crea una sola vez para no volver a suscribirse en cada build.
  late final Stream<List<Reporte>> _stream =
      _firestoreService.todosLosReportes();

  // Actualiza solo el campo 'estado' (ver FirestoreService), que es lo
  // único que las reglas de Firestore le permiten cambiar a un admin
  // además de los votos.
  Future<void> _cambiarEstado(Reporte reporte, EstadoReporte nuevoEstado) {
    return _firestoreService.actualizarEstado(
      reporteId: reporte.id!,
      nuevoEstado: nuevoEstado,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: StreamBuilder<List<Reporte>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Error al cargar los reportes: ${snapshot.error}');
            return const MensajeCentrado(
              icono: Icons.error_outline,
              texto: 'No se pudieron cargar los reportes.\n'
                  'Revisa tu conexión e intenta de nuevo.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const MensajeCentrado(
              icono: Icons.inbox_outlined,
              texto: 'Todavía no hay reportes en el sistema.',
            );
          }
          return ReportesAdminContenido(
            reportes: snapshot.data!,
            onCambiarEstado: _cambiarEstado,
          );
        },
      ),
    );
  }
}

/// Búsqueda, filtros y lista de reportes, a partir de una lista ya
/// descargada (del más reciente al más antiguo).
class ReportesAdminContenido extends StatefulWidget {
  final List<Reporte> reportes;
  final CambiarEstado onCambiarEstado;

  const ReportesAdminContenido({
    super.key,
    required this.reportes,
    required this.onCambiarEstado,
  });

  @override
  State<ReportesAdminContenido> createState() => _ReportesAdminContenidoState();
}

class _ReportesAdminContenidoState extends State<ReportesAdminContenido> {
  final _busquedaCtrl = TextEditingController();

  CategoriaReporte? _categoria;
  EstadoReporte? _estado;
  DateTimeRange? _fechas;

  // Cambia al limpiar los filtros, para recrear los dropdowns (solo leen
  // su valor inicial al crearse).
  int _versionFiltros = 0;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFechas() async {
    final rango = await elegirRangoFechas(context, inicial: _fechas);
    if (rango == null || !mounted) return;
    setState(() => _fechas = rango);
  }

  void _limpiarFiltros() {
    setState(() {
      _busquedaCtrl.clear();
      _categoria = null;
      _estado = null;
      _fechas = null;
      _versionFiltros++;
    });
  }

  void _abrirDetalle(Reporte reporte) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReporteAdminDetalleScreen(
          reporte: reporte,
          onCambiarEstado: widget.onCambiarEstado,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final filtros = FiltrosReportesAdmin(
      texto: _busquedaCtrl.text,
      categoria: _categoria,
      estado: _estado,
      primerDia: _fechas?.start,
      ultimoDia: _fechas?.end,
    );
    final visibles = filtros.aplicar(widget.reportes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _barraFiltros(filtros),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            filtros.estaActivo
                ? '${visibles.length} de ${widget.reportes.length} reportes'
                : '${widget.reportes.length} reportes',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? const MensajeCentrado(
                  icono: Icons.search_off,
                  texto: 'Ningún reporte coincide con la búsqueda o los '
                      'filtros.',
                )
              // Una columna en celular y varias en pantallas anchas: las
              // tarjetas miden hasta 460 px de ancho.
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (context, i) => _TarjetaReporte(
                    reporte: visibles[i],
                    onTap: () => _abrirDetalle(visibles[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _barraFiltros(FiltrosReportesAdmin filtros) {
    final formato = DateFormat('d MMM y', 'es_MX');
    const borde = OutlineInputBorder();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busquedaCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por tipo, colonia o descripción',
            prefixIcon: const Icon(Icons.search),
            border: borde,
            isDense: true,
            suffixIcon: _busquedaCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Borrar búsqueda',
                    onPressed: () => setState(_busquedaCtrl.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<CategoriaReporte?>(
                key: ValueKey('categoria-$_versionFiltros'),
                initialValue: _categoria,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: borde,
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final c in CategoriaReporte.values)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        infoCategoria[c]!.nombre,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _categoria = v),
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<EstadoReporte?>(
                key: ValueKey('estado-$_versionFiltros'),
                initialValue: _estado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: borde,
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final e in EstadoReporte.values)
                    DropdownMenuItem(
                      value: e,
                      child: Text(infoEstado[e]!.nombre),
                    ),
                ],
                onChanged: (v) => setState(() => _estado = v),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _elegirFechas,
              icon: const Icon(Icons.date_range),
              label: Text(
                _fechas == null
                    ? 'Fechas'
                    : '${formato.format(_fechas!.start)} – '
                        '${formato.format(_fechas!.end)}',
              ),
            ),
            if (filtros.estaActivo)
              TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Limpiar filtros'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tarjeta de un reporte en la lista: categoría, tipo, colonia, fecha,
/// inicio de la descripción y etiqueta con su estado.
class _TarjetaReporte extends StatelessWidget {
  final Reporte reporte;
  final VoidCallback onTap;

  const _TarjetaReporte({required this.reporte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gris = tema.colorScheme.onSurfaceVariant;
    final formato = DateFormat('d MMM y, HH:mm', 'es_MX');
    final colonia =
        reporte.colonia.trim().isEmpty ? 'Sin colonia' : reporte.colonia.trim();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorPorCategoria(reporte.categoria),
                    child: Icon(
                      infoCategoria[reporte.categoria]!.icono,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreTipoReporte[reporte.tipo] ?? reporte.tipo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.titleSmall,
                        ),
                        Text(
                          '$colonia · ${formato.format(reporte.fechaHora)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(color: gris),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  EtiquetaEstado(reporte.estado),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reporte.descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle completo de un reporte para el administrador, con el control
/// para cambiar su estado (pide confirmación antes de guardar).
class ReporteAdminDetalleScreen extends StatefulWidget {
  final Reporte reporte;
  final CambiarEstado onCambiarEstado;

  const ReporteAdminDetalleScreen({
    super.key,
    required this.reporte,
    required this.onCambiarEstado,
  });

  @override
  State<ReporteAdminDetalleScreen> createState() =>
      _ReporteAdminDetalleScreenState();
}

class _ReporteAdminDetalleScreenState extends State<ReporteAdminDetalleScreen> {
  // El reporte que recibe la pantalla es una foto del momento en que se
  // abrió; el estado se guarda aparte para reflejar el cambio al guardar.
  late EstadoReporte _estado = widget.reporte.estado;
  bool _guardando = false;

  String get _nombreTipo =>
      nombreTipoReporte[widget.reporte.tipo] ?? widget.reporte.tipo;

  Future<void> _pedirCambio(EstadoReporte nuevo) async {
    if (nuevo == _estado || _guardando) return;

    final anterior = _estado;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambiar el estado?'),
        content: Text(
          'El reporte «$_nombreTipo» pasará de '
          '${infoEstado[anterior]!.nombre} a ${infoEstado[nuevo]!.nombre}.'
          '${_avisoCambio(nuevo)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cambiar estado'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await widget.onCambiarEstado(widget.reporte, nuevo);
      if (!mounted) return;
      setState(() => _estado = nuevo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado cambiado a ${infoEstado[nuevo]!.nombre}.'),
        ),
      );
    } catch (e) {
      debugPrint('Error al cambiar el estado del reporte: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar el estado. Revisa tu conexión y que tu '
            'cuenta tenga rol de administrador.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // Consecuencia visible del cambio: el mapa solo muestra reportes
  // pendientes y verificados (ver FirestoreService.reportesRecientes).
  String _avisoCambio(EstadoReporte nuevo) {
    switch (nuevo) {
      case EstadoReporte.falso:
      case EstadoReporte.resuelto:
        return '\n\nDejará de mostrarse en el mapa.';
      case EstadoReporte.pendiente:
      case EstadoReporte.verificado:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = widget.reporte;
    final formato = DateFormat("EEEE d 'de' MMMM 'de' y, HH:mm", 'es_MX');

    return Scaffold(
      appBar: AppBar(title: Text(_nombreTipo)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Wrap y no Row: con letra grande (accesibilidad) pasa a
              // otra línea en vez de desbordarse.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Estado actual:', style: tema.textTheme.titleSmall),
                  EtiquetaEstado(_estado),
                  if (_guardando)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Cambiar estado', style: tema.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in EstadoReporte.values)
                    ChoiceChip(
                      avatar: Icon(
                        infoEstado[e]!.icono,
                        size: 18,
                        color: infoEstado[e]!.color,
                      ),
                      showCheckmark: false,
                      label: Text(infoEstado[e]!.nombre),
                      selected: e == _estado,
                      onSelected: _guardando ? null : (_) => _pedirCambio(e),
                    ),
                ],
              ),
              const Divider(height: 32),
              if (r.fotoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    r.fotoUrl!,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 60,
                      child: Center(child: Text('No se pudo cargar la foto.')),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Descripción', style: tema.textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(r.descripcion, style: tema.textTheme.bodyLarge),
              const SizedBox(height: 16),
              _Campo(
                icono: infoCategoria[r.categoria]!.icono,
                colorIcono: colorPorCategoria(r.categoria),
                etiqueta: 'Categoría y tipo',
                valor: '${infoCategoria[r.categoria]!.nombre} · $_nombreTipo',
              ),
              _Campo(
                icono: Icons.location_on,
                etiqueta: 'Colonia',
                valor: r.colonia.trim().isEmpty ? 'Sin colonia' : r.colonia,
              ),
              _Campo(
                icono: Icons.my_location,
                etiqueta: 'Coordenadas',
                valor: '${r.ubicacion.latitude.toStringAsFixed(5)}, '
                    '${r.ubicacion.longitude.toStringAsFixed(5)}',
              ),
              _Campo(
                icono: Icons.event,
                etiqueta: 'Fecha y hora',
                valor: formato.format(r.fechaHora),
              ),
              _Campo(
                icono: Icons.how_to_vote,
                etiqueta: 'Votos de la comunidad',
                valor: 'Sigue vigente: ${r.votosUtil} · '
                    'Ya no / falso: ${r.votosFalso}',
              ),
              _Campo(
                icono: Icons.person,
                etiqueta: 'Usuario que reportó (uid)',
                valor: r.usuarioId,
              ),
              if (r.id != null)
                _Campo(
                  icono: Icons.tag,
                  etiqueta: 'ID del reporte',
                  valor: r.id!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renglón "etiqueta / valor" del detalle. El valor se puede seleccionar
/// para copiarlo (útil para el uid y el ID).
class _Campo extends StatelessWidget {
  final IconData icono;
  final Color? colorIcono;
  final String etiqueta;
  final String valor;

  const _Campo({
    required this.icono,
    this.colorIcono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gris = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: colorIcono ?? gris),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: tema.textTheme.bodySmall?.copyWith(color: gris),
                ),
                SelectableText(valor, style: tema.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
