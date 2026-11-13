import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importante para el formato de fechas

import 'firebase_options.dart'; // <-- DESCOMENTADO
import 'models/usuario.dart';
import 'screens/admin_shell.dart';
import 'screens/home_map_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/usuario_service.dart';

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
class _RaizSegunSesion extends StatefulWidget {
  const _RaizSegunSesion();

  @override
  State<_RaizSegunSesion> createState() => _RaizSegunSesionState();
}

class _RaizSegunSesionState extends State<_RaizSegunSesion> {
  // Se crea una sola vez para no volver a suscribirse en cada build.
  final _streamSesion = AuthService().authStateChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _streamSesion,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PantallaCarga();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        // La key hace que, si entra otra cuenta, se vuelva a leer el rol.
        return _RaizSegunRol(key: ValueKey(user.uid));
      },
    );
  }
}

/// Con sesión activa, decide la interfaz según el rol del usuario.
class _RaizSegunRol extends StatefulWidget {
  const _RaizSegunRol({super.key});

  @override
  State<_RaizSegunRol> createState() => _RaizSegunRolState();
}

class _RaizSegunRolState extends State<_RaizSegunRol> {
  // Se crea una sola vez; también se encarga de crear usuarios/{uid}
  // si la cuenta todavía no tiene documento.
  final Stream<Usuario> _streamUsuario = UsuarioService().usuarioActual();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Usuario>(
      stream: _streamUsuario,
      builder: (context, snapshot) {
        // Si no se pudo leer el rol se muestra la interfaz de ciudadano
        // (la de menos permisos) en lugar de dejar la app bloqueada.
        if (snapshot.hasError) return const HomeMapScreen();
        if (!snapshot.hasData) return const _PantallaCarga();

        return snapshot.data!.esAdmin
            ? const AdminShell()
            : const HomeMapScreen();
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}