import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regra do projeto: o Supabase so e tocado por `core/supabase/supabase_gateway.dart`
/// (e inicializado em `main.dart`). Nenhuma tabela e lida direto: todo dado
/// vem de RPC que valida a sessao no banco. Este teste e a garantia mecanica.
void main() {
  final lib = Directory('lib');
  const gateway = 'lib/core/supabase/supabase_gateway.dart';
  const allowedImports = {gateway, 'lib/main.dart'};

  List<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File f) => f.path.replaceAll(r'\', '/');

  /// Remove comentarios de linha para nao pegar exemplos na documentacao.
  String code(File f) => f.readAsStringSync().replaceAll(RegExp(r'//.*'), '');

  test('somente o gateway importa supabase_flutter', () {
    final offenders = <String>[];
    for (final file in dartFiles()) {
      if (code(file).contains('package:supabase_flutter/') &&
          !allowedImports.contains(rel(file))) {
        offenders.add(rel(file));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Importe o gateway, nao o Supabase: $offenders',
    );
  });

  test('ninguem usa .from( nem .schema( fora do gateway', () {
    final pattern = RegExp(r'\.(from|schema)\s*\(');
    final offenders = <String>[];
    for (final file in dartFiles()) {
      if (rel(file) == gateway) continue;
      if (pattern.hasMatch(code(file))) offenders.add(rel(file));
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Acesso direto ao Supabase em: $offenders',
    );
  });

  test('o gateway nao usa tabelas (.from) em lugar nenhum', () {
    // .storage.from(bucket) e o Storage (upload por URL assinada de Edge
    // Function), nao tabela: e a unica forma permitida
    final source = code(
      File(gateway),
    ).replaceAll(RegExp(r'\.storage\s*\.from\s*\('), '');
    expect(
      RegExp(r'\.from\s*\(').hasMatch(source),
      isFalse,
      reason: 'Toda leitura e escrita passa por RPC (function no banco).',
    );
  });
}
