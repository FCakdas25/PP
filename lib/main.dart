import 'package:flutter/material.dart';

// telas
import 'package:app_vendas/screens/login_page.dart';
import 'package:app_vendas/screens/home_page.dart';
import 'package:app_vendas/screens/fornecedores_visitados.dart';
import 'package:app_vendas/screens/itens_venda.dart';
import 'package:app_vendas/screens/vendas_page.dart';
import 'package:app_vendas/screens/programacao_page.dart';
import 'package:app_vendas/pages/compras_loja_page.dart';

// novas telas (categorias de compras + lista e detalhe)
import 'package:app_vendas/screens/compras_categorias_page.dart';
import 'package:app_vendas/screens/compras_associados_page.dart';
import 'package:app_vendas/screens/negociacao_detalhe_page.dart';

// splash novo
import 'package:app_vendas/screens/splash_page.dart';

// opcional: imprimir base da API na inicialização
import 'config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print('🚀 API_BASE em uso: ${AppConfig.apiBase}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Vendas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF70845F),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),

        // Home unificada (mantém aliases para compat)
        '/home': (_) => const HomePage(),
        '/home_ccb': (_) => const HomePage(),
        '/home_associados': (_) => const HomePage(),

        // Fluxo COMPRAS → tela de categorias (HORTIFRUTI / GELADO / SECO)
        '/compras_categorias': (_) => const ComprasCategoriasPage(),

        // Lista de negociações abertas por categoria
        '/compras_associados': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ComprasAssociadosPage.fromArgs(args);
        },

        // Detalhe da negociação (itens/mercadorias)
        '/negociacao_detalhe': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return NegociacaoDetalhePage.fromArgs(args);
        },

        // Demais rotas existentes
        '/fornecedores': (_) => const FornecedoresVisitadosPage(),
        '/compras_loja': (_) => const ComprasLojaPage(),

        // Alias para "DADOS ASSOCIADOS" (até termos a tela dedicada)
        '/dados_associados': (_) => const ComprasLojaPage(),
        '/info': (_) => const ComprasLojaPage(),

        '/programacao': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
          return ProgramacaoPage.fromArgs(map);
        },
        '/itens': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
          return ItensVendaPage.fromArgs(map);
        },
        '/vendas': (_) => const VendasPage(),

        // Placeholder para "ESTOQUE NÚCLEO" (rota já pronta para o botão da Home)
        '/estoque_nucleo': (_) => Scaffold(
          appBar: AppBar(title: const Text('Estoque Núcleo')),
          body: const Center(child: Text('Em breve: painel de estoque do núcleo.')),
        ),
      },
    );
  }
}
