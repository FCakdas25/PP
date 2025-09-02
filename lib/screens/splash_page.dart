// lib/screens/splash_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      // carrega token/payload do storage
      await AuthService.I.load();

      // 1) verifica expiração local
      final okLocal = await AuthService.I.isLoggedIn();

      // 2) confirma no servidor
      if (okLocal) {
        final resp = await AuthService.I.get('/auth/me');
        if (resp.statusCode == 200) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          return;
        }
      }

      // se não logado (ou inválido no servidor), limpa e vai para login
      await AuthService.I.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      // qualquer erro => volta para login
      await AuthService.I.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
