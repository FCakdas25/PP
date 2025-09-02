import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class ItensVendaPage extends StatefulWidget {
  final int fornecedorId;
  final String? fornecedorNome;

  // Programação pode vir como número de dias OU como rótulo textual
  final int? programacaoDias;     // opcional: vindo da ProgramacaoPage
  final String? programacaoLabel; // opcional: rótulo textual (ex.: "1° ENTR. 26/08")

  const ItensVendaPage({
    super.key,
    required this.fornecedorId,
    this.fornecedorNome,
    this.programacaoDias,
    this.programacaoLabel,
  });

  @override
  State<ItensVendaPage> createState() => _ItensVendaPageState();

  static Widget fromArgs(Map<String, dynamic> args) {
    return ItensVendaPage(
      fornecedorId: args['fornecedorId'] as int,
      fornecedorNome: args['fornecedorNome'] as String?,
      programacaoDias: args['programacaoDias'] as int?,
      programacaoLabel: args['programacaoLabel'] as String?,
    );
  }
}

class _ItensVendaPageState extends State<ItensVendaPage> {
  bool _loading = true;
  bool _posting = false;
  bool _podeFechar = false; // habilita o botão de venda

  List<Map<String, dynamic>> _itens = [];
  final Map<String, int> _quantidades = {};
  // controllers por item para manter o TextField sincronizado
  final Map<String, TextEditingController> _qtdCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qtdCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_loadItens(), _loadStatus()]);
    if (mounted) setState(() => _loading = false);
  }

  // ===================== ITENS =====================

  Future<void> _loadItens() async {
    try {
      // Monta a querystring para a programação:
      // - Se vier número, envia programacao_dias=<n>
      // - Se vier rótulo textual, envia programacao_dias=<texto> (mesma chave)
      final qpDias = (widget.programacaoDias != null)
          ? 'programacao_dias=${Uri.encodeQueryComponent(widget.programacaoDias.toString())}'
          : null;

      final qpLabel = (widget.programacaoLabel != null && widget.programacaoLabel!.trim().isNotEmpty)
          ? 'programacao_dias=${Uri.encodeQueryComponent(widget.programacaoLabel!.trim())}'
          : null;

      final query = [qpDias, qpLabel].whereType<String>().join('&');
      final qp = query.isNotEmpty ? '?$query' : '';

      final resp = await AuthService.I
          .get('/itens/${widget.fornecedorId}$qp')
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body);
        if (list is List) {
          _itens = list
              .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
              .cast<Map<String, dynamic>>()
              .toList();
        } else {
          _itens = [];
        }
      } else if (resp.statusCode == 401) {
        _voltarLogin();
      } else {
        _toast('Erro ${resp.statusCode} ao carregar itens.');
      }
    } catch (_) {
      _toast('Falha de conexão.');
    }
  }

  // ===================== CHECK-IN (liberação) =====================

  Future<void> _loadStatus() async {
    // 1) Checagem local (união das chaves, aceita 3 e 003)
    final okLocal = await _liberadoLocal(widget.fornecedorId);

    // 2) (Opcional) Checagem via API se existir o endpoint
    bool okApi = false;
    try {
      final resp = await AuthService.I
          .get('/fornecedores/${widget.fornecedorId}/status')
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        okApi = (m is Map && m['pode_registrar_compra'] == true);
      } else if (resp.statusCode == 401) {
        _voltarLogin();
      }
    } catch (_) {
      // se a API não existir/der erro, seguimos só com o local
    }

    _podeFechar = okLocal || okApi;
  }

  Future<bool> _liberadoLocal(int fornecedorId) async {
    final sp = await SharedPreferences.getInstance();
    final assocCodigo = AuthService.I.associado?['codigo']?.toString();
    final assocId = AuthService.I.associado?['id']?.toString();

    final keys = <String>{
      if (assocCodigo?.isNotEmpty == true) 'visited_fornecedores_$assocCodigo',
      if (assocId?.isNotEmpty == true) 'visited_fornecedores_$assocId',
    };

    final visitados = <String>{};
    for (final k in keys) {
      visitados.addAll(sp.getStringList(k)?.toSet() ?? const <String>{});
    }

    final s = fornecedorId.toString(); // "3"
    final pad3 = s.padLeft(3, '0'); // "003"
    return visitados.contains(s) || visitados.contains(pad3);
  }

  // ===================== SESSION / HELPERS =====================

  void _voltarLogin() {
    AuthService.I.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- Chave única por item (prioriza ItemID, depois Nome+Descricao, senão índice) ---
  String _itemKey(Map<String, dynamic> it, int index) {
    final idRaw = it['ItemID'];
    final id = (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '');
    if (id != null) return 'id_$id';
    final nome = (it['Nome'] ?? '').toString();
    final desc = (it['Descricao'] ?? '').toString();
    final fallback = '$nome|$desc';
    if (fallback.trim().isNotEmpty) return 'nd_${fallback.hashCode}';
    return 'idx_$index';
  }

  // pega InfoExtra vindo da API com variações de nome
  String? _infoExtraFrom(Map<String, dynamic> it) {
    final v = it['InfoExtra'] ?? it['infoExtra'] ?? it['info_extra'];
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  int _getQtdByKey(String key) => _quantidades[key] ?? 0;

  void _setQtdByKey(String key, int qtd) {
    if (qtd < 0) qtd = 0;
    setState(() {
      if (qtd == 0) {
        _quantidades.remove(key);
      } else {
        _quantidades[key] = qtd;
      }
      // mantém o TextField sincronizado
      if (_qtdCtrls.containsKey(key)) {
        final txt = qtd.toString();
        if (_qtdCtrls[key]!.text != txt) {
          _qtdCtrls[key]!.text = txt;
        }
      }
    });
  }

  TextEditingController _ctrlFor(String key, int qtd) {
    final existing = _qtdCtrls[key];
    final txt = qtd.toString();
    if (existing != null) {
      if (existing.text != txt) existing.text = txt;
      return existing;
    }
    final c = TextEditingController(text: txt);
    _qtdCtrls[key] = c;
    return c;
  }

  double get _total {
    double t = 0;
    for (var i = 0; i < _itens.length; i++) {
      final it = _itens[i];
      final key = _itemKey(it, i);
      final qtd = _getQtdByKey(key);
      if (qtd > 0) {
        final precoUnit = (it['Preco'] is num)
            ? (it['Preco'] as num).toDouble()
            : double.tryParse(it['Preco']?.toString() ?? '0') ?? 0.0;
        final volume = (it['Volume'] is num)
            ? (it['Volume'] as num).toInt()
            : int.tryParse(it['Volume']?.toString() ?? '1') ?? 1;
        t += qtd * (precoUnit * volume); // total por caixa
      }
    }
    return t;
  }

  Future<void> _fazerCheckin() async {
    final result = await Navigator.pushNamed(
      context,
      '/leitor_qrcode',
      arguments: {'purpose': 'checkin'},
    );
    await _loadStatus();
    if (mounted) setState(() {});
    if (result is Map && result['fornecedorNome'] != null) {
      _toast('Check-in em ${result['fornecedorNome']}');
    }
  }

  // ===================== VENDA =====================

  Future<void> _registrarVenda() async {
    if (!_podeFechar) {
      _toast('Faça o CHECK-in no estande para finalizar a venda.');
      return;
    }

    // Monta lista de itens no formato que o backend espera
    final itensSelecionados = <Map<String, dynamic>>[];
    for (var i = 0; i < _itens.length; i++) {
      final it = _itens[i];
      final key = _itemKey(it, i);
      final qtd = _getQtdByKey(key);
      if (qtd > 0) {
        final itemId = (it['ItemID'] is int)
            ? it['ItemID'] as int
            : int.tryParse(it['ItemID']?.toString() ?? '');
        final precoUnit = (it['Preco'] is num)
            ? (it['Preco'] as num).toDouble()
            : double.tryParse(it['Preco']?.toString() ?? '0') ?? 0.0;
        final volume = (it['Volume'] is num)
            ? (it['Volume'] as num).toInt()
            : int.tryParse(it['Volume']?.toString() ?? '1') ?? 1;
        final precoCaixa = precoUnit * volume;

        if (itemId != null) {
          itensSelecionados.add({
            'item_id': itemId,
            'quantidade': qtd,          // nº de caixas
            'preco_unit': precoCaixa,   // preço por caixa (unitário × volume)
            // opcional: envie também 'volume': volume, 'preco_unitario': precoUnit se quiser auditar
          });
        }
      }
    }

    if (itensSelecionados.isEmpty) {
      _toast('Selecione pelo menos 1 item para registrar a venda.');
      return;
    }

    final associadoId = AuthService.I.associado?['id'];
    if (associadoId == null) {
      _toast('Sessão inválida. Faça login novamente.');
      _voltarLogin();
      return;
    }

    // programacao_dias: prioriza label textual; se não houver, usa número
    final String? _progDias = (widget.programacaoLabel?.trim().isNotEmpty ?? false)
        ? widget.programacaoLabel!.trim()
        : widget.programacaoDias?.toString();

    final payload = <String, dynamic>{
      'associado_id': associadoId,
      'fornecedor_id': widget.fornecedorId,
      'itens': itensSelecionados,
      if (_progDias != null) 'programacao_dias': _progDias,
    };

    setState(() => _posting = true);
    try {
      final resp = await AuthService.I
          .post('/vendas', payload) // Map (sem jsonEncode)
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _toast('Venda registrada com sucesso!');
        if (!mounted) return;
        setState(() {
          _quantidades.clear();
        });
        Navigator.pop(context, true);
      } else if (resp.statusCode == 401) {
        _voltarLogin();
      } else {
        String msg = 'Erro ${resp.statusCode} ao registrar venda.';
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && (body['message'] ?? body['detail']) != null) {
            msg = (body['message'] ?? body['detail']).toString();
          }
        } catch (_) {}
        _toast(msg);
      }
    } catch (_) {
      _toast('Falha de conexão ao registrar venda.');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final base = widget.fornecedorNome ?? 'Fornecedor ${widget.fornecedorId}';
    final titulo = (widget.programacaoLabel != null && widget.programacaoLabel!.trim().isNotEmpty)
        ? '$base • ${widget.programacaoLabel}'
        : (widget.programacaoDias != null
        ? '$base • ${widget.programacaoDias} dias'
        : base);

    return Scaffold(
      appBar: AppBar(
        title: Text('Itens - $titulo'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await _loadStatus();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.verified),
            tooltip: 'Verificar check-in',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_podeFechar)
            MaterialBanner(
              content: const Text(
                'Para fechar a venda deste fornecedor, realize o CHECK-in no estande (leia o QR Code do estande).',
              ),
              leading: const Icon(Icons.info_outline),
              backgroundColor: Colors.amberAccent,
              actions: [
                TextButton(
                  onPressed: _fazerCheckin,
                  child: const Text('Fazer CHECK-in'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _itens.isEmpty
                ? const Center(child: Text('Nenhum item disponível.'))
                : ListView.separated(
              itemCount: _itens.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final it = _itens[i];
                final key = _itemKey(it, i);
                final nome = it['Nome']?.toString() ?? 'Item';
                final desc = (it['Descricao'] ?? '').toString(); // era 'Sku'
                final volume = (it['Volume'] is num)
                    ? (it['Volume'] as num).toInt()
                    : int.tryParse(it['Volume']?.toString() ?? '1') ?? 1;
                final precoUnit = (it['Preco'] is num)
                    ? (it['Preco'] as num).toDouble()
                    : double.tryParse(it['Preco']?.toString() ?? '0') ?? 0.0;
                final precoCaixa = precoUnit * volume;
                final qtd = _getQtdByKey(key);
                final infoExtra = _infoExtraFrom(it);

                // CARD CUSTOM para evitar "nome espremido"
                return InkWell(
                  onTap: () => _setQtdByKey(key, qtd + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ESQUERDA: Nome/descrição/caixa (ocupa o que sobrar)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(desc),
                              ],
                              const SizedBox(height: 4),
                              Text('caixa: $volume un. (R\$ ${precoCaixa.toStringAsFixed(2)})'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // DIREITA: Preço / +i / controles de quantidade
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'R\$ ${precoUnit.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (infoExtra != null) ...[
                              const SizedBox(height: 6),
                              // +i centralizado abaixo do preço
                              InfoExtraBadge(info: infoExtra),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _setQtdByKey(key, qtd - 1),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: TextFormField(
                                    controller: _ctrlFor(key, qtd),
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) {
                                      final parsed = int.tryParse(v) ?? 0;
                                      _setQtdByKey(key, parsed);
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _setQtdByKey(key, qtd + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.black.withOpacity(0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total selecionado', style: TextStyle(fontSize: 16)),
                Text(
                  'R\$ ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _posting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(_podeFechar ? 'Registrar venda' : 'Registrar venda (requer CHECK-in)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _podeFechar ? const Color(0xFF70845F) : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: (_posting || !_podeFechar) ? null : _registrarVenda,
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET: Badge +i =====================

class InfoExtraBadge extends StatelessWidget {
  final String info;
  const InfoExtraBadge({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Informação extra'),
            content: Text(info),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blueGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.info_outline, size: 16),
            SizedBox(width: 4),
            Text('+ i', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
