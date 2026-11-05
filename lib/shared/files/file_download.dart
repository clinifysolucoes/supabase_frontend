import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

/// Entrega um arquivo gerado no app ao usuario: download no navegador,
/// pasta de downloads/documentos no celular. Devolve o caminho (vazio na web).
abstract final class FileDownload {
  static Future<String> saveXlsx({
    required String name,
    required Uint8List bytes,
  }) => FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );

  static Future<String> saveCsv({
    required String name,
    required Uint8List bytes,
  }) => FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: 'csv',
    mimeType: MimeType.csv,
  );
}
