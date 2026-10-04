import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/home_map_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

// Este archivo se genera localmente para cada quien con:
//   flutterfire configure
// y NO se sube a GitHub (ver .gitignore) porque trae las credenciales
// del proyecto de Firebase. Instrucciones completas en el README.
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AcaSafeApp());
}

class AcaSafeApp extends StatelessWidget {
  const AcaSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcaSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _RaizSegunSesion(),
    );
  }
}

/// Decide qué pantalla mostrar según si hay sesión activa o no.
class _RaizSegunSesion extends StatelessWidget {
  const _RaizSegunSesion();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final haySesion = snapshot.data != null;
        return haySesion ? const HomeMapScreen() : const LoginScreen();
      },
    );
  }
}
