// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // base centralizada (AppConfig.apiBase)

class AuthService {
  // ---------- Singleton ----------
  static final AuthService I = AuthService._();
  AuthService._();

  // ---------- Config ----------
  static String get baseUrl {
    final raw = AppConfig.apiBase.trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  static const String _loginPath = '/auth/login';

  // ---------- Storage Keys ----------
  static const String _spTokenKey = 'token';              // compat legado
  static const String _spAssocKey = 'associado';          // compat legado
  static const String _spUserPayloadKey = 'user_payload'; // payload do JWT

  // ---------- Estado em memória ----------
  String? _token;
  Map<String, dynamic>? _userPayload; // payload JWT
  Map<String, dynamic>? _associado;   // compat

  // =========================================================
  // Sessão
  // =========================================================

  /// Chame no boot do app (ex.: Splash) para popular memória a partir do disco.
  Future<void> ensureLoaded() async {
    if (_token != null || _userPayload != null) return;
    await load();
  }

  /// Carrega token e payload do SharedPreferences
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    _token = sp.getString(_spTokenKey);

    final up = sp.getString(_spUserPayloadKey);
    if (up != null) {
      try {
        _userPayload = jsonDecode(up) as Map<String, dynamic>;
      } catch (_) {
        _userPayload = null;
      }
    }

    // compat: associado (se alguma parte do app ainda usa)
    final assocStr = sp.getString(_spAssocKey);
    if (assocStr != null) {
      try {
        _associado = jsonDecode(assocStr) as Map<String, dynamic>;
      } catch (_) {
        _associado = null;
      }
    }
  }

  /// Faz login com usuário+senha. Retorna true/false.
  Future<bool> loginWithPassword({
    required String login,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl$_loginPath');

    final resp = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login': login,
        'password': password,
        'aud': 'app',
      }),
    )
        .timeout(const Duration(seconds: 12));

    if (resp.statusCode != 200) return false;

    final data = _safeJson(resp.body);
    final token = (data['access_token'] ?? '').toString();
    if (token.isEmpty) return false;

    final payload = _decodeJwtPayload(token);
    await _saveSession(token: token, userPayload: payload);
    return true;
  }

  /// Salva sessão em memória e disco (mantém compat com 'associado')
  Future<void> _saveSession({
    required String token,
    Map<String, dynamic>? userPayload,
  }) async {
    _token = token;
    _userPayload = userPayload;

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_spTokenKey, token);

    if (userPayload != null) {
      await sp.setString(_spUserPayloadKey, jsonEncode(userPayload));

      // compat: se seu app antigo lia "associado", tenta mapear algo útil
      final assocCompat = <String, dynamic>{
        if (userPayload['name'] != null) 'Nome': userPayload['name'],
        if (userPayload['cd_cliente'] != null) 'cd_cliente': userPayload['cd_cliente'],
        if (userPayload['cd_fornecedor'] != null) 'cd_fornecedor': userPayload['cd_fornecedor'],
        if (userPayload['roles'] != null) 'roles': userPayload['roles'],
        if (userPayload['aud'] != null) 'aud': userPayload['aud'],
      };
      _associado = assocCompat.isEmpty ? null : assocCompat;
      if (_associado != null) {
        await sp.setString(_spAssocKey, jsonEncode(_associado));
      } else {
        await sp.remove(_spAssocKey);
      }
    } else {
      await sp.remove(_spUserPayloadKey);
      await sp.remove(_spAssocKey);
    }
  }

  /// Sai da sessão e limpa storage
  Future<void> logout() async {
    _token = null;
    _userPayload = null;
    _associado = null;

    final sp = await SharedPreferences.getInstance();
    await sp.remove(_spTokenKey);
    await sp.remove(_spUserPayloadKey);
    await sp.remove(_spAssocKey);
  }

  // -------- Getters de estado --------
  String? get token => _token;
  Map<String, dynamic>? get userPayload => _userPayload; // novo
  Map<String, dynamic>? get associado => _associado;     // compat

  bool hasRole(String role) {
    final roles = (_userPayload?['roles'] as List?)
        ?.map((e) => e.toString().toUpperCase())
        .toList() ??
        const [];
    return roles.contains(role.toUpperCase());
  }

  bool isAdmin() => hasRole('ADMIN');
  bool isPortal() => hasRole('PORTAL');

  /// Token existe e não está expirado (com margem de segurança).
  Future<bool> isLoggedIn({Duration safety = const Duration(seconds: 5)}) async {
    final t = _token;
    if (t == null || t.isEmpty) return false;

    // Se não temos payload, tenta decodificar do próprio token e persistir
    if (_userPayload == null) {
      final decoded = _decodeJwtPayload(t);
      if (decoded != null) {
        _userPayload = decoded;
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_spUserPayloadKey, jsonEncode(decoded));
      }
    }

    final p = _userPayload;
    if (p == null) return false; // <<< correção: não assume logado sem payload

    return !_isJwtExpired(p, safety: safety);
  }

  // =========================================================
  // HTTP helpers (com tratamento centralizado)
  // =========================================================

  Map<String, String> authHeaders([Map<String, String>? extra]) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = _token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    if (extra != null) h.addAll(extra);
    return h;
  }

  Future<http.Response> _request(Future<http.Response> Function() call) async {
    try {
      final resp = await call().timeout(const Duration(seconds: 20));
      if (resp.statusCode == 401) {
        // token inválido/expirado -> encerra sessão para o app reagir
        await logout();
        throw UnauthorizedException();
      }
      return resp;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      // padroniza erro de rede
      throw NetworkException();
    }
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() => http.get(uri, headers: authHeaders(headers)));
  }

  /// GET "bruto" (por ex. PDF/XML). Pode customizar headers fora do JSON.
  Future<http.Response> getRaw(String path, {Map<String, String>? headers}) {
    final uri = Uri.parse('$baseUrl$path');
    final base = authHeaders();
    if (headers != null) base.addAll(headers);
    return _request(() => http.get(uri, headers: base));
  }

  Future<http.Response> post(String path, Object body, {Map<String, String>? headers}) {
    final uri = Uri.parse('$baseUrl$path');
    final payload = (body is String) ? body : jsonEncode(body);
    return _request(() => http.post(uri, headers: authHeaders(headers), body: payload));
  }

  Future<http.Response> put(String path, Object body, {Map<String, String>? headers}) {
    final uri = Uri.parse('$baseUrl$path');
    final payload = (body is String) ? body : jsonEncode(body);
    return _request(() => http.put(uri, headers: authHeaders(headers), body: payload));
  }

  Future<http.Response> delete(String path, {Map<String, String>? headers}) {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() => http.delete(uri, headers: authHeaders(headers)));
  }

  // =========================================================
  // Utilidades JWT / JSON
  // =========================================================

  Map<String, dynamic> _safeJson(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
      return <String, dynamic>{'data': v};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payloadRaw = base64Url.normalize(parts[1]);
      final bytes = base64Url.decode(payloadRaw);
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) return map;
    } catch (_) {}
    return null;
  }

  bool _isJwtExpired(Map<String, dynamic> payload, {Duration safety = Duration.zero}) {
    final exp = payload['exp'];
    if (exp is int) {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final safetySec = safety.inSeconds;
      return (nowSec + safetySec) >= exp;
    }
    return false; // se não tem exp, não tratamos como expirado aqui
  }
}

// ---------- Exceptions simples p/ controle de fluxo ----------
class UnauthorizedException implements Exception {}
class NetworkException implements Exception {}
