import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../models/opciones_informe.dart';
import '../../models/periodo_estadisticas.dart';
import '../../models/reporte.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/constants.dart';
import '../../widgets/etiqueta_estado.dart';
import '../../widgets/selector_periodo.dart';

/// Genera el PDF de un informe ya calculado.
typedef GenerarPdf = Future<Uint8List> Function(DatosInforme datos);

/// Entrega el PDF al usuario (descarga en web, compartir en móvil).
typedef DescargarPdf = Future<void> Function(Uint8List bytes, String nombre);

/// Sección "Informes" del administrador: configurador del informe PDF.
/// Solo se llega aquí desde AdminShell, que main.dart muestra únicamente
/// a usuarios con rol admin.
///
/// Este widget trae los datos de Firestore y el correo del admin; lo que
/// se dibuja está en [InformesContenido], que no depende de Firebase.
class InformesScreen extends StatefulWidget {
  /// Periodo que mandó el Panel con "Generar informe PDF" (o null).
  final PeriodoEstadisticas? periodoInicial;

  /// Cambia cada vez que el Panel manda un periodo, aunque sea el mismo,
  /// para volver a preseleccionarlo.
  final int versionPeriodo;

  const InformesScreen({
    super.key,
    this.periodoInicial,
    this.versionPeriodo = 0,
  });

  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen> {
  // Se crea una sola vez; el filtrado se hace del lado del cliente.
  late final Stream<List<Reporte>> _stream =
      FirestoreService().todosLosReportes();

  @override
  Widget build(BuildContext context) {
    final correo = AuthService().usuarioActual?.email ?? 'Administrador';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes'),
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
            debugPrint('Error al cargar los informes: ${snapshot.error}');
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
          return InformesContenido(
            reportes: snapshot.data!,
            correoAdmin: correo,
            periodoInicial: widget.periodoInicial,
            versionPeriodo: widget.versionPeriodo,
          );
        },
      ),
    );
  }
}

/// Configurador del informe a partir de una lista de reportes ya
/// descargada.
class InformesContenido extends StatefulWidget {
  final List<Reporte> reportes;
  final String correoAdmin;
  final PeriodoEstadisticas? periodoInicial;
  final int versionPeriodo;

  /// Solo para tests: fija el "ahora" de los periodos y del nombre del
  /// archivo.
  final DateTime? ahora;

  /// Solo para tests: reemplazan la generación y la descarga reales.
  final GenerarPdf? generarPdf;
  final DescargarPdf? descargarPdf;

  const InformesContenido({
    super.key,
    required this.reportes,
    required this.correoAdmin,
    this.periodoInicial,
    this.versionPeriodo = 0,
    this.ahora,
    this.generarPdf,
    this.descargarPdf,
  });

  @override
  State<InformesContenido> createState() => _InformesContenidoState();
}

class _InformesContenidoState extends State<InformesContenido> {
  static const _separacion = 12.0;

  /// Un PDF ya generado se reutiliza si no cambió nada, pero no más de
  /// este tiempo (los periodos de N días terminan "ahora").
  static const _vigenciaPdf = Duration(minutes: 5);

  late OpcionesInforme _opciones =
      OpcionesInforme(periodo: widget.periodoInicial ?? _periodoPorDefecto);
  final _tituloCtrl = TextEditingController();

  bool _generando = false;
  String? _error;

  // Último PDF generado y con qué se generó.
  Uint8List? _pdf;
  OpcionesInforme? _pdfOpciones;
  List<Reporte>? _pdfReportes;
  DateTime? _pdfHora;

  static const _periodoPorDefecto = PeriodoEstadisticas(TipoPeriodo.ultimos30);

  DateTime get _ahora => widget.ahora ?? DateTime.now();

  @override
  void didUpdateWidget(InformesContenido anterior) {
    super.didUpdateWidget(anterior);
    // El Panel mandó un periodo nuevo: se preselecciona sin perder el
    // resto de la configuración.
    if (widget.versionPeriodo != anterior.versionPeriodo &&
        widget.periodoInicial != null) {
      _opciones = _opciones.copyWith(periodo: widget.periodoInicial);
      _error = null;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  void _cambiar(OpcionesInforme opciones) {
    setState(() {
      _opciones = opciones;
      _error = null;
    });
  }

  Future<Uint8List> _generarReal(DatosInforme datos) {
    return const PdfService().generar(
      datos,
      correoAdmin: widget.correoAdmin,
      generadoEl: DateTime.now(),
    );
  }

  /// Genera el PDF (o reutiliza el último si nada cambió). Regresa null y
  /// muestra el error si falla.
  Future<Uint8List?> _obtenerPdf(DatosInforme datos) async {
    final previo = _pdf;
    if (previo != null &&
        identical(_pdfOpciones, _opciones) &&
        identical(_pdfReportes, widget.reportes) &&
        DateTime.now().difference(_pdfHora!) < _vigenciaPdf) {
      return previo;
    }

    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      // Deja que se pinte el indicador de carga antes del trabajo pesado
      // (en web todo corre en un solo hilo).
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await (widget.generarPdf ?? _generarReal)(datos);
      _pdf = bytes;
      _pdfOpciones = datos.opciones;
      _pdfReportes = widget.reportes;
      _pdfHora = DateTime.now();
      return bytes;
    } catch (e, pila) {
      debugPrint('Error al generar el PDF: $e\n$pila');
      if (mounted) {
        setState(() => _error = 'No se pudo generar el PDF. Intenta de nuevo.');
      }
      return null;
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _vistaPrevia(DatosInforme datos) async {
    final bytes = await _obtenerPdf(datos);
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VistaPreviaInformeScreen(
          bytes: bytes,
          nombreArchivo: PdfService.nombreArchivo(_ahora),
          descargarPdf: widget.descargarPdf,
        ),
      ),
    );
  }

  Future<void> _descargar(DatosInforme datos) async {
    final bytes = await _obtenerPdf(datos);
    if (bytes == null || !mounted) return;
    await _entregarPdf(
      context,
      bytes,
      PdfService.nombreArchivo(_ahora),
      widget.descargarPdf,
    );
  }

  @override
  Widget build(BuildContext context) {
    DatosInforme? datos;
    try {
      datos = DatosInforme.calcular(widget.reportes, _opciones, ahora: _ahora);
    } catch (e) {
      debugPrint('Error al calcular las estadísticas del informe: $e');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth >= 900;
        final izquierda = [
          _tarjetaPeriodo(datos),
          const SizedBox(height: _separacion),
          _tarjetaCategorias(),
          const SizedBox(height: _separacion),
          _tarjetaTitulo(),
        ];
        final derecha = [
          _tarjetaSecciones(),
          const SizedBox(height: _separacion),
          _tarjetaGenerar(datos),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: ancho
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: izquierda,
                          ),
                        ),
                        const SizedBox(width: _separacion),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: derecha,
                          ),
                        ),
                      ],
                    )
                  // En celular el resumen con los botones va al final.
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...izquierda,
                        const SizedBox(height: _separacion),
                        ...derecha,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Tarjetas del formulario
  // -------------------------------------------------------------------

  Widget _tarjetaPeriodo(DatosInforme? datos) {
    final formato = DateFormat('d MMM y', 'es_MX');
    final tema = Theme.of(context);
    return _Tarjeta(
      titulo: '1. Periodo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectorPeriodo(
            periodo: _opciones.periodo,
            hoy: widget.ahora,
            onCambio: (p) => _cambiar(_opciones.copyWith(periodo: p)),
          ),
          if (datos != null) ...[
            const SizedBox(height: 8),
            Text(
              'Del ${formato.format(datos.rango.desde)} al '
              '${formato.format(datos.rango.hasta.subtract(const Duration(milliseconds: 1)))}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaCategorias() {
    final seleccion = _opciones.categorias;
    return _Tarjeta(
      titulo: '2. Categorías y reportes falsos',
      acciones: [
        TextButton(
          onPressed: _opciones.todasLasCategorias
              ? null
              : () => _cambiar(_opciones.copyWith(
                    categorias: CategoriaReporte.values.toSet(),
                  )),
          child: const Text('Todas'),
        ),
        TextButton(
          onPressed: seleccion.isEmpty
              ? null
              : () => _cambiar(_opciones.copyWith(categorias: {})),
          child: const Text('Ninguna'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in CategoriaReporte.values)
                FilterChip(
                  avatar: Icon(
                    infoCategoria[c]!.icono,
                    size: 18,
                    color: colorPorCategoria(c),
                  ),
                  label: Text(infoCategoria[c]!.nombre),
                  selected: seleccion.contains(c),
                  showCheckmark: false,
                  onSelected: (marcada) {
                    final nuevas = {...seleccion};
                    marcada ? nuevas.add(c) : nuevas.remove(c);
                    _cambiar(_opciones.copyWith(categorias: nuevas));
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incluir reportes marcados como falsos'),
            subtitle: const Text(
              'Normalmente se excluyen: un admin ya los revisó y no '
              'ocurrieron.',
            ),
            value: _opciones.incluirFalsos,
            onChanged: (v) => _cambiar(_opciones.copyWith(incluirFalsos: v)),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaTitulo() {
    return _Tarjeta(
      titulo: '3. Título (opcional)',
      child: TextField(
        controller: _tituloCtrl,
        maxLength: 100,
        decoration: const InputDecoration(
          hintText: OpcionesInforme.tituloPorDefecto,
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (t) => _cambiar(_opciones.copyWith(titulo: t)),
      ),
    );
  }

  Widget _tarjetaSecciones() {
    final secciones = _opciones.secciones;
    return _Tarjeta(
      titulo: '4. Secciones',
      acciones: [
        TextButton(
          onPressed: secciones.length == SeccionInforme.values.length
              ? null
              : () => _cambiar(_opciones.copyWith(
                    secciones: SeccionInforme.values.toSet(),
                  )),
          child: const Text('Todas'),
        ),
        TextButton(
          onPressed: secciones.isEmpty
              ? null
              : () => _cambiar(_opciones.copyWith(secciones: {})),
          child: const Text('Ninguna'),
        ),
      ],
      child: Column(
        children: [
          for (final s in SeccionInforme.values)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s.titulo),
              value: secciones.contains(s),
              onChanged: (marcada) {
                final nuevas = {...secciones};
                marcada == true ? nuevas.add(s) : nuevas.remove(s);
                _cambiar(_opciones.copyWith(secciones: nuevas));
              },
            ),
        ],
      ),
    );
  }

  Widget _tarjetaGenerar(DatosInforme? datos) {
    final tema = Theme.of(context);

    if (datos == null) {
      return const _Tarjeta(
        titulo: 'Generar',
        child: MensajeCentrado(
          icono: Icons.error_outline,
          texto: 'No se pudieron calcular las estadísticas del informe.',
        ),
      );
    }

    final total = datos.total;
    final String? motivo = _opciones.categorias.isEmpty
        ? 'Elige al menos una categoría.'
        : total == 0
            ? 'Ningún reporte cumple los criterios. Prueba con un periodo '
                'más amplio u otras categorías.'
            : _opciones.secciones.isEmpty
                ? 'Elige al menos una sección.'
                : null;
    final habilitado = motivo == null && !_generando;

    return _Tarjeta(
      titulo: 'Generar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '$total',
                key: const ValueKey('conteo-informe'),
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: total == 0
                      ? tema.colorScheme.outline
                      : tema.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  total == 1
                      ? 'reporte cumple los criterios'
                      : 'reportes cumplen los criterios',
                ),
              ),
            ],
          ),
          if (motivo != null) ...[
            const SizedBox(height: 8),
            Text(
              motivo,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: habilitado ? () => _vistaPrevia(datos) : null,
                icon: const Icon(Icons.visibility),
                label: const Text('Vista previa'),
              ),
              FilledButton.icon(
                onPressed: habilitado ? () => _descargar(datos) : null,
                icon: const Icon(Icons.download),
                label: const Text('Descargar PDF'),
              ),
            ],
          ),
          if (_generando) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Generando el PDF…'),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.error_outline, color: tema.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Descarga el PDF. En web (Chrome y Safari de iPhone) printing crea un
/// enlace de descarga con el nombre de archivo; en Android/iOS abre el
/// menú de compartir para guardarlo.
Future<void> _entregarPdf(
  BuildContext context,
  Uint8List bytes,
  String nombre,
  DescargarPdf? descargarPdf,
) async {
  final mensajero = ScaffoldMessenger.of(context);
  try {
    if (descargarPdf != null) {
      await descargarPdf(bytes, nombre);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: nombre);
    }
  } catch (e) {
    debugPrint('Error al descargar el PDF: $e');
    mensajero.showSnackBar(
      const SnackBar(content: Text('No se pudo descargar el PDF.')),
    );
  }
}

/// Vista previa del informe con PdfPreview (en web usa pdf.js para
/// dibujar las páginas). Trae botones para imprimir y descargar.
class VistaPreviaInformeScreen extends StatelessWidget {
  final Uint8List bytes;
  final String nombreArchivo;
  final DescargarPdf? descargarPdf;

  const VistaPreviaInformeScreen({
    super.key,
    required this.bytes,
    required this.nombreArchivo,
    this.descargarPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () =>
                  _entregarPdf(context, bytes, nombreArchivo, descargarPdf),
              icon: const Icon(Icons.download),
              label: const Text('Descargar PDF'),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: nombreArchivo,
        allowPrinting: true,
        // La descarga va en la barra superior, con el mismo nombre.
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => const MensajeCentrado(
          icono: Icons.error_outline,
          texto: 'No se pudo mostrar la vista previa.\n'
              'Puedes descargar el PDF con el botón de arriba.',
        ),
      ),
    );
  }
}

/// Tarjeta con título y acciones opcionales, igual a las del Panel.
class _Tarjeta extends StatelessWidget {
  final String titulo;
  final List<Widget> acciones;
  final Widget child;

  const _Tarjeta({
    required this.titulo,
    required this.child,
    this.acciones = const [],
  });

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
            Row(
              children: [
                Expanded(
                  child: Text(titulo, style: tema.textTheme.titleMedium),
                ),
                ...acciones,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
