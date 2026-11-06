import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/core/supabase/mfa_types.dart';
import 'package:odonto_app/features/session/domain/session_context.dart';

void main() {
  test('MfaStatus: conta com app autenticador sem o codigo na sessao', () {
    const s = MfaStatus(
      currentAal: 'aal1',
      nextAal: 'aal2',
      factors: [MfaFactor(id: 'f1', verified: true)],
    );
    expect(s.needsChallenge, isTrue);
    expect(s.hasVerifiedFactor, isTrue);
    expect(s.verifiedFactor?.id, 'f1');
    expect(s.isVerifiedSession, isFalse);
  });

  test('MfaStatus: sessao confirmada e conta sem fator', () {
    const ok = MfaStatus(currentAal: 'aal2', nextAal: 'aal2');
    expect(ok.needsChallenge, isFalse);
    expect(ok.isVerifiedSession, isTrue);
    const none = MfaStatus(factors: [MfaFactor(id: 'x', verified: false)]);
    expect(none.hasVerifiedFactor, isFalse);
    expect(none.verifiedFactor, isNull);
    expect(none.needsChallenge, isFalse);
  });

  test('SessionContext.requiresMfa pelo motivo do bloqueio', () {
    Map<String, dynamic> ctx(String key) => {
      'user': {'nr_user': 1, 'vc_name': 'Mel', 'vc_email': 'mel@x.com'},
      'companies': <dynamic>[],
      'blocked': [
        {'nr_company': 1, 'vc_name': 'Clínica', 'vc_reason_key': key},
      ],
    };
    expect(
      SessionContext.fromJson(ctx('SESSION_MFA_REQUIRED')).requiresMfa,
      isTrue,
    );
    expect(
      SessionContext.fromJson(ctx('SESSION_COMPANY_BLOCKED')).requiresMfa,
      isFalse,
    );
  });
}
