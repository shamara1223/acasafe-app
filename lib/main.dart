import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para el formato de fechas

import 'firebase_options.dart'; // <-- DESCOMENTADO
import 'screens/home_map_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <-- DESCOMENTADO
  );
  
  // Esta línea debe ir DENTRO de main() para que no dé error
  await initializeDateFormatting(); 
  
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