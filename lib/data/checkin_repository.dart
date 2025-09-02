// lib/data/checkin_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CheckinRepository {
  static const _prefsKeyVisited = 'visited_uids';

  Future<Set<String>> loadVisited() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKeyVisited) ?? <String>[];
    return list.toSet();
  }

  Future<void> markVisited(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_prefsKeyVisited) ?? <String>[]).toSet();
    set.add(uid);
    await prefs.setStringList(_prefsKeyVisited, set.toList());
  }

  Future<void> unmarkVisited(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_prefsKeyVisited) ?? <String>[]).toSet();
    set.remove(uid);
    await prefs.setStringList(_prefsKeyVisited, set.toList());
  }

  /// (Opcional) Dispara para API também
  Future<void> syncToApi({
    required String baseUrl, // ex: http://10.150.5.168:8000
    required String associado,
    required String fornecedorNome,
    required String fornecedorUid,
  }) async {
    final uri = Uri.parse('$baseUrl/checkin');
    final body = {
      'associado': associado,
      'fornecedor_nome': fornecedorNome,
      'fornecedor_uid': fornecedorUid,
      'evento': 'checkin',
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode >= 400) {
        // Log/Toast opcional
      }
    } catch (_) {
      // Offline? Sem problema, fica só local
    }
  }
}
