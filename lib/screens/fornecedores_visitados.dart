import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class FornecedoresVisitadosPage extends StatefulWidget {
  const FornecedoresVisitadosPage({super.key});

  @override
  State<FornecedoresVisitadosPage> createState() => _FornecedoresVisitadosPageState();
}

class _FornecedoresVisitadosPageState extends State<FornecedoresVisitadosPage> {
  List<Map<String, dynamic>> _fornecedores = [];
  Set<String> _visitados = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTudo();
  }

  // ================= API + STORAGE =================

  Future<void> _loadTudo() async {
    setState(() => _loading = true);
    await Future.wait([
      _carregarVisitadosLocalUnificado(),
      _carregarFornecedoresCompat(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// Lê a UNIÃO das duas chaves locais:
  ///  - visited_fornecedores_<codigo>
  ///  - visited_fornecedores_<id>
  /// E normaliza adicionando representações com e sem zeros à esquerda.
  Future<void> _carregarVisitadosLocalUnificado() async {
    final sp = await SharedPreferences.getInstance();
    final assocCodigo = AuthService.I.associado?['codigo']?.toString();
    final assocId = AuthService.I.associado?['id']?.toString();

    final keys = <String>{
      if (assocCodigo?.isNotEmpty == true) 'visited_fornecedores_$assocCodigo',
      if (assocId?.isNotEmpty == true) 'visited_fornecedores_$assocId',
    };

    final acc = <String>{};
    for (final k in keys) {
      acc.addAll(sp.getStringList(k)?.toSet() ?? const <String>{});
    }

    // Normaliza: para cada valor X, inclui também X sem zeros e padLeft(3)
    final norm = <String>{};
    for (final raw in acc) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final noZeros = s.replaceFirst(RegExp(r'^0+'), '');
      final pad3 = (noZeros.isEmpty ? '0' : noZeros).padLeft(3, '0');
      norm..add(s)..add(noZeros)..add(pad3);
    }

    _visitados = norm;
  }

  /// Busca fornecedores primeiro em /ccb/fornecedores
  /// e cai para /fornecedores se precisar (compatibilidade).
  Future<void> _carregarFornecedoresCompat() async {
    try {
      final resp1 = await AuthService.I.get('/ccb/fornecedores').timeout(const Duration(seconds: 10));
      if (_ok(resp1.statusCode)) {
        _fornecedores = _coerceList(resp1.body);
        return;
      }
      // fallback antigo
      final resp2 = await AuthService.I.get('/fornecedores').timeout(const Duration(seconds: 10));
      if (_ok(resp2.statusCode)) {
        _fornecedores = _coerceList(resp2.body);
        return;
      }
      if (resp1.statusCode == 401 || resp2.statusCode == 401) {
        _voltarLogin();
      } else {
        _toast('Erro ao carregar fornecedores (${resp1.statusCode}/${resp2.statusCode}).');
      }
    } catch (_) {
      _toast('Falha de conexão.');
    }
  }

  List<Map<String, dynamic>> _coerceList(String body) {
    try {
      final decoded = jsonDecode(body);
      final list = (decoded is List)
          ? decoded
          : (decoded is Map && decoded['items'] is List ? decoded['items'] : []);
      return (list as List)
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  void _voltarLogin() {
    AuthService.I.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // ================= Navegação =================

  /// Decide se abre Programação ou vai direto para Itens.
  Future<void> _abrirDestinoFornecedor(Map<String, dynamic> f) async {
    final id = _fornecedorIdFromJson(f);
    final nome = _fornecedorNomeFromJson(f);
    if (id == null) return;

    // Tenta detectar programação via endpoint NOVO (/ccb/...)
    try {
      final resp = await AuthService.I
          .get('/ccb/fornecedores/$id/programacoes')
          .timeout(const Duration(seconds: 8));

      // Só tenta decodificar se 200 e body não-vazio
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        List prog = const [];
        try {
          final decoded = jsonDecode(resp.body);
          // >>> ajuste: aceita lista direta ou { items: [...] }
          final rawList = (decoded is List)
              ? decoded
              : (decoded is Map && decoded['items'] is List ? decoded['items'] : const []);
          prog = (rawList as List).whereType<Map>().toList();
        } catch (_) {
          prog = const [];
        }

        final temProgramacao = prog.isNotEmpty;
        if (temProgramacao) {
          if (!mounted) return;
          Navigator.pushNamed(
            context,
            '/programacao',
            arguments: {
              'fornecedorId': id,
              'fornecedorNome': nome,
              // passa a lista pra evitar refetch na próxima tela
              'programacoes': prog,
            },
          );
          return;
        }
      }
      // 204/404/200 vazio -> segue para itens
    } catch (_) {
      // Em erro de rede, segue fluxo normal (itens)
    }

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/itens',
      arguments: {
        'fornecedorId': id,
        'fornecedorNome': nome,
      },
    );
  }

  /// Navegação antiga (mantida só se precisar em algum lugar)
  void _abrirItens(Map<String, dynamic> f) {
    final id = _fornecedorIdFromJson(f);
    final nome = _fornecedorNomeFromJson(f);
    if (id == null) return;
    Navigator.pushNamed(
      context,
      '/itens',
      arguments: {
        'fornecedorId': id,
        'fornecedorNome': nome,
      },
    );
  }

  Future<void> _abrirLeitorERecarregar() async {
    final result = await Navigator.pushNamed(context, '/leitor_qrcode');
    await _carregarVisitadosLocalUnificado();
    if (mounted) setState(() {});
    if (result is Map && result['fornecedorNome'] != null) {
      _toast('Check-in em ${result['fornecedorNome']}');
    }
  }

  // ================= Helpers =================

  bool _ok(int c) => c >= 200 && c < 300;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _fornecedorIdFromJson(Map<String, dynamic> f) {
    final raw = f['id'] ?? f['FornecedorID'] ?? f['codigo'] ?? f['codigo_fornecedor'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _fornecedorNomeFromJson(Map<String, dynamic> f) {
    return (f['nome'] ?? f['Nome'] ?? f['fornecedor'] ?? f['descricao'] ?? '').toString();
  }

  bool _visitadoFornecedor(Map<String, dynamic> f) {
    final id = _fornecedorIdFromJson(f);
    if (id == null) return false;
    final s = id.toString();
    final pad3 = s.padLeft(3, '0');
    return _visitados.contains(s) || _visitados.contains(pad3);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _loadTudo,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _fornecedores.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final f = _fornecedores[i];
          final visitado = _visitadoFornecedor(f);
          final nome = _fornecedorNomeFromJson(f);
          final id = _fornecedorIdFromJson(f);

          return ListTile(
            title: Text(nome.isNotEmpty ? nome : 'Fornecedor'),
            subtitle: Text('ID: ${id ?? '-'}'),
            trailing: visitado
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_off, color: Colors.grey),
            tileColor: visitado ? Colors.green.withOpacity(0.08) : null,
            onTap: () => _abrirDestinoFornecedor(f),
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fornecedores'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadTudo,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirLeitorERecarregar,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Ler QR para Check-in'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
      ),
    );
  }
}
