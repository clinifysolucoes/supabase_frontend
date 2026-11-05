import 'dart:convert';

import 'package:file_picker/file_picker.dart';

/// Escolhe um arquivo de texto (web, celular, desktop) e devolve o conteudo.
/// Null = cancelou. Tenta UTF-8 e cai para Latin-1 (extratos OFX de bancos
/// brasileiros costumam vir em ISO-8859-1).
abstract final class FilePick {
  static Future<String?> text({required List<String> extensions}) async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final bytes = r?.files.single.bytes;
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
