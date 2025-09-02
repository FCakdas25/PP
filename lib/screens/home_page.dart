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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Compras'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Marca d'água ao fundo (opcional)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/WhatsApp Image 2025-08-06 at 08.03.35.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
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
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dados do Associado',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                fontWeight:
                                                FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            loading
                                                ? 'Carregando...'
                                                : data.nome,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
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

                        // BOTÕES (APENAS 3)
                        _BigActionButton(
                          label: 'COMPRAS ASSOCIADOS',
                          icon: Icons.shopping_bag_outlined,
                          onTap: () {
                            // <<< CORRIGIDO: abre a tela com os 3 botões (HORTIFRUTI/GELADO/SECO)
                            Navigator.pushNamed(context, '/compras_categorias');
                          },
                        ),
                        const SizedBox(height: 12),
                        _BigActionButton(
                          label: 'DADOS ASSOCIADOS',
                          icon: Icons.info_outline,
                          onTap: () {
                            Navigator.pushNamed(context, '/dados_associados');
                          },
                        ),
                        const SizedBox(height: 12),
                        _BigActionButton(
                          label: 'ESTOQUE NÚCLEO',
                          icon: Icons.inventory_2_outlined,
                          onTap: () {
                            Navigator.pushNamed(context, '/estoque_nucleo');
                          },
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
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

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
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
