// lib/screens/home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<_AssociadoInfo> _loadInfo() async {
    final sp = await SharedPreferences.getInstance();

    Map<String, dynamic>? associado;
    final rawAssoc = sp.getString('associado');
    if (rawAssoc != null && rawAssoc.trim().isNotEmpty) {
      try {
        associado = json.decode(rawAssoc) as Map<String, dynamic>;
      } catch (_) {}
    }

    Map<String, dynamic>? payload;
    final rawPayload = sp.getString('user_payload');
    if (rawPayload != null && rawPayload.trim().isNotEmpty) {
      try {
        payload = json.decode(rawPayload) as Map<String, dynamic>;
      } catch (_) {}
    }

    String nome = _firstNonEmpty([
      associado?['Nome']?.toString(),
      associado?['nome']?.toString(),
      payload?['name']?.toString(),
      payload?['nome']?.toString(),
    ], fallback: 'Não identificado');

    String codigo = _firstNonEmpty([
      associado?['Codigo']?.toString(),
      associado?['codigo']?.toString(),
      payload?['codigo']?.toString(),
    ], fallback: '—');

    String loja = _firstNonEmpty([
      associado?['Loja']?.toString(),
      associado?['loja']?.toString(),
    ], fallback: '');

    String comprador = _firstNonEmpty([
      associado?['Comprador']?.toString(),
      associado?['comprador']?.toString(),
    ], fallback: '');

    return _AssociadoInfo(
      nome: nome,
      codigo: codigo,
      loja: loja,
      comprador: comprador,
    );
  }

  String _firstNonEmpty(List<String?> candidates, {required String fallback}) {
    for (final s in candidates) {
      if (s != null) {
        final t = s.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return fallback;
  }

  void _go(String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget actionCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required String route,
      String? semanticsLabel,
      String? tooltip,
    }) {
      return Semantics(
        button: true,
        label: semanticsLabel ?? title,
        child: Tooltip(
          message: tooltip ?? title,
          child: InkWell(
            onTap: () => _go(route),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(.06),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Compras'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: FutureBuilder<_AssociadoInfo>(
            future: _loadInfo(),
            builder: (context, snap) {
              final loading = snap.connectionState != ConnectionState.done;
              final data = snap.data ??
                  const _AssociadoInfo(
                    nome: 'Carregando...',
                    codigo: '—',
                    loja: '',
                    comprador: '',
                  );

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // CARD DO ASSOCIADO (TOPO)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  child: Icon(Icons.person, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dados do Associado',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        loading ? 'Carregando...' : data.nome,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Atualizar',
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _infoRow('Código', data.codigo),
                            if (data.loja.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _infoRow('Loja', data.loja),
                            ],
                            if (data.comprador.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _infoRow('Comprador', data.comprador),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== 3 CARDS PRINCIPAIS =====
                    actionCard(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Compras Associados',
                      subtitle: 'Categorias: Hortifruti, Gelado e Seco',
                      route: '/compras_categorias',
                      semanticsLabel: 'Abrir compras por categorias do associado',
                    ),
                    const SizedBox(height: 12),

                    actionCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'Logística',
                      subtitle: 'Retiradas faturadas e agendamentos',
                      route: '/logistica',
                      semanticsLabel: 'Abrir área de Logística',
                    ),
                    const SizedBox(height: 12),

                    actionCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Financeiro',
                      subtitle: 'Boletos vencidos e a vencer',
                      route: '/financeiro',
                      semanticsLabel: 'Abrir área de Financeiro',
                    ),

                    const SizedBox(height: 40),

                    // ===== LOGO GRANDE NO RODAPÉ =====
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          'assets/logo_baixo.png',
                          height: 150, // pode aumentar para 150 ou 200 se quiser
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          semanticLabel: 'Logo da empresa',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const Text(':  '),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AssociadoInfo {
  final String nome;
  final String codigo;
  final String loja;
  final String comprador;

  const _AssociadoInfo({
    required this.nome,
    required this.codigo,
    required this.loja,
    required this.comprador,
  });
}
