// lib/pages/informacoes_gerais_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class InformacoesGeraisPage extends StatefulWidget {
  final String associado; // código do associado (string)

  const InformacoesGeraisPage({super.key, required this.associado});

  @override
  State<InformacoesGeraisPage> createState() => _InformacoesGeraisPageState();
}

class _InformacoesGeraisPageState extends State<InformacoesGeraisPage> {
  bool _loading = true;
  String? _erro;
  List<Map<String, dynamic>> _vendas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      // 1) tenta endpoint novo com /ccb
      final uriCcb = '/ccb/compras/por-loja?associado=${Uri.encodeQueryComponent(widget.associado)}';
      final respCcb = await AuthService.I.get(uriCcb).timeout(const Duration(seconds: 12));

      if (respCcb.statusCode == 200) {
        _vendas = _parseList(respCcb.body);
      } else if (respCcb.statusCode == 404) {
        // 2) fallback p/ endpoint legado sem /ccb
        final uriOld = '/compras/por-loja?associado=${Uri.encodeQueryComponent(widget.associado)}';
        final respOld = await AuthService.I.get(uriOld).timeout(const Duration(seconds: 12));
        if (respOld.statusCode == 200) {
          _vendas = _parseList(respOld.body);
        } else if (respOld.statusCode == 401) {
          _redirLogin('Sessão expirada. Faça login novamente.');
          return;
        } else {
          _erro = 'Falha ${respOld.statusCode} ao carregar informações.';
        }
      } else if (respCcb.statusCode == 401) {
        _redirLogin('Sessão expirada. Faça login novamente.');
        return;
      } else if (respCcb.statusCode == 204) {
        _vendas = [];
      } else {
        _erro = 'Falha ${respCcb.statusCode} ao carregar informações.';
      }
    } catch (e) {
      _erro = 'Erro de conexão: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseList(String body) {
    final raw = jsonDecode(body);
    final list = (raw is List) ? raw : (raw is Map && raw['items'] is List ? raw['items'] : const []);
    // Normaliza campos comuns para exibição
    return list.whereType<Map>().map<Map<String, dynamic>>((m) {
      final map = m.map((k, v) => MapEntry(k.toString(), v));
      return {
        'fornecedor': (map['Fornecedor'] ?? map['fornecedor'] ?? map['FornecedorNome'] ?? '').toString(),
        'itens': (map['itens'] is List)
            ? (map['itens'] as List)
            : (map['Itens'] is List ? map['Itens'] : const []),
        'quando': (map['Quando'] ?? map['quando'] ?? map['data'] ?? map['Data'])?.toString(),
        // campos alternativos que algumas APIs retornam:
        'timestamp': (map['timestamp'] ?? map['Timestamp']),
        'valor_total': map['valor_total'] ?? map['Total'] ?? map['total'],
      };
    }).toList();
  }

  void _redirLogin(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  String _fmtHoraMin(DateTime dt) =>
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDataCurta(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

  DateTime? _parseData(String? s) {
    if (s == null || s.isEmpty) return null;
    // tenta ISO; se vier outro formato, pode ajustar aqui
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmtMoeda(num? v) {
    final n = (v is num) ? v : 0;
    return 'R\$ ${n.toStringAsFixed(2)}';
    // (se quiser intl/locale pt-BR, dá pra usar package:intl)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Informações Gerais"),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_erro != null)
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        )
            : _vendas.isEmpty
            ? const Center(child: Text("Nenhuma venda registrada ainda."))
            : ListView.builder(
          itemCount: _vendas.length,
          itemBuilder: (context, index) {
            final venda = _vendas[index];

            final fornecedor = (venda['fornecedor'] ?? '').toString();
            final itens = (venda['itens'] is List)
                ? venda['itens'] as List
                : const <dynamic>[];
            final quandoIso = venda['quando']?.toString();
            final ts = _parseData(quandoIso);
            final tsTxt = (ts == null)
                ? (quandoIso ?? '')
                : '${_fmtDataCurta(ts)} ${_fmtHoraMin(ts)}';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fornecedor.isEmpty ? 'Fornecedor' : fornecedor,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (tsTxt.isNotEmpty)
                      Text(
                        'Data: $tsTxt',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const Divider(),
                    ...itens.map((item) {
                      final prod = (item is Map ? (item['produto'] ?? item['Produto'] ?? item['nome']) : null)?.toString() ?? '';
                      final qtd = (item is Map ? (item['quantidade'] ?? item['Quantidade']) : null);
                      final val = (item is Map ? (item['valor'] ?? item['Valor']) : null);
                      final qtdNum = (qtd is num) ? qtd : num.tryParse(qtd?.toString() ?? '0') ?? 0;
                      final valNum = (val is num) ? val : num.tryParse(val?.toString() ?? '0') ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('$prod - ${qtdNum}x ${_fmtMoeda(valNum)}'),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
