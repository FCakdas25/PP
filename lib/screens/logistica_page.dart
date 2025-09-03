// lib/screens/logistica_page.dart
import 'package:flutter/material.dart';

class LogisticaPage extends StatefulWidget {
  const LogisticaPage({super.key});

  @override
  State<LogisticaPage> createState() => _LogisticaPageState();
}

class _LogisticaPageState extends State<LogisticaPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  // filtros simples
  String _filtroStatus = 'TODOS'; // TODOS | HOJE | ATRASADOS
  String? _filtroLoja;
  String? _filtroFornecedor;

  // dados (mock por enquanto)
  List<_CargaPendente> _todas = [];
  List<_CargaPendente> _visiveis = [];

  // KPIs
  int get kpiQtd => _visiveis.length;
  double get kpiValor => _visiveis.fold(0, (p, e) => p + e.valorTotal);
  int get kpiVolumes => _visiveis.fold(0, (p, e) => p + e.volumes);

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
    // TODO: substituir por chamada real ao backend
    // Ex.: final itens = await LogisticaApi.listarPendentes(filtros...)
    _todas = _seedMock();
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    final q = _searchCtrl.text.trim().toLowerCase();

    _visiveis = _todas.where((e) {
      // status
      if (_filtroStatus == 'HOJE' && !e.entregaHoje) return false;
      if (_filtroStatus == 'ATRASADOS' && !e.atrasado) return false;

      // loja/fornecedor
      if (_filtroLoja != null && _filtroLoja!.isNotEmpty && e.loja != _filtroLoja) return false;
      if (_filtroFornecedor != null && _filtroFornecedor!.isNotEmpty && e.fornecedor != _filtroFornecedor) return false;

      // busca livre (NF, pedido, loja, fornecedor)
      if (q.isNotEmpty) {
        final hay = '${e.notaFiscal}|${e.pedido}|${e.loja}|${e.fornecedor}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Ordenação padrão: atrasados primeiro, depois por data de retirada prevista
    _visiveis.sort((a, b) {
      if (a.atrasado != b.atrasado) return a.atrasado ? -1 : 1;
      return a.dataRetiradaPrevista.compareTo(b.dataRetiradaPrevista);
    });

    setState(() {});
  }

  // listas para filtros (do mock; no backend virão da API)
  List<String> get _lojas =>
      _todas.map((e) => e.loja).toSet().toList()..sort();
  List<String> get _fornecedores =>
      _todas.map((e) => e.fornecedor).toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logística'),
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
                  title: 'Notas/Pedidos',
                  value: '$kpiQtd',
                  icon: Icons.receipt_long_outlined,
                ),
                _kpiCard(
                  context,
                  title: 'Volumes',
                  value: '$kpiVolumes',
                  icon: Icons.inventory_2_outlined,
                ),
                _kpiCard(
                  context,
                  title: 'Valor Total',
                  value: _formatCurrency(kpiValor),
                  icon: Icons.attach_money_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // === Filtros ===
            _filtros(context),

            const SizedBox(height: 12),

            // === Lista ===
            if (_visiveis.isEmpty)
              _emptyState(context)
            else
              ..._visiveis.map((c) => _cargaCard(context, c, text, scheme)),
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

  // ----------------- Widgets -----------------

  Widget _kpiCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    final scheme = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final boxWidth = w >= 560 ? (w - 16 - 16 - 12 * 2) / 3 : (w - 16 - 16);

    return SizedBox(
      width: boxWidth,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
          boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(.05))],
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // busca
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => _aplicarFiltros(),
          decoration: InputDecoration(
            hintText: 'Buscar por NF, Pedido, Loja ou Fornecedor…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // filtros rápidos: status
        Wrap(
          spacing: 8,
          children: [
            _chip('Todos', 'TODOS', Icons.all_inbox_outlined),
            _chip('Hoje', 'HOJE', Icons.event_available_outlined),
            _chip('Atrasados', 'ATRASADOS', Icons.warning_amber_outlined),
          ],
        ),
        const SizedBox(height: 10),

        // filtros dropdown: loja e fornecedor
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _filtroLoja,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Loja (Associado)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ..._lojas.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                ],
                onChanged: (v) {
                  _filtroLoja = v;
                  _aplicarFiltros();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _filtroFornecedor,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Fornecedor',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ..._fornecedores.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                ],
                onChanged: (v) {
                  _filtroFornecedor = v;
                  _aplicarFiltros();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    final selected = _filtroStatus == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) {
        _filtroStatus = value;
        _aplicarFiltros();
      },
    );
  }

  Widget _cargaCard(
      BuildContext context,
      _CargaPendente c,
      TextTheme text,
      ColorScheme scheme,
      ) {
    Color badgeColor;
    String badgeText;
    if (c.atrasado) {
      badgeColor = Colors.red.withOpacity(.12);
      badgeText = 'ATRASADO';
    } else if (c.entregaHoje) {
      badgeColor = Colors.orange.withOpacity(.12);
      badgeText = 'HOJE';
    } else {
      badgeColor = Colors.green.withOpacity(.12);
      badgeText = 'AGENDADO';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
        boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(.05))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // título linha 1
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_shipping_outlined, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'NF ${c.notaFiscal}  •  Pedido ${c.pedido}',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // infos principais
            _infoRow('Loja', c.loja),
            _infoRow('Fornecedor', c.fornecedor),
            _infoRow('Faturamento', _formatDate(c.dataFaturamento)),
            _infoRow('Retirada prevista', _formatDate(c.dataRetiradaPrevista)),
            const SizedBox(height: 6),

            // volumes e valor
            Row(
              children: [
                _pill('${c.volumes} vol.'),
                const SizedBox(width: 8),
                _pill(_formatCurrency(c.valorTotal)),
                const Spacer(),
                IconButton(
                  tooltip: 'Ver detalhes',
                  onPressed: () {
                    // TODO: navegar para detalhe futuro
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Detalhe da carga (em breve)')),
                    );
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
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
          Text('Nada por aqui…'),
          SizedBox(height: 4),
          Text('Ajuste os filtros ou puxe para atualizar.', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const Text(':  '),
          Expanded(child: Text(v, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }

  // ----------------- Utils -----------------

  List<_CargaPendente> _seedMock() {
    final hoje = DateTime.now();
    return [
      _CargaPendente(
        notaFiscal: '145223',
        pedido: 'P-88011',
        loja: 'AUTO SERV IRMÃOS PIMENTEL',
        fornecedor: 'BRF',
        dataFaturamento: hoje.subtract(const Duration(days: 1)),
        dataRetiradaPrevista: hoje, // hoje
        volumes: 12,
        valorTotal: 5820.75,
      ),
      _CargaPendente(
        notaFiscal: '145301',
        pedido: 'P-88022',
        loja: 'SUPERMERCADO CALVI',
        fornecedor: 'UNILEVER',
        dataFaturamento: hoje.subtract(const Duration(days: 3)),
        dataRetiradaPrevista: hoje.subtract(const Duration(days: 1)), // atrasado
        volumes: 7,
        valorTotal: 2190.10,
      ),
      _CargaPendente(
        notaFiscal: '145402',
        pedido: 'P-88041',
        loja: 'MERCADO TOP',
        fornecedor: 'QUÍMICA AMPARO',
        dataFaturamento: hoje.subtract(const Duration(days: 2)),
        dataRetiradaPrevista: hoje.add(const Duration(days: 1)), // agendado amanhã
        volumes: 20,
        valorTotal: 10350.00,
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
    // formatação simples PT-BR (sem package intl)
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

// --------- Modelo (mock) ---------
class _CargaPendente {
  final String notaFiscal;
  final String pedido;
  final String loja;
  final String fornecedor;
  final DateTime dataFaturamento;
  final DateTime dataRetiradaPrevista;
  final int volumes;
  final double valorTotal;

  _CargaPendente({
    required this.notaFiscal,
    required this.pedido,
    required this.loja,
    required this.fornecedor,
    required this.dataFaturamento,
    required this.dataRetiradaPrevista,
    required this.volumes,
    required this.valorTotal,
  });

  bool get entregaHoje {
    final now = DateTime.now();
    return dataRetiradaPrevista.year == now.year &&
        dataRetiradaPrevista.month == now.month &&
        dataRetiradaPrevista.day == now.day;
  }

  bool get atrasado => dataRetiradaPrevista.isBefore(
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );
}
