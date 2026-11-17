import 'package:flutter/material.dart';

import '../../models/estadisticas_reportes.dart';
import '../../models/periodo_estadisticas.dart';
import '../../models/reporte.dart';
import '../../services/auth_service.dart';
import '../../services/estadisticas_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/filtros_reporte.dart';
import '../../widgets/etiqueta_estado.dart';
import '../../widgets/graficas_estadisticas.dart';
import '../../widgets/selector_periodo.dart';

/// Sección "Panel" del administrador: estadísticas de todo lo reportado
/// en el sistema. Solo se llega aquí desde AdminShell, que main.dart
/// muestra únicamente a usuarios con rol admin.
///
/// Este widget trae los datos de Firestore; lo que se dibuja está en
/// [PanelContenido], que no depende de Firebase.
class PanelScreen extends StatefulWidget {
  /// Se llama al tocar "Generar informe PDF", con el periodo elegido.
  final ValueChanged<PeriodoEstadisticas> onGenerarInforme;

  const PanelScreen({super.key, required this.onGenerarInforme});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  // Se crea una sola vez. Trae todos los reportes y el periodo se filtra
  // del lado del cliente, así cambiar de periodo no vuelve a consultar.
  late final Stream<List<Reporte>> _stream =
      FirestoreService().todosLosReportes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
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
            debugPrint('Error al cargar el panel: ${snapshot.error}');
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
          return PanelContenido(
            reportes: snapshot.data!,
            onGenerarInforme: widget.onGenerarInforme,
          );
        },
      ),
    );
  }
}

/// Dibuja el panel a partir de una lista de reportes ya descargada.
/// Cuenta los reportes en cualquier estado (incluidos los falsos, que se
/// ven aparte en la gráfica de distribución por estado).
class PanelContenido extends StatefulWidget {
  final List<Reporte> reportes;
  final ValueChanged<PeriodoEstadisticas> onGenerarInforme;

  /// Solo para tests: fija el "ahora" con el que se calculan los periodos.
  final DateTime? ahora;

  const PanelContenido({
    super.key,
    required this.reportes,
    required this.onGenerarInforme,
    this.ahora,
  });

  @override
  State<PanelContenido> createState() => _PanelContenidoState();
}

class _PanelContenidoState extends State<PanelContenido> {
  static const _servicio = EstadisticasService();
  static const _separacion = 12.0;

  PeriodoEstadisticas _periodo =
      const PeriodoEstadisticas(TipoPeriodo.ultimos30);

  @override
  Widget build(BuildContext context) {
    final reportes = widget.reportes;
    final ahora = widget.ahora ?? DateTime.now();

    // Fechas del reporte más antiguo y del más nuevo, para "Todo el
    // historial".
    DateTime? primero, ultimo;
    for (final r in reportes) {
      if (primero == null || r.fechaHora.isBefore(primero)) primero = r.fechaHora;
      if (ultimo == null || r.fechaHora.isAfter(ultimo)) ultimo = r.fechaHora;
    }
    final rango =
        _periodo.rango(ahora, primerReporte: primero, ultimoReporte: ultimo);

    final stats = _servicio.calcular(
      reportes,
      desde: rango.desde,
      hasta: rango.hasta,
      limiteColonias: 10,
    );
    final hallazgos = _servicio.generarHallazgos(
      reportes,
      desde: rango.desde,
      hasta: rango.hasta,
      etiquetaPeriodo: _periodo.etiquetaFrase,
    );
    // Pendientes de todo el sistema, no solo del periodo: es el trabajo
    // de moderación que falta.
    final pendientes =
        reportes.where((r) => r.estado == EstadoReporte.pendiente).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        // Una columna en celular y más conforme crece la pantalla.
        final columnasIndicadores = ancho < 600
            ? 1
            : ancho < 900
                ? 2
                : ancho < 1300
                    ? 3
                    : 5;
        final columnasGraficas = ancho < 700
            ? 1
            : ancho < 1150
                ? 2
                : 3;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _selectorPeriodo(),
                  const SizedBox(height: 16),
                  _Rejilla(
                    columnas: columnasIndicadores,
                    children: _indicadores(stats, pendientes),
                  ),
                  const SizedBox(height: _separacion),
                  _tarjetaHallazgos(hallazgos),
                  const SizedBox(height: _separacion),
                  if (stats.total == 0)
                    const Card(
                      child: MensajeCentrado(
                        icono: Icons.query_stats,
                        texto: 'No hay reportes en este periodo.\n'
                            'Prueba con un periodo más amplio.',
                      ),
                    )
                  else ...[
                    _Rejilla(
                      columnas: columnasGraficas,
                      children: _graficas(stats),
                    ),
                    const SizedBox(height: _separacion),
                    _tarjetaColonias(stats, columnas: ancho < 900 ? 1 : 2),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Selector de periodo y botón de informe
  // -------------------------------------------------------------------

  Widget _selectorPeriodo() {
    return SelectorPeriodo(
      periodo: _periodo,
      hoy: widget.ahora,
      onCambio: (periodo) => setState(() => _periodo = periodo),
      acciones: [
        FilledButton.tonalIcon(
          onPressed: () => widget.onGenerarInforme(_periodo),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Generar informe PDF'),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Tarjetas de indicadores
  // -------------------------------------------------------------------

  List<Widget> _indicadores(EstadisticasReportes stats, int pendientes) {
    final colores = Theme.of(context).colorScheme;
    final hayDatos = stats.total > 0;

    // Con empate gana la primera del enum.
    final categoria = CategoriaReporte.values.reduce(
      (a, b) => stats.porCategoria[b]! > stats.porCategoria[a]! ? b : a,
    );
    final franja = stats.porFranja.keys.reduce(
      (a, b) => stats.porFranja[b]! > stats.porFranja[a]! ? b : a,
    );
    final colonia = stats.topColonias.isEmpty ? null : stats.topColonias.first;

    return [
      _Indicador(
        icono: Icons.assignment,
        color: colores.primary,
        etiqueta: 'Total de reportes',
        valor: '${stats.total}',
        detalle: _textoCambio(stats),
      ),
      _Indicador(
        icono: infoEstado[EstadoReporte.pendiente]!.icono,
        color: infoEstado[EstadoReporte.pendiente]!.color,
        etiqueta: 'Pendientes de moderar',
        valor: '$pendientes',
        detalle: 'En todo el sistema',
      ),
      _Indicador(
        icono: hayDatos ? infoCategoria[categoria]!.icono : Icons.category,
        color: hayDatos ? colorPorCategoria(categoria) : colores.outline,
        etiqueta: 'Categoría más reportada',
        valor: hayDatos ? infoCategoria[categoria]!.nombre : '—',
        detalle: hayDatos ? _reportes(stats.porCategoria[categoria]!) : null,
      ),
      _Indicador(
        icono: Icons.location_on,
        color: colores.secondary,
        etiqueta: 'Colonia con más reportes',
        valor: colonia?.colonia ?? '—',
        detalle: colonia == null
            ? (hayDatos ? 'Sin colonia identificada' : null)
            : _reportes(colonia.conteo),
      ),
      _Indicador(
        icono: Icons.schedule,
        color: colores.tertiary,
        etiqueta: 'Franja horaria con más reportes',
        valor: hayDatos ? franja.etiqueta : '—',
        detalle: hayDatos ? _reportes(stats.porFranja[franja]!) : null,
      ),
    ];
  }

  String _textoCambio(EstadisticasReportes stats) {
    if (_periodo.tipo == TipoPeriodo.todo) return 'Todo el historial';
    final cambio = stats.cambioPorcentual;
    if (cambio == null) return 'Sin periodo anterior para comparar';
    final redondeado = cambio.round();
    if (redondeado == 0) return 'Sin cambio vs. periodo anterior';
    return '${redondeado > 0 ? '▲' : '▼'} ${redondeado.abs()} % '
        'vs. periodo anterior';
  }

  String _reportes(int n) => n == 1 ? '1 reporte' : '$n reportes';

  // -------------------------------------------------------------------
  // Hallazgos
  // -------------------------------------------------------------------

  Widget _tarjetaHallazgos(List<String> hallazgos) {
    final tema = Theme.of(context);
    return _Tarjeta(
      titulo: 'Hallazgos automáticos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hallazgos.isEmpty)
            const Text(
              'No hay suficientes reportes en este periodo para generar '
              'hallazgos.',
            ),
          for (final frase in hallazgos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(frase)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Basado en reportes ciudadanos; no son cifras oficiales.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Gráficas
  // -------------------------------------------------------------------

  List<Widget> _graficas(EstadisticasReportes stats) {
    final colores = Theme.of(context).colorScheme;
    const altoGrafica = 220.0;
    const franjasCortas = {
      FranjaHoraria.madrugada: 'Madrugada',
      FranjaHoraria.manana: 'Mañana',
      FranjaHoraria.tarde: 'Tarde',
      FranjaHoraria.noche: 'Noche',
    };
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const diasCompletos = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    return [
      _Tarjeta(
        titulo: 'Por categoría',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: altoGrafica,
              child: GraficaBarras(
                datos: [
                  for (final c in CategoriaReporte.values)
                    DatoBarra(
                      nombre: infoCategoria[c]!.nombre,
                      icono: infoCategoria[c]!.icono,
                      valor: stats.porCategoria[c]!,
                      color: colorPorCategoria(c),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LeyendaGrafica(
              datos: [
                for (final c in CategoriaReporte.values)
                  DatoLeyenda(
                    infoCategoria[c]!.nombre,
                    stats.porCategoria[c]!,
                    colorPorCategoria(c),
                  ),
              ],
            ),
          ],
        ),
      ),
      _Tarjeta(
        titulo: 'Por franja horaria',
        subtitulo: stats.horaPico == null
            ? null
            : 'Hora con más reportes: ${stats.horaPico}:00–'
                '${stats.horaPico! + 1}:00',
        child: SizedBox(
          height: altoGrafica,
          child: GraficaBarras(
            datos: [
              for (final f in stats.porFranja.keys)
                DatoBarra(
                  nombre: f.etiqueta,
                  etiqueta: franjasCortas[f],
                  valor: stats.porFranja[f]!,
                  color: colores.tertiary,
                ),
            ],
          ),
        ),
      ),
      _Tarjeta(
        titulo: 'Por día de la semana',
        child: SizedBox(
          height: altoGrafica,
          child: GraficaBarras(
            datos: [
              for (var d = 1; d <= 7; d++)
                DatoBarra(
                  nombre: diasCompletos[d - 1],
                  etiqueta: dias[d - 1],
                  valor: stats.porDiaSemana[d]!,
                  color: colores.secondary,
                ),
            ],
          ),
        ),
      ),
      _Tarjeta(
        titulo: 'Tendencia en el tiempo',
        subtitulo: stats.granularidad == GranularidadTendencia.dia
            ? 'Reportes por día'
            : 'Reportes por semana',
        child: SizedBox(
          height: altoGrafica,
          child: Padding(
            // Aire a la derecha para que no se corte la última fecha.
            padding: const EdgeInsets.only(right: 12),
            child: GraficaTendencia(
              puntos: stats.tendencia,
              granularidad: stats.granularidad,
            ),
          ),
        ),
      ),
      _Tarjeta(
        titulo: 'Distribución por estado',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: altoGrafica,
              child: GraficaEstados(porEstado: stats.porEstado),
            ),
            const SizedBox(height: 8),
            LeyendaGrafica(
              datos: [
                for (final e in EstadoReporte.values)
                  DatoLeyenda(
                    infoEstado[e]!.nombre,
                    stats.porEstado[e]!,
                    infoEstado[e]!.color,
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------
  // Top 10 colonias
  // -------------------------------------------------------------------

  Widget _tarjetaColonias(EstadisticasReportes stats, {required int columnas}) {
    final tema = Theme.of(context);
    final colonias = stats.topColonias;
    final maximo = colonias.isEmpty ? 1 : colonias.first.conteo;

    return _Tarjeta(
      titulo: 'Top 10 colonias',
      subtitulo: 'Colonias con más reportes y su desglose por categoría',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colonias.isEmpty)
            const Text('Ningún reporte del periodo tiene colonia identificada.')
          else
            _Rejilla(
              columnas: columnas,
              espacio: 16,
              children: [
                for (var i = 0; i < colonias.length; i++)
                  _FilaColonia(
                    posicion: i + 1,
                    colonia: colonias[i],
                    maximo: maximo,
                  ),
              ],
            ),
          if (stats.sinColonia > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${_reportes(stats.sinColonia)} sin colonia identificada '
              '${stats.sinColonia == 1 ? 'no entra' : 'no entran'} en el '
              'ranking.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reparte a sus hijos en [columnas] columnas del mismo ancho. A
/// diferencia de GridView, cada hijo conserva su alto natural y la
/// rejilla puede ir dentro de un scroll.
class _Rejilla extends StatelessWidget {
  final int columnas;
  final double espacio;
  final List<Widget> children;

  const _Rejilla({
    required this.columnas,
    required this.children,
    this.espacio = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // floor: evita que un redondeo mande la última columna abajo.
        final ancho =
            ((constraints.maxWidth - espacio * (columnas - 1)) / columnas)
                .floorToDouble();
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final hijo in children) SizedBox(width: ancho, child: hijo),
          ],
        );
      },
    );
  }
}

/// Tarjeta con título (y subtítulo opcional) para una sección del panel.
class _Tarjeta extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget child;

  const _Tarjeta({required this.titulo, this.subtitulo, required this.child});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: tema.textTheme.titleMedium),
            if (subtitulo != null)
              Text(
                subtitulo!,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de indicador: ícono, etiqueta, valor grande y un detalle.
class _Indicador extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String etiqueta;
  final String valor;
  final String? detalle;

  const _Indicador({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.valor,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gris = tema.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        // Alto fijo para que todas las tarjetas de una fila se alineen.
        height: 104,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: gris),
                    ),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (detalle != null)
                      Text(
                        detalle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: gris),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renglón del top de colonias: posición, nombre, total y una barra
/// dividida por categoría (cada tramo con el color de su categoría).
class _FilaColonia extends StatelessWidget {
  final int posicion;
  final ConteoColonia colonia;

  /// Conteo de la colonia con más reportes; su barra ocupa todo el ancho
  /// y las demás son proporcionales.
  final int maximo;

  const _FilaColonia({
    required this.posicion,
    required this.colonia,
    required this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final desglose = colonia.porCategoria.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$posicion.',
                style: tema.textTheme.titleSmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                colonia.colonia,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${colonia.conteo}',
              style: tema.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: colonia.conteo / maximo,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                for (final e in desglose)
                  Expanded(
                    flex: e.value,
                    child: Container(
                      height: 10,
                      color: colorPorCategoria(e.key),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desglose
              .map((e) => '${infoCategoria[e.key]!.nombre} ${e.value}')
              .join(' · '),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
