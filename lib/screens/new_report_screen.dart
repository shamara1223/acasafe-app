import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/reporte.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// Formulario de "nuevo reporte". El flujo es:
/// 1. Elegir tipo (bache, robo, inundación, etc.)
/// 2. Tomar/elegir foto (opcional)
/// 3. Obtener la ubicación del dispositivo automáticamente
/// 4. Escribir una breve descripción
/// 5. Guardar en Firestore con estado "pendiente"
///
/// El filtro anti-reportes-falsos (TODO del equipo) se conecta aquí:
/// por ahora todo entra como "pendiente" y se modera manualmente o por
/// votos de la comunidad (ver FirestoreService.votar).
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _authService = AuthService();

  CategoriaReporte? _categoriaSeleccionada;
  String? _tipoSeleccionado;
  Uint8List? _foto;
  Position? _ubicacionActual;
  String _colonia = '';
  bool _guardando = false;
  bool _obteniendoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      final permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _avisarUbicacionNoDisponible();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      // Se guarda la posición antes del geocoding para no perderla si
      // este falla (en web, geocoding no tiene implementación).
      setState(() => _ubicacionActual = pos);

      var colonia = 'Acapulco de Juárez';
      if (!kIsWeb) {
        try {
          final lugares = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (lugares.isNotEmpty) {
            colonia = lugares.first.subLocality?.isNotEmpty == true
                ? lugares.first.subLocality!
                : lugares.first.locality ?? 'Acapulco de Juárez';
          }
        } catch (_) {
          // Sin colonia exacta; se queda el valor por defecto.
        }
      }
      if (!mounted) return;
      setState(() => _colonia = colonia);
    } catch (_) {
      _avisarUbicacionNoDisponible();
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  void _avisarUbicacionNoDisponible() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo obtener tu ubicación. Revisa los permisos de ubicación.',
        ),
      ),
    );
  }

  Future<void> _elegirFoto() async {
    final picker = ImagePicker();
    final archivo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (archivo != null) {
      final bytes = await archivo.readAsBytes();
      setState(() => _foto = bytes);
    }
  }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaSeleccionada == null || _tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige la categoría y el tipo de incidencia.'),
        ),
      );
      return;
    }
    if (_ubicacionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía no tenemos tu ubicación, espera un momento.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      // La subida de foto se intenta aparte: si Storage todavía no está
      // activo en el proyecto de Firebase (ej. mientras se resuelve la
      // cuenta de facturación), el reporte se guarda igual, solo sin
      // foto, en vez de bloquear por completo el envío.
      String? fotoUrl;
      if (_foto != null) {
        try {
          fotoUrl = await _storageService.subirFotoReporte(_foto!);
        } catch (e) {
          debugPrint('Error al subir la foto del reporte: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo subir la foto (Storage no disponible todavía). '
                  'El reporte se guardará sin foto.',
                ),
              ),
            );
          }
        }
      }

      final reporte = Reporte(
        tipo: _tipoSeleccionado!,
        categoria: tiposDeReporte[_tipoSeleccionado]!,
        colonia: _colonia,
        ubicacion: GeoPoint(
          _ubicacionActual!.latitude,
          _ubicacionActual!.longitude,
        ),
        descripcion: _descripcionCtrl.text.trim(),
        fotoUrl: fotoUrl,
        fechaHora: DateTime.now(),
        usuarioId: _authService.usuarioActual?.uid ?? 'anonimo',
      );

      await _firestoreService.crearReporte(reporte);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el reporte: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo reporte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '¿Qué tipo de incidencia es?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            // Primero la categoría; el dropdown de abajo solo muestra los
            // tipos de la categoría elegida.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoriaReporte.values.map((c) {
                final color = colorPorCategoria(c);
                final elegida = _categoriaSeleccionada == c;
                return ChoiceChip(
                  avatar: Icon(
                    infoCategoria[c]!.icono,
                    size: 18,
                    color: elegida ? Colors.white : color,
                  ),
                  label: Text(infoCategoria[c]!.nombre),
                  selected: elegida,
                  showCheckmark: false,
                  selectedColor: color,
                  labelStyle: TextStyle(color: elegida ? Colors.white : null),
                  side: BorderSide(color: color),
                  onSelected: (_) {
                    if (elegida) return;
                    final tipos = tiposDeCategoria(c);
                    setState(() {
                      _categoriaSeleccionada = c;
                      // Si la categoría solo tiene un tipo (ej. "Otro"),
                      // se elige solo.
                      _tipoSeleccionado = tipos.length == 1 ? tipos.first : null;
                    });
                  },
                );
              }).toList(),
            ),
            if (_categoriaSeleccionada != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // La key fuerza a recrear el campo al cambiar de categoría,
                // para que no conserve un tipo de otra categoría.
                key: ValueKey(_categoriaSeleccionada),
                initialValue: _tipoSeleccionado,
                decoration: const InputDecoration(labelText: '¿Qué pasó?'),
                items: tiposDeCategoria(_categoriaSeleccionada!)
                    .map((clave) => DropdownMenuItem(
                          value: clave,
                          child: Text(nombreTipoReporte[clave] ?? clave),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipoSeleccionado = v),
                validator: (v) => v == null ? 'Elige un tipo' : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe brevemente lo que viste',
                hintText: 'Ej. Bache grande sobre el carril derecho',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe una descripción' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_foto == null ? 'Agregar foto' : 'Cambiar foto'),
                  ),
                ),
              ],
            ),
            if (_foto != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_foto!, height: 160, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              leading: _obteniendoUbicacion
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              title: Text(_colonia.isEmpty ? 'Obteniendo ubicación…' : _colonia),
              subtitle: const Text('Colonia detectada automáticamente'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardarReporte,
              child: Text(_guardando ? 'Guardando…' : 'Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }
}
