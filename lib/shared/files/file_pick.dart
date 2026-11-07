import 'dart:convert';
import 'dart:typed_data';

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

  /// Escolhe um arquivo qualquer (anexo) e devolve nome e conteudo.
  /// Null = cancelou.
  static Future<({String name, Uint8List bytes})?> file({
    required List<String> extensions,
  }) async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final picked = r?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return null;
    return (name: picked.name, bytes: bytes);
  }

  /// Escolhe varios arquivos (fotos/exames). Lista vazia = cancelou.
  static Future<List<({String name, Uint8List bytes})>> files({
    required List<String> extensions,
  }) async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: true,
      withData: true,
    );
    return [
      for (final f in r?.files ?? const <PlatformFile>[])
        if (f.bytes != null) (name: f.name, bytes: f.bytes!),
    ];
  }
}
