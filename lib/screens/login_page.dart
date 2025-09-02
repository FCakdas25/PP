// lib/screens/login_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _autenticando = false;
  bool _obscure = true;
  String? _erro;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_autenticando) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _autenticando = true;
      _erro = null;
    });

    try {
      final ok = await AuthService.I.loginWithPassword(
        login: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (!ok) {
        setState(() => _erro = 'Usuário ou senha inválidos.');
        return;
      }

      // ===== Decisão de rota pós-login =====
      final payload = AuthService.I.userPayload ?? {};
      final aud = (payload['aud'] ?? '').toString().toLowerCase();
      final roles = (payload['roles'] is List)
          ? (payload['roles'] as List)
          .map((e) => e.toString().toUpperCase())
          .toList()
          : <String>[];

      bool hasRole(String r) => roles.contains(r.toUpperCase());
      final perfil = AuthService.I.associado?['perfil']?.toString().toUpperCase();

      if (aud == 'app' || hasRole('APP') || perfil == 'CCB') {
        Navigator.pushNamedAndRemoveUntil(context, '/home_ccb', (_) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home_associados', (_) => false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _erro = 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _autenticando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF70845F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO
                  Image.asset('assets/logo_login.png', width: 180, height: 180),
                  const SizedBox(height: 24),

                  const Text(
                    'Fazer login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.disabled,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _userCtrl,
                              focusNode: _userFocus,
                              decoration: const InputDecoration(
                                labelText: 'Usuário',
                                hintText: 'seu_login',
                                border: OutlineInputBorder(),
                              ),
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _passFocus.requestFocus(),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Informe o usuário' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              autofillHints: const [AutofillHints.password],
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _doLogin(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                            ),
                            if (_erro != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _erro!,
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _autenticando ? null : _doLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _autenticando
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text(
                                  'Entrar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Use seu usuário e senha do Portal.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
