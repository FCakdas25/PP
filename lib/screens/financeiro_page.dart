import 'package:flutter/material.dart';

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  // Dados (mock por enquanto)
  List<_Boleto> _todos = [];
  List<_Boleto> _visiveis = [];

  // KPIs
  int get kpiQtd => _visiveis.length;
  double get kpiValorTotal =>
      _visiveis.fold(0.0, (sum, b) => sum + b.valor);

  @override
  void initState() {
    super.initState();
    _loadData(); // mock → depois pluga no backend
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // TODO: substituir por chamada real ao backend:
    // ex.: final bol = await FinanceiroApi.listarVencidos();
    _todos = _seedMock();

    // ordena por data de vencimento (os mais antigos primeiro)
    _todos.sort((a, b) => a.vencimento.compareTo(b.vencimento));

    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    final q = _searchCtrl.text.trim().toLowerCase();

    _visiveis = _todos.where((b) {
      // apenas vencidos (regra da tela)
      if (!b.vencido) return false;

      // busca livre: número do boleto, associado, fornecedor, NF(s)
      if (q.isNotEmpty) {
        final hay = StringBuffer()
          ..write('${b.numero}|${b.associado}|${b.fornecedor}|${b.pedidoPallet}');
        for (final nf in b.notas) {
          hay.write('|${nf.numero}');
        }
        if (!hay.toString().toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {});
  }

  Future<void> _emitirPdf(_Boleto b) async {
    // TODO (backend): endpoint para gerar/concatenar PDF (Boleto + NF(s))
    // Exemplo de contrato:
    // POST /financeiro/boletos/{boletoId}/pdf
    // body: { nfs: [..ids..] } -> retorna URL/bytes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gerando PDF do boleto ${b.numero}… (mock)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro — Boletos Vencidos'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // === KPIs ===
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpiCard(
                  context,
                  title: 'Boletos Vencidos',
                  value: '$kpiQtd',
                  icon: Icons.receipt_long_outlined,
                ),
                _kpiCard(
                  context,
                  title: 'Valor Total',
                  value: _formatCurrency(kpiValorTotal),
                  icon: Icons.attach_money_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Busca ===
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => _aplicarFiltros(),
              decoration: InputDecoration(
                hintText: 'Buscar por boleto, associado, fornecedor ou NF…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // === Lista ===
            if (_visiveis.isEmpty)
              _emptyState(context)
            else
              ..._visiveis.map((b) => _boletoTile(context, b, text, scheme)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadData,
        icon: const Icon(Icons.refresh),
        label: const Text('Atualizar'),
      ),
    );
  }

  // ----------------- UI Helpers -----------------

  Widget _kpiCard(
      BuildContext context, {
        required String title,
        required String value,
        required IconData icon,
      }) {
    final scheme = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final boxWidth = w >= 560 ? (w - 16 - 16 - 12) / 2 : (w - 16 - 16);

    return SizedBox(
      width: boxWidth,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(.05),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boletoTile(
      BuildContext context,
      _Boleto b,
      TextTheme text,
      ColorScheme scheme,
      ) {
    final atrasoDias = b.atrasoDias;
    final atrasoColor = atrasoDias >= 10
        ? Colors.red.withOpacity(.12)
        : atrasoDias >= 3
        ? Colors.orange.withOpacity(.12)
        : Colors.yellow.withOpacity(.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      child: Theme(
        // remove splash forte do ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_outlined,
                color: scheme.onPrimaryContainer),
          ),
          title: Text(
            'Boleto ${b.numero}',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${b.associado} • ${b.fornecedor}',
                  style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                'Venc.: ${_formatDate(b.vencimento)}  •  ${_formatCurrency(b.valor)}',
                style: text.bodySmall,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: atrasoColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${atrasoDias}d',
                  style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          children: [
            // Notas relacionadas
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: b.notas
                    .map((nf) => _nfChip(
                  'NF ${nf.numero}',
                  subtitle: _formatCurrency(nf.valor),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Pedido / Pallet info (quando existir)
            if (b.pedidoPallet != null && b.pedidoPallet!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Pedido/Pallet: ${b.pedidoPallet!}'),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Ações
            Row(
              children: [
                _pill('Vencido em ${_formatDate(b.vencimento)}'),
                const SizedBox(width: 8),
                _pill('${b.notas.length} NF(s)'),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _emitirPdf(b),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Emitir PDF'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _nfChip(String text, {String? subtitle}) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(fontSize: 12)),
        ],
      ),
      avatar: const Icon(Icons.receipt_long_outlined, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
      ),
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 42),
          SizedBox(height: 8),
          Text('Sem boletos vencidos'),
          SizedBox(height: 4),
          Text('Puxe para atualizar ou refine sua busca.',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  // ----------------- Utils -----------------

  List<_Boleto> _seedMock() {
    final hoje = DateTime.now();
    return [
      _Boleto(
        id: 'BOL-001',
        numero: '341-123456-7',
        associado: 'SUPERMERCADO CALVI',
        fornecedor: 'BRF',
        vencimento: hoje.subtract(const Duration(days: 8)),
        valor: 5320.40,
        pedidoPallet: 'P-88022',
        notas: const [
          _NotaFiscal(numero: '145301', valor: 2190.10),
          _NotaFiscal(numero: '145302', valor: 3130.30),
        ],
      ),
      _Boleto(
        id: 'BOL-002',
        numero: '104-765432-1',
        associado: 'AUTO SERV IRMÃOS PIMENTEL',
        fornecedor: 'UNILEVER',
        vencimento: hoje.subtract(const Duration(days: 2)),
        valor: 1890.00,
        pedidoPallet: 'P-77110',
        notas: const [
          _NotaFiscal(numero: '145223', valor: 945.00),
          _NotaFiscal(numero: '145224', valor: 945.00),
        ],
      ),
      _Boleto(
        id: 'BOL-003',
        numero: '033-998877-0',
        associado: 'MERCADO TOP',
        fornecedor: 'QUÍMICA AMPARO',
        vencimento: hoje.subtract(const Duration(days: 15)),
        valor: 10450.00,
        pedidoPallet: 'P-88041',
        notas: const [
          _NotaFiscal(numero: '145402', valor: 10450.00),
        ],
      ),
    ];
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatCurrency(double v) {
    // formatação simples pt-BR sem intl
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    final parts = s.split(',');
    String intPart = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final idx = intPart.length - i;
      buf.write(intPart[i]);
      final pos = i + 1;
      final remaining = intPart.length - pos;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    final milhar = buf.toString();
    return 'R\$ $milhar,${parts[1]}';
  }
}

// --------- Modelos (mock) ---------
class _Boleto {
  final String id;
  final String numero;
  final String associado;
  final String fornecedor;
  final DateTime vencimento;
  final double valor;
  final String? pedidoPallet;
  final List<_NotaFiscal> notas;

  const _Boleto({
    required this.id,
    required this.numero,
    required this.associado,
    required this.fornecedor,
    required this.vencimento,
    required this.valor,
    required this.notas,
    this.pedidoPallet,
  });

  bool get vencido {
    final hoje = DateTime.now();
    final hoje00 = DateTime(hoje.year, hoje.month, hoje.day);
    final ven00 = DateTime(vencimento.year, vencimento.month, vencimento.day);
    return ven00.isBefore(hoje00);
  }

  int get atrasoDias {
    final hoje = DateTime.now();
    return hoje.difference(vencimento).inDays;
  }
}

class _NotaFiscal {
  final String numero;
  final double valor;
  const _NotaFiscal({required this.numero, required this.valor});
}
