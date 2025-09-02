import 'package:flutter/material.dart';

enum CategoriaCompra { hortifruti, gelado, seco }

class ComprasCategoriasPage extends StatelessWidget {
  const ComprasCategoriasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categorias = <_CategoriaDef>[
      _CategoriaDef(
        key: CategoriaCompra.hortifruti,
        titulo: 'HORTIFRUTI',
        icone: Icons.eco_outlined,
        descricao: 'Frutas, verduras e legumes',
      ),
      _CategoriaDef(
        key: CategoriaCompra.gelado,
        titulo: 'GELADO',
        icone: Icons.ac_unit_outlined,
        descricao: 'Resfriados e congelados',
      ),
      _CategoriaDef(
        key: CategoriaCompra.seco,
        titulo: 'SECO',
        icone: Icons.inventory_2_outlined,
        descricao: 'Mercearia, limpeza, secos',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras por Categoria'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Marca d’água opcional (mesma usada na Home)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: Image.asset(
                  'assets/WhatsApp Image 2025-08-06 at 08.03.35.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Selecione uma categoria',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid com os 3 botões
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        final crossAxisCount = isWide ? 3 : 1;

                        return GridView.builder(
                          itemCount: categorias.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isWide ? 1.1 : 3.2,
                          ),
                          itemBuilder: (context, index) {
                            final c = categorias[index];
                            return _CategoriaCard(
                              titulo: c.titulo,
                              icone: c.icone,
                              descricao: c.descricao,
                              onTap: () {
                                // Navega para a próxima etapa já com a categoria escolhida.
                                Navigator.pushNamed(
                                  context,
                                  '/compras_associados', // próxima tela (lista de negociações)
                                  arguments: {
                                    'categoriaKey': c.key.name,  // 'hortifruti' | 'gelado' | 'seco'
                                    'categoriaTitulo': c.titulo, // rótulo bonitinho
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final IconData icone;
  final VoidCallback onTap;

  const _CategoriaCard({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Icon(icone, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriaDef {
  final CategoriaCompra key;
  final String titulo;
  final IconData icone;
  final String descricao;

  _CategoriaDef({
    required this.key,
    required this.titulo,
    required this.icone,
    required this.descricao,
  });
}
