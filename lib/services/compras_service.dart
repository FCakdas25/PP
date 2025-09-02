import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ComprasService {
  static String get base {
    final raw = AppConfig.apiBase.trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static Future<List<Map<String, dynamic>>> listarNegociacoesAbertas(String categoriaKey) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token');

    final uri = Uri.parse('$base/compras/negociacoes-abertas?categoria=$categoriaKey');

    final resp = await http.get(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Erro ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> listarItensNegociacao(int negociacaoId) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token');

    final uri = Uri.parse('$base/compras/negociacoes/$negociacaoId/itens');

    final resp = await http.get(
      uri,
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Erro ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
