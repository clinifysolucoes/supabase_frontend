// Tipos do 2FA (app autenticador / TOTP do Supabase Auth), sem expor o
// pacote do Supabase fora do gateway.

/// Um fator cadastrado na conta.
class MfaFactor {
  const MfaFactor({required this.id, this.name, required this.verified});

  final String id;
  final String? name;
  final bool verified;
}

/// Situacao do 2FA na sessao atual.
class MfaStatus {
  const MfaStatus({
    this.currentAal = 'aal1',
    this.nextAal,
    this.factors = const [],
  });

  /// `aal1` (so senha) ou `aal2` (senha + app autenticador).
  final String currentAal;

  /// `aal2` quando a conta tem fator verificado (falta confirmar o codigo).
  final String? nextAal;
  final List<MfaFactor> factors;

  bool get isVerifiedSession => currentAal == 'aal2';
  bool get hasVerifiedFactor => factors.any((f) => f.verified);

  /// Conta com app autenticador, mas a sessao ainda nao confirmou o codigo.
  bool get needsChallenge => currentAal == 'aal1' && nextAal == 'aal2';

  MfaFactor? get verifiedFactor {
    for (final f in factors) {
      if (f.verified) return f;
    }
    return null;
  }
}

/// Cadastro de um app autenticador (antes de confirmar o primeiro codigo).
class MfaEnrollment {
  const MfaEnrollment({
    required this.factorId,
    required this.qrSvg,
    required this.secret,
  });

  final String factorId;

  /// QR code em SVG (texto) para o app autenticador ler.
  final String qrSvg;

  /// Chave para digitar no app, se nao der para ler o QR.
  final String secret;
}
