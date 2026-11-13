import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// Convierte coordenadas en el nombre de la colonia (reverse geocoding).
/// - En móvil usa el paquete `geocoding` (geocoder nativo del sistema).
/// - En web ese paquete no tiene implementación, así que se consulta
///   Nominatim (OpenStreetMap) por HTTP.
/// Si algo falla, regresa [coloniaPorDefecto] en vez de lanzar un error:
/// un reporte nunca se bloquea por no tener colonia exacta.
class GeocodificacionService {
  static const _tiempoLimite = Duration(seconds: 8);

  final http.Client? _cliente;

  /// [cliente] solo se pasa en los tests, para simular a Nominatim.
  GeocodificacionService({http.Client? cliente}) : _cliente = cliente;

  Future<String> coloniaDesdeCoordenadas(double lat, double lng) {
    return kIsWeb ? coloniaConNominatim(lat, lng) : _coloniaConGeocoding(lat, lng);
  }

  /// Reverse geocoding con Nominatim. Es público para poder probarlo.
  Future<String> coloniaConNominatim(double lat, double lng) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lng',
      'zoom': '16',
      'accept-language': 'es',
    });
    try {
      final respuesta =
          await (_cliente?.get(url) ?? http.get(url)).timeout(_tiempoLimite);
      if (respuesta.statusCode != 200) return coloniaPorDefecto;
      // utf8.decode sobre los bytes: `respuesta.body` puede romper los
      // acentos si el servidor no declara el charset.
      return coloniaDesdeRespuestaNominatim(utf8.decode(respuesta.bodyBytes)) ??
          coloniaPorDefecto;
    } catch (_) {
      // Sin red, timeout o respuesta inválida: valor por defecto.
      return coloniaPorDefecto;
    }
  }

  Future<String> _coloniaConGeocoding(double lat, double lng) async {
    try {
      final lugares = await placemarkFromCoordinates(lat, lng);
      if (lugares.isEmpty) return coloniaPorDefecto;
      final subLocalidad = lugares.first.subLocality;
      if (subLocalidad != null && subLocalidad.isNotEmpty) return subLocalidad;
      return lugares.first.locality ?? coloniaPorDefecto;
    } catch (_) {
      // Sin colonia exacta; se queda el valor por defecto.
      return coloniaPorDefecto;
    }
  }
}

/// Extrae la colonia del JSON que regresa Nominatim: el primer valor
/// disponible entre suburb, neighbourhood, quarter y city_district.
/// Regresa null si no viene ninguno o el JSON no tiene la forma esperada.
String? coloniaDesdeRespuestaNominatim(String cuerpo) {
  final Object? json;
  try {
    json = jsonDecode(cuerpo);
  } on FormatException {
    return null;
  }
  if (json is! Map) return null;
  final direccion = json['address'];
  if (direccion is! Map) return null;

  for (final campo in const [
    'suburb',
    'neighbourhood',
    'quarter',
    'city_district',
  ]) {
    final valor = direccion[campo];
    if (valor is String && valor.trim().isNotEmpty) return valor.trim();
  }
  return null;
}
