import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _esRegistro = false;
  String? _error;

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_esRegistro) {
        await _authService.registrarse(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await _authService.iniciarSesion(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      // Si el login/registro funciona, el StreamBuilder en main.dart
      // detecta el cambio de auth state y navega solo al mapa.
    } catch (e) {
      setState(() => _error = 'No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shield_outlined, size: 64),
              const SizedBox(height: 8),
              Text(
                'AcaSafe',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _cargando ? null : _enviar,
                child: Text(_cargando
                    ? 'Un momento…'
                    : (_esRegistro ? 'Crear cuenta' : 'Entrar')),
              ),
              TextButton(
                onPressed: () => setState(() => _esRegistro = !_esRegistro),
                child: Text(_esRegistro
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿Nuevo en AcaSafe? Crea una cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
