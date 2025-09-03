import 'package:flutter/material.dart';

// telas
import 'package:app_vendas/screens/login_page.dart';
import 'package:app_vendas/screens/home_page.dart';

// novas telas (categorias de compras + lista e detalhe)
import 'package:app_vendas/screens/compras_categorias_page.dart';
import 'package:app_vendas/screens/compras_associados_page.dart';
import 'package:app_vendas/screens/negociacao_detalhe_page.dart';

// páginas novas
import 'package:app_vendas/screens/logistica_page.dart';
import 'package:app_vendas/screens/financeiro_page.dart';

// splash
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

        // Fluxo COMPRAS → categorias (HORTIFRUTI / GELADO / SECO)
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

        // Placeholder antigo (se ainda precisar)
        '/estoque_nucleo': (_) => Scaffold(
          appBar: AppBar(title: const Text('Estoque Núcleo')),
          body: const Center(child: Text('Em breve: painel de estoque do núcleo.')),
        ),

        // Páginas novas
        '/logistica': (_) => const LogisticaPage(),
        '/financeiro': (_) => const FinanceiroPage(),
      },
    );
  }
}
