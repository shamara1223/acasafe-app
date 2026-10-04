# Arquitectura de AcaSafe

## Resumen

AcaSafe es una app móvil (Flutter, Android + iOS) para que habitantes y
turistas de Acapulco de Juárez reporten incidencias de movilidad,
seguridad y clima en su colonia (baches, postes caídos, robos,
inundaciones, etc.), y las consulten en un mapa.

Esto nace de un ajuste de alcance al protocolo de investigación
original: las fuentes oficiales de incidencia delictiva en México
(SESNSP / RNID) solo publican datos agregados a nivel municipal, sin
colonia ni coordenadas. AcaSafe resuelve esto generando su **propia**
base de datos geolocalizada a partir de reportes ciudadanos.

## Fases del proyecto

- **Fase 1 (actual):** app de reporte y consulta en tiempo real.
- **Fase 2 (futura):** una vez acumulada una base de reportes
  suficiente, exportar la colección `reportes` de Firestore a
  CSV/Parquet y correr el mismo pipeline de análisis geoespacial ya
  investigado en el protocolo (GeoPandas, KDE/STKDE, mapas de calor con
  Folium) para calcular porcentajes por zona, horario y día.

## Stack técnico

| Capa | Tecnología | Por qué |
|---|---|---|
| App móvil | Flutter | Un solo código para Android/iOS, equipo pequeño, un semestre |
| Autenticación | Firebase Auth | Evita mantener servidor propio de usuarios |
| Base de datos | Cloud Firestore | Tiempo real, consultas geoespaciales básicas suficientes para la Fase 1 |
| Fotos | Firebase Storage | Integrado con Auth/Firestore, sin servidor propio |
| Análisis (Fase 2) | Python + GeoPandas + Folium | Mismo stack ya definido en el protocolo de investigación |

## Estructura de carpetas

```
lib/
  models/      -> Reporte, Usuario (estructuras de datos)
  services/    -> AuthService, FirestoreService, StorageService
                  (toda la comunicación con Firebase pasa por aquí,
                  nunca directo desde las pantallas)
  screens/     -> LoginScreen, HomeMapScreen, NewReportScreen,
                  ReportDetailScreen
  utils/       -> constants.dart (tipos de reporte, colores, centro del mapa)
  main.dart    -> punto de entrada, decide Login vs Mapa según sesión
```

## Esquema de datos (Firestore)

### Colección `reportes`

| Campo | Tipo | Descripción |
|---|---|---|
| `tipo` | string | clave interna (ver `utils/constants.dart`), ej. `bache`, `robo` |
| `categoria` | string | `infraestructura` / `seguridad` / `clima` / `otro` |
| `colonia` | string | obtenida por geocodificación inversa al momento del reporte |
| `ubicacion` | GeoPoint | lat/lng exactos |
| `descripcion` | string | texto libre del usuario |
| `fotoUrl` | string? | URL en Firebase Storage, opcional |
| `fechaHora` | Timestamp | momento del reporte |
| `estado` | string | `pendiente` / `verificado` / `falso` / `resuelto` |
| `usuarioId` | string | uid de quien reportó |
| `votosUtil` / `votosFalso` | int | validación comunitaria (insumo para el futuro filtro anti-falsos) |

### Colección `usuarios`

| Campo | Tipo |
|---|---|
| `nombre` | string? |
| `email` | string? |
| `fechaRegistro` | string (ISO 8601) |
| `reportesEnviados` | int |

## Filtro anti-reportes-falsos (pendiente de diseñar)

Por ahora todo reporte entra como `pendiente` y cualquier usuario puede
votar si le parece útil o falso (`FirestoreService.votar`). Ideas para
definir en equipo antes de la Fase 2:

- Umbral automático: si `votosFalso - votosUtil` supera cierto número,
  el estado pasa solo a `falso` (Cloud Function con trigger `onUpdate`).
- Límite de reportes por usuario por día, para frenar spam.
- Moderación manual simple desde un panel (puede ser incluso la
  consola de Firebase al inicio, sin construir un admin aparte).

## Seguridad

Ver `firestore.rules` en la raíz del repo — controla quién puede leer,
crear y (parcialmente) actualizar reportes, para que nadie pueda
alterar o borrar reportes ajenos directamente desde la app.
