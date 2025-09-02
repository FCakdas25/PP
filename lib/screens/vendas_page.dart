import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});

  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  // Endpoints (agora com prefixo /ccb)
  static const String pathVendas = '/ccb/vendas';             // POST
  static const String pathFornecedores = '/ccb/fornecedores'; // GET
  static const String pathCompradoresCcb = '/ccb/compradores-ccb'; // GET
  static const String pathLojas = '/ccb/lojas';               // GET

  // Filtros
  List<_Fornecedor> _fornecedores = [];
  _Fornecedor? _fornecedorSel;

  List<_CompradorCcb> _compradoresCcb = [];
  _CompradorCcb? _compradorCcbSel;

  List<_Loja> _lojas = [];
  _Loja? _lojaSel;

  // dados/paginação
  final List<Map<String, dynamic>> _vendas = [];
  bool _carregando = false;
  bool _temMais = true;
  int _page = 1;
  final int _limit = 30;

  // totais
  double _totalValor = 0.0;

  String? _ultimoErro;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _carregarFornecedores(),
      _carregarCompradoresCcb(),
      _carregarLojas(),
    ]);
    if (mounted) setState(() {});
  }

  // ===================== API =====================

  Future<void> _carregarFornecedores() async {
    try {
      final resp = await AuthService.I.get(pathFornecedores).timeout(const Duration(seconds: 12));
      if (_isOk(resp.statusCode)) {
        final data = jsonDecode(resp.body);
        final list = (data is List)
            ? data
            : (data is Map && data['items'] is List ? data['items'] : []);
        _fornecedores = (list as List)
            .map((e) => _Fornecedor.fromJson(e as Map<String, dynamic>))
            .where((f) => f.id != null)
            .cast<_Fornecedor>()
            .toList()
          ..sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
      } else {
        _mostrarSnack('Falha ao carregar fornecedores (${resp.statusCode}).');
      }
    } catch (e) {
      _mostrarSnack('Erro ao carregar fornecedores: $e');
    }
  }

  Future<void> _carregarCompradoresCcb() async {
    try {
      final resp = await AuthService.I.get(pathCompradoresCcb).timeout(const Duration(seconds: 12));
      if (_isOk(resp.statusCode)) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : [];
        _compradoresCcb = list
            .map((e) => _CompradorCcb.fromJson(e as Map<String, dynamic>))
            .where((c) => (c.nome ?? '').isNotEmpty)
            .cast<_CompradorCcb>()
            .toList()
          ..sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
      } else {
        _mostrarSnack('Falha ao carregar compradores CCB (${resp.statusCode}).');
      }
    } catch (e) {
      _mostrarSnack('Erro ao carregar compradores CCB: $e');
    }
  }

  Future<void> _carregarLojas() async {
    try {
      final resp = await AuthService.I.get(pathLojas).timeout(const Duration(seconds: 12));
      if (_isOk(resp.statusCode)) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : [];
        _lojas = list
            .map((e) => _Loja.fromJson(e as Map<String, dynamic>))
            .where((l) => (l.loja ?? '').isNotEmpty)
            .cast<_Loja>()
            .toList()
          ..sort((a, b) => (a.loja ?? '').compareTo(b.loja ?? ''));
      } else {
        _mostrarSnack('Falha ao carregar lojas (${resp.statusCode}).');
      }
    } catch (e) {
      _mostrarSnack('Erro ao carregar lojas: $e');
    }
  }

  Map<String, dynamic> _buildJsonBody({required int page}) {
    final body = <String, dynamic>{
      'page': page,
      'limit': _limit,
      if (_fornecedorSel?.id != null) 'fornecedor_ids': [_fornecedorSel!.id],
      if (_compradorCcbSel?.nome != null && _compradorCcbSel!.nome!.trim().isNotEmpty)
        'comprador_ccb_nomes': [_compradorCcbSel!.nome!.trim()],
      if (_lojaSel?.loja != null && _lojaSel!.loja!.trim().isNotEmpty)
        'loja': _lojaSel!.loja!.trim(),
    };
    return body;
  }

  Future<void> _fetchVendas({bool reset = false}) async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      if (reset) _ultimoErro = null;
    });

    try {
      if (reset) {
        _vendas.clear();
        _totalValor = 0;
        _temMais = true;
        _page = 1;
      }

      final resp = await AuthService.I
          .post(pathVendas, _buildJsonBody(page: _page))
          .timeout(const Duration(seconds: 20));

      if (_isOk(resp.statusCode)) {
        _consumeItems(resp.body);
        if (mounted) setState(() {});
      } else {
        final msg = _shortText(resp.body);
        _ultimoErro = 'Falha ao carregar vendas (${resp.statusCode}). $msg';
        _mostrarSnack(_ultimoErro!);
      }
    } catch (e) {
      _mostrarSnack('Erro ao carregar vendas: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ===================== Parse / acumulo =====================

  void _consumeItems(String body) {
    final data = _safeJson(body);

    final List<Map<String, dynamic>> items = () {
      if (data is Map && data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return <Map<String, dynamic>>[];
    }();

    for (final m in items) {
      _vendas.add(m);

      // soma o valor por item (TotalItem)
      final vRaw = (m['TotalItem'] ??
          m['total_item'] ??
          m['valor'] ??
          m['valor_total'] ??
          m['VALOR'] ??
          0)
          .toString();
      _totalValor += double.tryParse(vRaw.replaceAll(',', '.')) ?? 0.0;
    }

    final bool hasMore = () {
      if (data is Map && data['hasMore'] != null) return data['hasMore'] == true;
      return items.length == _limit; // fallback
    }();

    _temMais = hasMore;
    if (_temMais) _page += 1;
  }

  // ===================== UI / helpers =====================

  bool _isOk(int code) => code >= 200 && code < 300;

  dynamic _safeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtMoeda(num v) {
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }

  String _shortText(String body) {
    final s = body.replaceAll(RegExp(r'\s+'), ' ');
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  // Programação: aceita número (dias) ou rótulo textual (ex.: "1° ENTR. 26/08")
  List<Widget> _progWidgetsFrom(Map<String, dynamic> v) {
    final widgets = <Widget>[];

    dynamic pv = v['ProgramacaoDias'] ?? v['programacao_dias'];
    dynamic pi = v['ProgramacaoDiasItem'] ?? v['programacao_dias_item'];

    int? toInt(dynamic x) => int.tryParse(x?.toString() ?? '');
    String? toStr(dynamic x) {
      final s = x?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final pvInt = toInt(pv), piInt = toInt(pi);
    final pvStr = toStr(pv),  piStr = toStr(pi);

    // Caso numérico (dias)
    if (pvInt != null || piInt != null) {
      if (pvInt != null && piInt != null && pvInt != piInt) {
        widgets.add(Text('Prog. venda: $pvInt dias'));
        widgets.add(Text('Prog. item:  $piInt dias'));
      } else {
        final eff = piInt ?? pvInt;
        if (eff != null) widgets.add(Text('Programação: $eff dias'));
      }
      return widgets;
    }

    // Caso textual (label)
    final eff = piStr ?? pvStr;
    if (eff != null) widgets.add(Text('Programação: $eff'));
    return widgets;
  }
  // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  Widget _buildFilters() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // FORNECEDOR (opcional)
                Expanded(
                  child: DropdownButtonFormField<_Fornecedor>(
                    value: _fornecedorSel,
                    items: _fornecedores
                        .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text('${f.nome ?? 'Fornecedor'}  (#${f.id})'),
                    ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _fornecedorSel = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Fornecedor (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // COMPRADOR CCB (opcional)
                Expanded(
                  child: DropdownButtonFormField<_CompradorCcb>(
                    value: _compradorCcbSel,
                    items: _compradoresCcb
                        .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.nome ?? ''),
                    ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _compradorCcbSel = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Comprador CCB (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // LOJA (Associado) opcional
                Expanded(
                  child: DropdownButtonFormField<_Loja>(
                    value: _lojaSel,
                    items: _lojas
                        .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l.loja ?? ''),
                    ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _lojaSel = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Loja (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar vendas'),
                    onPressed: () => _fetchVendas(reset: true),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar'),
                    onPressed: () {
                      setState(() {
                        _fornecedorSel = null;
                        _compradorCcbSel = null;
                        _lojaSel = null;
                        _vendas.clear();
                        _totalValor = 0;
                        _temMais = true;
                        _page = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final qtd = _vendas.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Vendas carregadas: $qtd',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'Total: ${_fmtMoeda(_totalValor)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_vendas.isEmpty && _carregando) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _ultimoErro?.isNotEmpty == true
                ? _ultimoErro!
                : 'Nenhuma venda encontrada.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _vendas.length + 1,
      itemBuilder: (context, index) {
        if (index == _vendas.length) {
          if (!_temMais) return const SizedBox(height: 80);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
              onPressed: () => _fetchVendas(reset: false),
              icon: const Icon(Icons.expand_more),
              label: const Text('Carregar mais'),
            ),
          );
        }

        final v = _vendas[index];

        // chaves retornadas pelo endpoint /ccb/vendas
        final loja = (v['Loja'] ?? '').toString();
        final fornecedorNome = (v['FornecedorNome'] ?? '').toString();
        final compradorLoja = (v['CompradorLoja'] ?? '').toString();
        final itemNome = (v['ItemNome'] ?? v['Nome'] ?? '').toString();
        final sku = (v['Sku'] ?? '').toString();
        final itemId = (v['ItemID'] ?? '').toString();
        final data = (v['Quando'] ?? '').toString();

        final valorNum = double.tryParse(
          (v['TotalItem'] ?? '0').toString().replaceAll(',', '.'),
        ) ??
            0.0;
        final quantNum = double.tryParse(
          (v['Quantidade'] ?? '0').toString().replaceAll(',', '.'),
        ) ??
            0.0;

        final progLines = _progWidgetsFrom(v);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          elevation: 0.5,
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(
              itemNome.isNotEmpty
                  ? itemNome
                  : (sku.isNotEmpty
                  ? sku
                  : (itemId.isNotEmpty ? 'Item $itemId' : 'Item')),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.isNotEmpty) Text('Data: $data'),
                if (loja.isNotEmpty) Text('Loja: $loja'),
                if (fornecedorNome.isNotEmpty)
                  Text('Fornecedor: $fornecedorNome'),
                if (compradorLoja.isNotEmpty)
                  Text('Comprador: $compradorLoja'),
                if (sku.isNotEmpty) Text('SKU: $sku'),
                if (itemId.isNotEmpty && itemNome.isEmpty && sku.isEmpty)
                  Text('ItemID: $itemId'),
                ...progLines, // <- Programação aqui
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_fmtMoeda(valorNum),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Qtde: ${quantNum.toStringAsFixed(0)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildHeader(),
          const Divider(height: 0),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
}

class _Fornecedor {
  final int? id;
  final String? nome;

  _Fornecedor({this.id, this.nome});

  factory _Fornecedor.fromJson(Map<String, dynamic> j) {
    final id = j['id'] ?? j['codigo'] ?? j['codigo_fornecedor'] ?? j['FornecedorID'];
    final nome = j['nome'] ?? j['fornecedor'] ?? j['descricao'] ?? j['Nome'];
    return _Fornecedor(
      id: (id is int) ? id : int.tryParse(id?.toString() ?? ''),
      nome: nome?.toString(),
    );
  }
}

class _CompradorCcb {
  final String? nome;
  _CompradorCcb({this.nome});
  factory _CompradorCcb.fromJson(Map<String, dynamic> j) =>
      _CompradorCcb(nome: (j['nome'] ?? j['Nome'])?.toString());
}

class _Loja {
  final int? id; // representativo (não é usado para o filtro)
  final String? loja; // string exibida e filtrada
  _Loja({this.id, this.loja});
  factory _Loja.fromJson(Map<String, dynamic> j) {
    final id = j['id'] ?? j['CadastroID'];
    final loja = j['loja'] ?? j['Loja'];
    return _Loja(
      id: (id is int) ? id : int.tryParse(id?.toString() ?? ''),
      loja: loja?.toString(),
    );
  }
}
