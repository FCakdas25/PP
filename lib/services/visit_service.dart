// lib/services/visit_service.dart
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class VisitService extends ChangeNotifier {
  static final VisitService I = VisitService._();
  VisitService._();

  // status por fornecedor: visited = abriu a tela/visualizou; checkin = leu QR no estande
  final Map<int, _VisitStatus> _status = {};

  _VisitStatus _get(int fornecedorId) =>
      _status.putIfAbsent(fornecedorId, () => _VisitStatus());

  void markVisited(int fornecedorId) {
    final s = _get(fornecedorId);
    if (!s.visited) {
      s.visited = true;
      notifyListeners();
    }
  }

  void markCheckin(int fornecedorId) {
    final s = _get(fornecedorId);
    s.visited = true;
    s.checkin = true;
    notifyListeners();
  }

  bool isVisited(int fornecedorId) => _get(fornecedorId).visited;
  bool isCheckedIn(int fornecedorId) => _get(fornecedorId).checkin;

  /// regra de negócio: só fecha venda se tiver check-in
  bool canCloseSale(int fornecedorId) => isCheckedIn(fornecedorId);

  /// (Opcional) registra check-in também no backend
  /// Chame isso após ler o QR code do estande.
  /// - associadoCodigo: código do associado logado
  /// - fornecedorUid / fornecedorNome: vindos do QR
  Future<bool> registrarCheckin({
    required int fornecedorId,
    required String associadoCodigo,
    String? fornecedorUid,
    String? fornecedorNome,
  }) async {
    try {
      final resp = await AuthService.I.post('/checkin', {
        'AssociadoCodigo': associadoCodigo,
        'FornecedorID': fornecedorId,
        if (fornecedorUid != null) 'FornecedorUID': fornecedorUid,
        if (fornecedorNome != null) 'FornecedorNome': fornecedorNome,
      });

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        markCheckin(fornecedorId);
        return true;
      }
      // pode logar resp.body para debug
      return false;
    } catch (_) {
      return false;
    }
  }
}

class _VisitStatus {
  bool visited = false;
  bool checkin = false;
}
