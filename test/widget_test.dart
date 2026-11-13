// Tests de la lógica que no depende de Firebase.
//
// AcaSafeApp no se prueba aquí directamente: al construirse consulta
// FirebaseAuth, y eso requiere inicializar Firebase (o simularlo), algo
// que todavía no está configurado en el proyecto.

import 'package:acasafe/models/reporte.dart';
import 'package:acasafe/models/usuario.dart';
import 'package:acasafe/utils/constants.dart';
import 'package:acasafe/utils/filtros_reporte.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Reporte _reporte(CategoriaReporte categoria, DateTime fechaHora) {
  return Reporte(
    tipo: 'otro',
    categoria: categoria,
    colonia: 'Centro',
    ubicacion: const GeoPoint(acapulcoLat, acapulcoLng),
    descripcion: 'Prueba',
    fechaHora: fechaHora,
    usuarioId: 'test',
  );
}

void main() {
  group('categoriaDesdeTexto', () {
    test('mapea las categorías viejas a las nuevas', () {
      expect(categoriaDesdeTexto('seguridad'), CategoriaReporte.delictivo);
      expect(categoriaDesdeTexto('clima'), CategoriaReporte.riesgoNatural);
    });

    test('reconoce las categorías actuales', () {
      for (final c in CategoriaReporte.values) {
        expect(categoriaDesdeTexto(c.name), c);
      }
    });

    test('valores desconocidos o vacíos caen en "otro"', () {
      expect(categoriaDesdeTexto('inventada'), CategoriaReporte.otro);
      expect(categoriaDesdeTexto(null), CategoriaReporte.otro);
    });
  });

  group('Usuario', () {
    test('reconoce los roles actuales', () {
      for (final r in RolUsuario.values) {
        expect(rolDesdeTexto(r.name), r);
      }
    });

    test('rol desconocido o faltante se trata como ciudadano', () {
      expect(rolDesdeTexto('superadmin'), RolUsuario.ciudadano);
      expect(rolDesdeTexto('Admin'), RolUsuario.ciudadano);
      expect(rolDesdeTexto(null), RolUsuario.ciudadano);
      expect(rolDesdeTexto(true), RolUsuario.ciudadano);
      expect(Usuario.fromMap('u1', {}).rol, RolUsuario.ciudadano);
    });

    test('fromMap lee el rol admin y la fecha en ambos formatos', () {
      final fecha = DateTime(2026, 11, 1, 10);
      final conTimestamp = Usuario.fromMap('u1', {
        'email': 'a@b.c',
        'rol': 'admin',
        'fechaRegistro': Timestamp.fromDate(fecha),
      });
      expect(conTimestamp.esAdmin, isTrue);
      expect(conTimestamp.email, 'a@b.c');
      expect(conTimestamp.fechaRegistro, fecha);

      final conTexto = Usuario.fromMap('u2', {
        'fechaRegistro': fecha.toIso8601String(),
      });
      expect(conTexto.esAdmin, isFalse);
      expect(conTexto.fechaRegistro, fecha);
    });

    test('toMap guarda el rol como texto', () {
      final usuario = Usuario(uid: 'u1', fechaRegistro: DateTime(2026));
      expect(usuario.toMap()['rol'], 'ciudadano');
    });
  });

  test('cada tipo de reporte tiene nombre legible', () {
    for (final tipo in tiposDeReporte.keys) {
      expect(nombreTipoReporte[tipo], isNotNull, reason: tipo);
    }
  });

  group('FiltrosReporte', () {
    final ahora = DateTime(2026, 11, 8, 12);
    final reportes = [
      _reporte(CategoriaReporte.delictivo, DateTime(2026, 11, 8, 3)),
      _reporte(CategoriaReporte.social, DateTime(2026, 11, 8, 9)),
      _reporte(CategoriaReporte.ambiental, DateTime(2026, 11, 5, 15)),
      _reporte(CategoriaReporte.otro, DateTime(2026, 10, 1, 20)),
    ];

    test('sin filtros muestra todo', () {
      final filtros = FiltrosReporte.inicial();
      expect(filtros.estaActivo, isFalse);
      expect(filtros.aplicar(reportes, ahora: ahora), hasLength(4));
    });

    test('filtra por categoría', () {
      final filtros = FiltrosReporte.inicial()
          .copyWith(categorias: {CategoriaReporte.delictivo});
      expect(filtros.estaActivo, isTrue);
      expect(filtros.aplicar(reportes, ahora: ahora), hasLength(1));
    });

    test('filtra por franja horaria', () {
      final madrugada =
          FiltrosReporte.inicial().copyWith(franja: FranjaHoraria.madrugada);
      final noche =
          FiltrosReporte.inicial().copyWith(franja: FranjaHoraria.noche);
      expect(madrugada.aplicar(reportes, ahora: ahora), hasLength(1));
      expect(noche.aplicar(reportes, ahora: ahora), hasLength(1));
    });

    test('filtra por periodo', () {
      FiltrosReporte conPeriodo(PeriodoReporte p) =>
          FiltrosReporte.inicial().copyWith(periodo: p);
      expect(
        conPeriodo(PeriodoReporte.ultimas24h).aplicar(reportes, ahora: ahora),
        hasLength(2),
      );
      expect(
        conPeriodo(PeriodoReporte.ultimos7dias).aplicar(reportes, ahora: ahora),
        hasLength(3),
      );
    });
  });
}
