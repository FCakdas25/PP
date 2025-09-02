import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ProgramacaoPage extends StatefulWidget {
  final int fornecedorId;
  final String? fornecedorNome;

  /// Opcional: lista já carregada (vinda da tela anterior) para evitar novo GET
  final List<Map<String, dynamic>>? programacoesPrefetched;

  const ProgramacaoPage({
    super.key,
    required this.fornecedorId,
    this.fornecedorNome,
    this.programacoesPrefetched,
  });

  static Widget fromArgs(Map<String, dynamic> args) {
    return ProgramacaoPage(
      fornecedorId: args['fornecedorId'] as int,
      fornecedorNome: args['fornecedorNome'] as String?,
      programacoesPrefetched: (args['programacoes'] is List)
          ? (args['programacoes'] as List)
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList()
          : null,
    );
  }

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool _loading = true;
  String? _erro;
  List<_Prog> _programacoes = [];

  @override
  void initState() {
    super.initState();
    // Se já veio a lista por argumentos, usa; senão, busca na API
    if (widget.programacoesPrefetched != null &&
        widget.programacoesPrefetched!.isNotEmpty) {
      _programacoes = _parseList(widget.programacoesPrefetched!);
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final resp = await AuthService.I
          .get('/ccb/fornecedores/${widget.fornecedorId}/programacoes')
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        final list = (data is List)
            ? data
            : (data is Map && data['items'] is List ? data['items'] : const []);
        _programacoes = _parseList(list);
      } else if (resp.statusCode == 204) {
        _programacoes = [];
      } else if (resp.statusCode == 401) {
        _erro = 'Sessão expirada. Faça login novamente.';
      } else {
        _erro = 'Falha ${resp.statusCode} ao carregar programação.';
      }
    } catch (e) {
      _erro = 'Erro de conexão: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Prog> _parseList(dynamic listDyn) {
    final list = (listDyn is List) ? listDyn : const [];
    // Backend novo retorna: programacao_id, fornecedor_id, label, ordem, data_entrada, ativo
    // Mantemos compat com possíveis campos em maiúsculas.
    String? _toStr(Map m, String a, [String? b, String? c]) {
      for (final k in [a, b, c].whereType<String>()) {
        final v = m[k] ?? m[_swapCase(k)];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    int? _toInt(Map m, String a, [String? b]) {
      for (final k in [a, b].whereType<String>()) {
        final v = m[k] ?? m[_swapCase(k)];
        if (v is num) return v.toInt();
        final s = v?.toString();
        final parsed = int.tryParse(s ?? '');
        if (parsed != null) return parsed;
      }
      return null;
    }

    String _fmtDataLabel(String? iso) {
      // Espera "YYYY-MM-DD..." -> "DD/MM"
      if (iso == null || iso.isEmpty) return 'Programação';
      final p = iso.split('T')[0].split('-'); // [yyyy, mm, dd]
      if (p.length >= 3) {
        final dd = p[2].padLeft(2, '0');
        final mm = p[1].padLeft(2, '0');
        return 'Entrada $dd/$mm';
      }
      return 'Programação';
    }

    final progs = list.whereType<Map>().map<_Prog>((raw) {
      final m = raw.map((k, v) => MapEntry(k.toString(), v));

      final ordem = _toInt(m, 'ordem', 'Ordem') ?? 9999;
      final label = _toStr(m, 'label', 'Label', 'ProgramacaoDias');
      final dataEnt = _toStr(m, 'data_entrada', 'DataEntrada');

      final effectiveLabel = label ?? _fmtDataLabel(dataEnt);
      return _Prog(label: effectiveLabel, ordem: ordem);
    }).toList();

    progs.sort((a, b) => (a.ordem).compareTo(b.ordem));
    return progs;
  }

  String _swapCase(String s) {
    // troca camel por Pascal ou vice-versa simples (aqui só para Label/Ordem/DataEntrada)
    if (s.isEmpty) return s;
    final first = s[0];
    final swappedFirst =
    first == first.toUpperCase() ? first.toLowerCase() : first.toUpperCase();
    return swappedFirst + s.substring(1);
  }

  void _abrirItens(_Prog p) {
    Navigator.pushNamed(
      context,
      '/itens',
      arguments: {
        'fornecedorId': widget.fornecedorId,
        'fornecedorNome': widget.fornecedorNome,
        // Passa o RÓTULO textual:
        'programacaoLabel': p.label,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.fornecedorNome ?? 'Fornecedor ${widget.fornecedorId}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Programação - $titulo'),
        backgroundColor: const Color(0xFF70845F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_erro != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_erro!),
        ),
      )
          : _programacoes.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sem programação para este fornecedor.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _abrirItens(
                  _Prog(label: 'Sem programação', ordem: 9999),
                ),
                child: const Text('Ir para itens'),
              ),
            ],
          ),
        ),
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // ocupa pelo menos a altura da viewport
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: _programacoes.map((p) {
                      return SizedBox(
                        width: 180,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _abrirItens(p),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF70845F),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            p.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Prog {
  final String label;
  final int ordem;
  _Prog({required this.label, required this.ordem});
}
