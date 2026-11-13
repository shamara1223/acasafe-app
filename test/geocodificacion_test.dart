// Tests del reverse geocoding con Nominatim (la rama que se usa en web).
// Nominatim se simula con MockClient: no se hace ninguna petición real.

import 'dart:convert';

import 'package:acasafe/services/geocodificacion_service.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _respuesta(Map<String, dynamic> direccion) {
  return http.Response.bytes(
    utf8.encode(jsonEncode({'address': direccion})),
    200,
  );
}

void main() {
  group('coloniaDesdeRespuestaNominatim', () {
    test('toma el primer campo disponible, en orden de prioridad', () {
      expect(
        coloniaDesdeRespuestaNominatim(jsonEncode({
          'address': {
            'city_district': 'Distrito',
            'quarter': 'Cuartel',
            'neighbourhood': 'Barrio',
            'suburb': 'Costa Azul',
          },
        })),
        'Costa Azul',
      );
      expect(
        coloniaDesdeRespuestaNominatim(jsonEncode({
          'address': {'city_district': 'Distrito', 'quarter': 'Cuartel'},
        })),
        'Cuartel',
      );
      // Un campo vacío se salta.
      expect(
        coloniaDesdeRespuestaNominatim(jsonEncode({
          'address': {'suburb': ' ', 'neighbourhood': 'Barrio'},
        })),
        'Barrio',
      );
    });

    test('regresa null si no hay colonia o el JSON no sirve', () {
      expect(
        coloniaDesdeRespuestaNominatim(jsonEncode({
          'address': {'city': 'Acapulco de Juárez'},
        })),
        isNull,
      );
      expect(
        coloniaDesdeRespuestaNominatim(jsonEncode({'error': 'Unable to geocode'})),
        isNull,
      );
      expect(coloniaDesdeRespuestaNominatim('<html>'), isNull);
      expect(coloniaDesdeRespuestaNominatim('[]'), isNull);
    });
  });

  group('GeocodificacionService.coloniaConNominatim', () {
    test('consulta la URL esperada y regresa la colonia', () async {
      late Uri urlPedida;
      final servicio = GeocodificacionService(
        cliente: MockClient((peticion) async {
          urlPedida = peticion.url;
          return _respuesta({'suburb': 'Hornos Insurgentes'});
        }),
      );

      final colonia = await servicio.coloniaConNominatim(16.8531, -99.8237);

      expect(colonia, 'Hornos Insurgentes');
      expect(urlPedida.host, 'nominatim.openstreetmap.org');
      expect(urlPedida.path, '/reverse');
      expect(urlPedida.queryParameters, {
        'format': 'jsonv2',
        'lat': '16.8531',
        'lon': '-99.8237',
        'zoom': '16',
        'accept-language': 'es',
      });
    });

    test('conserva los acentos de la respuesta', () async {
      final servicio = GeocodificacionService(
        cliente: MockClient((_) async => _respuesta({'suburb': 'Jardín Mangos'})),
      );
      expect(await servicio.coloniaConNominatim(16.9, -99.8), 'Jardín Mangos');
    });

    test('usa el valor por defecto si no viene colonia', () async {
      final servicio = GeocodificacionService(
        cliente: MockClient((_) async => _respuesta({'city': 'Acapulco'})),
      );
      expect(await servicio.coloniaConNominatim(16.9, -99.8), coloniaPorDefecto);
    });

    test('usa el valor por defecto si el servidor responde con error', () async {
      final servicio = GeocodificacionService(
        cliente: MockClient((_) async => http.Response('Too many requests', 429)),
      );
      expect(await servicio.coloniaConNominatim(16.9, -99.8), coloniaPorDefecto);
    });

    test('usa el valor por defecto si falla la red', () async {
      final servicio = GeocodificacionService(
        cliente: MockClient((_) async => throw http.ClientException('sin red')),
      );
      expect(await servicio.coloniaConNominatim(16.9, -99.8), coloniaPorDefecto);
    });
  });
}
