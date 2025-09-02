// lib/core/conv_parser.dart
class ConvCheckinData {
  final String fornecedor;
  final String uid;

  const ConvCheckinData({required this.fornecedor, required this.uid});
}

class ConvParser {
  static final _begin =
  RegExp(r'^\s*convbegin\s*$', caseSensitive: false, multiLine: true);
  static final _end =
  RegExp(r'^\s*convend\s*$', caseSensitive: false, multiLine: true);
  static final _fornecedor =
  RegExp(r'^\s*Fornecedor\s*:\s*(.+?)\s*$', caseSensitive: false);
  static final _uid =
  RegExp(r'^\s*UID\s*:\s*([A-Za-z0-9_-]+)\s*$', caseSensitive: false);

  /// Ex.: texto do QR completo
  static ConvCheckinData parse(String raw) {
    final lines =
    raw.split(RegExp(r'\r?\n')).map((e) => e.trimRight()).toList();

    final hasBegin = lines.any(_begin.hasMatch);
    final hasEnd = lines.any(_end.hasMatch);
    if (!hasBegin || !hasEnd) {
      throw const FormatException('Formato inválido: faltando convbegin/convend');
    }

    String? fornecedor;
    String? uid;

    for (final l in lines) {
      final mForn = _fornecedor.firstMatch(l);
      if (mForn != null) fornecedor = mForn.group(1)?.trim();

      final mUid = _uid.firstMatch(l);
      if (mUid != null) uid = mUid.group(1)?.trim();
    }

    if (fornecedor == null || fornecedor.isEmpty || uid == null || uid.isEmpty) {
      throw const FormatException('Formato inválido: Fornecedor/UID ausentes');
    }

    return ConvCheckinData(fornecedor: fornecedor, uid: uid);
  }
}
