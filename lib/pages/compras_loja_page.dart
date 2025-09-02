// lib/pages/compras_loja_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../services/auth_service.dart';

class ComprasLojaPage extends StatefulWidget {
  const ComprasLojaPage({super.key});

  @override
  State<ComprasLojaPage> createState() => _ComprasLojaPageState();
}

class _ComprasLojaPageState extends State<ComprasLojaPage> {
  bool _loading = true;
  bool _downloading = false;

  String? _loja;
  double _totalGeral = 0;
  DateTime? _de;
  DateTime? _ate; // data “humana” escolhida; enviada ao backend como ate+1 dia

  List<Map<String, dynamic>> _compras = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qs = <String>[];
      if (_de != null) {
        qs.add('de=${DateFormat('yyyy-MM-dd').format(_de!)}');
      }
      if (_ate != null) {
        // Inclusivo para o usuário: enviamos +1 dia (backend usa CriadoEm < :ate)
        final ateExclusivo = _ate!.add(const Duration(days: 1));
        qs.add('ate=${DateFormat('yyyy-MM-dd').format(ateExclusivo)}');
      }
      final path = '/compras/por-loja${qs.isEmpty ? "" : "?${qs.join("&")}"}';

      final resp = await AuthService.I.get(path).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body);
        _loja = m['loja']?.toString();
        _totalGeral = (m['total_geral'] is num)
            ? (m['total_geral'] as num).toDouble()
            : double.tryParse(m['total_geral']?.toString() ?? '0') ?? 0.0;

        final list = (m['compras'] is List) ? (m['compras'] as List) : const [];
        _compras = list
            .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
            .cast<Map<String, dynamic>>()
            .toList();
      } else if (resp.statusCode == 401) {
        _voltarLogin();
      } else {
        _toast('Erro ${resp.statusCode} ao carregar as compras.');
      }
    } catch (_) {
      _toast('Falha de conexão ao carregar as compras.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _voltarLogin() {
    AuthService.I.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _selecionarData({required bool isInicio}) async {
    final now = DateTime.now();
    final base = isInicio ? (_de ?? now) : (_ate ?? now);
    final dt = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: isInicio ? 'Data inicial' : 'Data final',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (dt != null) {
      setState(() {
        if (isInicio) {
          _de = dt;
        } else {
          _ate = dt;
        }
      });
      await _load();
    }
  }

  Future<void> _limparFiltro() async {
    setState(() {
      _de = null;
      _ate = null;
    });
    await _load();
  }

  Future<void> _abrirDetalheVenda(int vendaId) async {
    try {
      final resp = await AuthService.I.get('/vendas/$vendaId').timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        _toast('Erro ${resp.statusCode} ao buscar a venda.');
        return;
      }
      final m = jsonDecode(resp.body) as Map<String, dynamic>;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final itens = (m['itens'] is List) ? (m['itens'] as List) : const [];
          final total = (m['total'] is num)
              ? (m['total'] as num).toDouble()
              : double.tryParse(m['total']?.toString() ?? '0') ?? 0.0;

          // Programação (nível venda) – opcional
          final progVenda = _asInt(m['programacao_dias']) ?? _asInt(m['ProgramacaoDias']);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Venda #$vendaId — ${m['fornecedor'] ?? ''}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${m['comprador'] ?? ''} · ${m['data_local'] ?? ''}'),
                        if (progVenda != null) Text('Programação (venda): $progVenda dias'),
                      ],
                    ),
                    trailing: Text(
                      'R\$ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: itens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = (itens[i] as Map).map((k, v) => MapEntry(k.toString(), v));
                        final nome = it['nome']?.toString() ?? '';
                        final sku = it['sku']?.toString() ?? '';
                        final q = (it['quantidade'] is num) ? (it['quantidade'] as num).toInt() : 0;
                        final p = (it['preco_unit'] is num)
                            ? (it['preco_unit'] as num).toDouble()
                            : double.tryParse(it['preco_unit']?.toString() ?? '0') ?? 0.0;

                        // Programação (nível item) – opcional; aceitamos 2 chaves
                        final progItem = _asInt(it['programacao_dias']) ??
                            _asInt(it['ProgramacaoDiasItem']) ??
                            _asInt(it['ProgramacaoDias']);

                        return ListTile(
                          title: Text(nome),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SKU: $sku'),
                              if (progItem != null) Text('Programação (item): $progItem dias'),
                            ],
                          ),
                          trailing: Text('${q} x R\$ ${p.toStringAsFixed(2)}'),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.code),
                            label: const Text('Baixar XML'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _baixarXml(vendaId);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: _downloading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Icon(Icons.picture_as_pdf),
                            label: const Text('Baixar PDF'),
                            onPressed: _downloading
                                ? null
                                : () async {
                              Navigator.pop(ctx);
                              await _baixarPdf(vendaId);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      _toast('Falha ao carregar detalhes da venda.');
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _baixarPdf(int vendaId) async {
    setState(() => _downloading = true);
    try {
      final resp = await AuthService.I.getRaw('/vendas/$vendaId/pdf').timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/venda_$vendaId.pdf');
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        await OpenFilex.open(file.path);
      } else {
        _toast('Falha ao baixar PDF (${resp.statusCode}).');
      }
    } catch (_) {
      _toast('Erro ao baixar PDF.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _baixarXml(int vendaId) async {
    try {
      final resp = await AuthService.I.getRaw('/vendas/$vendaId/xml').timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/venda_$vendaId.xml');
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        await OpenFilex.open(file.path);
      } else {
        _toast('Falha ao baixar XML (${resp.statusCode}).');
      }
    } catch (_) {
      _toast('Erro ao baixar XML.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loja = _loja ?? (AuthService.I.associado?['loja']?.toString() ?? 'Minha Loja');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações gerais'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros simples por período
          Container(
            color: Colors.black.withOpacity(0.03),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(isInicio: true),
                    child: _FiltroChip(
                      label: 'De',
                      value: _de != null ? DateFormat('dd/MM/yyyy').format(_de!) : '—',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(isInicio: false),
                    child: _FiltroChip(
                      label: 'Até',
                      value: _ate != null ? DateFormat('dd/MM/yyyy').format(_ate!) : '—',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _limparFiltro,
                  child: const Text('Limpar'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _compras.isEmpty
                  ? const Center(child: Text('Nenhuma compra encontrada.'))
                  : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _compras.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      // Card de cabeçalho com total consolidado
                      return ListTile(
                        tileColor: Colors.green.withOpacity(0.06),
                        title: Text(loja, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Total de compras no período'),
                        trailing: Text(
                          'R\$ ${_totalGeral.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    final c = _compras[i - 1];
                    final vendaId = (c['venda_id'] is int)
                        ? c['venda_id'] as int
                        : int.tryParse(c['venda_id']?.toString() ?? '');
                    final fornecedor = c['fornecedor']?.toString() ?? '';
                    final comprador = c['comprador']?.toString() ?? '';
                    final total = (c['total'] is num)
                        ? (c['total'] as num).toDouble()
                        : double.tryParse(c['total']?.toString() ?? '0') ?? 0.0;
                    final data = c['data_local']?.toString() ?? '';

                    return ListTile(
                      title: Text(fornecedor),
                      subtitle: Text('$comprador · $data'),
                      trailing: Text('R\$ ${total.toStringAsFixed(2)}'),
                      onTap: vendaId == null ? null : () => _abrirDetalheVenda(vendaId),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final String value;
  const _FiltroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
