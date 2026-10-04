# AcaSafe

App móvil de reportes ciudadanos para Acapulco de Juárez (baches,
inundaciones, robos, postes caídos, etc.), con consulta en mapa y,
en una segunda fase, mapas de calor estadísticos por zona y horario.

Ver [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) para el detalle
técnico completo (esquema de datos, stack, estructura de carpetas).

## Qué necesitas instalado

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal estable, 3.3 o superior)
- Android Studio (para el emulador de Android y/o compilar para Android)
- Xcode, solo si vas a compilar para iOS (requiere Mac)
- Una cuenta de Google para el proyecto de Firebase (la crea quien lo
  configure la primera vez; después cada quien se conecta al mismo
  proyecto)

## Primera vez que clonas el repo

Este repositorio **no incluye** las carpetas `android/` ni `ios/` ni
los archivos de credenciales de Firebase — esos se generan localmente,
cada quien en su máquina, para no subir configuraciones ni secretos
al repo. Pasos:

```bash
# 1. Clona el repo
git clone https://github.com/shamara1223/acasafe-app.git
cd acasafe-app

# 2. Trae las dependencias de Dart/Flutter
flutter pub get

# 3. Genera las carpetas nativas de Android/iOS
#    (si al correr esto pide sobrescribir pubspec.yaml o lib/, dile que NO)
flutter create .

# 4. Conecta el proyecto a Firebase (una sola vez, pide iniciar sesión
#    con la cuenta de Google del proyecto AcaSafe en Firebase Console)
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` va a generar `lib/firebase_options.dart` y los
archivos nativos (`google-services.json` / `GoogleService-Info.plist`)
— ya están en `.gitignore`, no los subas aunque Git te lo sugiera.

Después de eso, en `lib/main.dart` descomenta estas dos líneas:

```dart
import 'firebase_options.dart';
// ...
options: DefaultFirebaseOptions.currentPlatform,
```

## Correr la app

```bash
flutter run
```

## Firebase: servicios que debe tener activados el proyecto

Quien cree el proyecto en [Firebase Console](https://console.firebase.google.com/)
debe activar manualmente:

- **Authentication** → método "Correo electrónico/contraseña"
- **Firestore Database** → modo producción (las reglas están en
  `firestore.rules`, se suben con `firebase deploy --only firestore:rules`)
- **Storage** → para las fotos de los reportes

## Flujo de trabajo en equipo (Git)

- `main` siempre debe quedar en un estado que compile.
- Para una funcionalidad nueva: `git checkout -b feature/nombre-corto`,
  trabajas ahí, y Pull Request a `main` cuando esté lista.
- Comenta en el PR qué pantalla/servicio toca, para que sea fácil de
  revisar entre compañeros.

## Estado actual del proyecto

- [x] Estructura base del proyecto (modelos, servicios, pantallas)
- [x] Esquema de datos de Firestore definido
- [x] Reglas de seguridad iniciales
- [ ] Carpetas nativas Android/iOS (cada quien las genera localmente, ver arriba)
- [ ] Proyecto de Firebase creado y conectado
- [ ] Filtro anti-reportes-falsos (ver `docs/ARQUITECTURA.md`)
- [ ] Fase 2: exportación a Python + mapas de calor (KDE/STKDE)
