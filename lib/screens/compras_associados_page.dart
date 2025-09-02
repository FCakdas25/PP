import 'package:flutter/material.dart';
import '../services/compras_service.dart';

class ComprasAssociadosPage extends StatefulWidget {
  final String categoriaKey;
  final String? categoriaTitulo;

  const ComprasAssociadosPage({
    super.key,
    required this.categoriaKey,
    this.categoriaTitulo,
  });

  static Widget fromArgs(Map<String, dynamic>? args) {
    final key = (args?['categoriaKey'] as String?) ?? 'hortifruti';
    final titulo = args?['categoriaTitulo'] as String?;
    return ComprasAssociadosPage(categoriaKey: key, categoriaTitulo: titulo);
  }

  @override
  State<ComprasAssociadosPage> createState() => _ComprasAssociadosPageState();
}

class _ComprasAssociadosPageState extends State<ComprasAssociadosPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ComprasService.listarNegociacoesAbertas(widget.categoriaKey);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.categoriaTitulo ?? widget.categoriaKey.toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text('Negociações — $title')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Falha ao carregar: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma negociação aberta.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];

              final desc = (n['descricao'] ?? n['Descricao'] ?? '').toString();
              final dtAbert = (n['dataAbertura'] ?? '').toString();
              final dtIni = (n['dataInicioEncarte'] ?? '').toString();
              final dtFim = (n['dataFimEncarte'] ?? '').toString();
              final qtdFor = (n['qtdFornecedores'] ?? 0).toString();
              final qtdIt = (n['qtdItens'] ?? 0).toString();

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    if (dtAbert.isNotEmpty) 'Abertura: $dtAbert',
                    if (dtIni.isNotEmpty || dtFim.isNotEmpty) 'Período: $dtIni → $dtFim',
                    'Fornecedores: $qtdFor | Itens: $qtdIt',
                  ].join('\n')),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final id = n['id'] ?? n['ID'] ?? n['idNegociacao'];
                    Navigator.pushNamed(context, '/negociacao_detalhe', arguments: {
                      'negociacaoId': id,
                      'descricao': desc,
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
