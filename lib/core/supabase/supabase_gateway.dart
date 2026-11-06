import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../errors/app_error.dart';
import 'mfa_types.dart';

/// UNICO ponto do app que fala com o Supabase.
///
/// Regras (ver CLAUDE.md):
///   * Nenhuma tabela e lida ou escrita direto (`from(...)` nao existe aqui).
///   * Todo dado passa por RPC do schema `ad`, que valida a sessao no banco.
///   * Auth (signIn/signOut/sessao) e o Supabase Auth; e a unica excecao.
///   * Storage so por URL assinada que uma Edge Function gerou depois de
///     validar a permissao numa RPC (anexos do financeiro).
///
/// O teste `test/no_direct_supabase_access_test.dart` garante que nenhum outro
/// arquivo importa `supabase_flutter` nem acessa tabela direto.
class SupabaseGateway {
  SupabaseGateway(this._client);

  final SupabaseClient _client;

  static Future<void> initialize() => Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  bool get hasSession => _client.auth.currentSession != null;

  /// uuid do usuario no Supabase Auth (null sem sessao).
  String? get authUserId => _client.auth.currentUser?.id;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw _fromAuth(e);
    } catch (e) {
      throw AppError.unexpected(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _fromAuth(e);
    }
  }

  // --- 2FA (app autenticador / TOTP) ---------------------------------------

  /// Nivel da sessao e fatores da conta.
  Future<MfaStatus> mfaStatus() async {
    try {
      final level = _client.auth.mfa.getAuthenticatorAssuranceLevel();
      final factors = _client.auth.currentUser?.factors ?? const [];
      return MfaStatus(
        currentAal: level.currentLevel?.name ?? 'aal1',
        nextAal: level.nextLevel?.name,
        factors: [
          for (final f in factors)
            if (f.factorType == FactorType.totp)
              MfaFactor(
                id: f.id,
                name: f.friendlyName,
                verified: f.status == FactorStatus.verified,
              ),
        ],
      );
    } on AuthException catch (e) {
      throw _fromAuth(e);
    }
  }

  /// Comeca o cadastro de um app autenticador (descarta cadastros nao
  /// confirmados antes).
  Future<MfaEnrollment> mfaEnroll({required String issuer}) async {
    try {
      for (final f in _client.auth.currentUser?.factors ?? const <Factor>[]) {
        if (f.status != FactorStatus.verified) {
          await _client.auth.mfa.unenroll(f.id);
        }
      }
      final r = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: issuer,
        friendlyName: 'App autenticador',
      );
      final totp = r.totp;
      if (totp == null) throw AppError(key: 'MFA_ERROR');
      return MfaEnrollment(
        factorId: r.id,
        qrSvg: totp.qrCode,
        secret: totp.secret,
      );
    } on AuthException catch (e) {
      throw _fromAuth(e);
    }
  }

  /// Confirma o codigo de 6 digitos (a sessao passa a aal2).
  Future<void> mfaVerify({
    required String factorId,
    required String code,
  }) async {
    try {
      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    } on AuthException catch (e) {
      throw _fromAuth(e);
    }
  }

  /// Remove o app autenticador da conta (exige sessao aal2).
  Future<void> mfaUnenroll(String factorId) async {
    try {
      await _client.auth.mfa.unenroll(factorId);
      await _client.auth.refreshSession();
    } on AuthException catch (e) {
      throw _fromAuth(e);
    }
  }

  /// Chama `ad.<function>(p_json)` com `nr_version` injetado.
  /// Erros do banco chegam como `{"Message": "CHAVE", "Parameters": {...}}` e
  /// viram [AppError] com a chave traduzida em `Strings`.
  Future<Map<String, dynamic>> rpc(
    String function, [
    Map<String, dynamic> json = const {},
  ]) => rpcIn('ad', function, json);

  /// Chama `<schema>.<function>(p_json)` (`ad` = administrativo, `od` = negocio
  /// da clinica). Mesmo contrato de [rpc].
  Future<Map<String, dynamic>> rpcIn(
    String schema,
    String function, [
    Map<String, dynamic> json = const {},
  ]) async {
    try {
      final result = await _client
          .schema(schema)
          .rpc(
            function,
            params: {
              'p_json': {'nr_version': AppConfig.contractVersion, ...json},
            },
          );
      if (result is Map) return result.cast<String, dynamic>();
      return {'result': result};
    } on PostgrestException catch (e) {
      throw _fromPostgrest(e);
    } on AuthException catch (e) {
      throw _fromAuth(e);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.unexpected(e);
    }
  }

  /// Envia um arquivo para o Storage pela URL assinada que uma Edge Function
  /// gerou (o app nao tem policy de escrita no Storage).
  Future<void> uploadToSignedUrl({
    required String bucket,
    required String path,
    required String token,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .uploadBinaryToSignedUrl(
            path,
            token,
            bytes,
            FileOptions(contentType: contentType),
          );
    } on StorageException catch (e) {
      throw AppError.unexpected(e.message);
    }
  }

  /// Baixa o conteudo de uma URL assinada (download de anexo).
  Future<Uint8List> fetchBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw AppError.unexpected('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Chama uma Edge Function (`supabase/functions/<name>`) com o JWT da sessao.
  /// Erros 4xx chegam no mesmo formato do banco: `{"Message": "CHAVE", ...}`.
  Future<Map<String, dynamic>> invokeFunction(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(name, body: body);
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      return {'result': data};
    } on FunctionException catch (e) {
      throw _fromFunction(e);
    } on AuthException catch (e) {
      throw _fromAuth(e);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.unexpected(e);
    }
  }

  static AppError _fromFunction(FunctionException e) {
    final details = e.details;
    Map<String, dynamic>? payload;
    if (details is Map) {
      payload = details.cast<String, dynamic>();
    } else if (details is String) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) payload = decoded.cast<String, dynamic>();
      } catch (_) {
        // corpo nao e JSON
      }
    }
    if (payload != null && payload['Message'] is String) {
      final params = payload['Parameters'];
      return AppError(
        key: payload['Message'] as String,
        parameters: params is Map ? params.cast<String, dynamic>() : const {},
      );
    }
    return AppError(
      key: 'UNKNOWN',
      fallback: e.reasonPhrase ?? details?.toString() ?? 'HTTP ${e.status}',
    );
  }

  static AppError _fromPostgrest(PostgrestException e) {
    try {
      final decoded = jsonDecode(e.message);
      if (decoded is Map && decoded['Message'] is String) {
        final params = decoded['Parameters'];
        return AppError(
          key: decoded['Message'] as String,
          parameters: params is Map ? params.cast<String, dynamic>() : const {},
        );
      }
    } catch (_) {
      // mensagem nao e JSON: cai no fallback abaixo
    }
    return AppError(key: 'UNKNOWN', fallback: e.message);
  }

  static AppError _fromAuth(AuthException e) {
    return switch (e.code) {
      'invalid_credentials' => AppError(key: 'AUTH_INVALID_CREDENTIALS'),
      'email_not_confirmed' => AppError(key: 'AUTH_EMAIL_NOT_CONFIRMED'),
      'user_banned' => AppError(key: 'AUTH_USER_BANNED'),
      'over_request_rate_limit' => AppError(key: 'AUTH_RATE_LIMIT'),
      'mfa_verification_failed' ||
      'mfa_challenge_expired' => AppError(key: 'MFA_CODE_INVALID'),
      'insufficient_aal' => AppError(key: 'MFA_AAL_REQUIRED'),
      _ => AppError(key: 'AUTH_ERROR', fallback: e.message),
    };
  }
}

final supabaseGatewayProvider = Provider<SupabaseGateway>(
  (ref) => SupabaseGateway(Supabase.instance.client),
);
