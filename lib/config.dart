// lib/config.dart
class AppConfig {
  /// Base da API. Pode ser sobrescrita via --dart-define=API_BASE=...
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://apiappcompras.centraldecompras.com.br'
);
}
