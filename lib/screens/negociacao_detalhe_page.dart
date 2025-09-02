import 'package:flutter/material.dart';
import '../services/compras_service.dart';

class NegociacaoDetalhePage extends StatefulWidget {
  final int negociacaoId;
  final String? descricao;

  const NegociacaoDetalhePage({
    super.key,
    required this.negociacaoId,
    this.descricao,
  });

  static Widget fromArgs(Map<String, dynamic>? args) {
    final id = (args?['negociacaoId'] as num?)?.toInt();
    final desc = args?['descricao'] as String?;
    return NegociacaoDetalhePage(negociacaoId: id ?? 0, descricao: desc);
  }

  @override
  State<NegociacaoDetalhePage> createState() => _NegociacaoDetalhePageState();
}

class _NegociacaoDetalhePageState extends State<NegociacaoDetalhePage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ComprasService.listarItensNegociacao(widget.negociacaoId);
  }

  String _fmtPreco(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    return 'R\$ ${n.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descricao ?? 'Negociação #${widget.negociacaoId}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro ao carregar itens: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Nenhum item nesta negociação.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final it = items[index];
              final nome = (it['nome'] ?? '').toString();
              final cadmer = (it['cadmer'] ?? '').toString();
              final fator = (it['fator'] ?? '').toString();
              final preco = _fmtPreco(it['preco']);

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  title: Text(nome.isNotEmpty ? nome : 'CADMER $cadmer',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('CADMER: $cadmer   •   Fator: $fator'),
                  trailing: Text(preco,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
