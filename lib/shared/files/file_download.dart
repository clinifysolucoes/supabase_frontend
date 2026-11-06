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

  /// Arquivo baixado (anexo): nome original com a extensao.
  static Future<String> saveFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : '';
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: ext,
      mimeType: switch (ext) {
        'pdf' => MimeType.pdf,
        'jpg' || 'jpeg' => MimeType.jpeg,
        'png' => MimeType.png,
        _ => MimeType.other,
      },
    );
  }

  static Future<String> savePdf({
    required String name,
    required Uint8List bytes,
  }) => FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
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
