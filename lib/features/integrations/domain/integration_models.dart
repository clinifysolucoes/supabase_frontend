/// Situacao das integracoes externas (Edge Function integrations-status).
library;

/// Codigos devolvidos pela Edge Function.
abstract final class IntegrationCode {
  static const email = 'email';
  static const sms = 'sms';
  static const whatsapp = 'whatsapp';
  static const credit = 'credit';
  static const invoice = 'invoice';
  static const priceLookup = 'price_lookup';
}

/// Situacao de uma integracao.
enum IntegrationState {
  /// Chaves cadastradas e integracao concluida.
  ready,

  /// Faltam chaves (contratar o servico / cadastrar as secrets).
  pending,

  /// Chaves cadastradas, mas a integracao com o provedor ainda nao foi escrita.
  preparing,

  /// Nao foi possivel verificar (Edge Function fora do ar ou nao publicada).
  unknown,
}

class IntegrationStatus {
  const IntegrationStatus({
    this.configured = false,
    this.implemented = false,
    this.missing = const [],
    this.checked = true,
  });

  factory IntegrationStatus.fromJson(Map<String, dynamic> j) =>
      IntegrationStatus(
        configured: j['configured'] == true,
        implemented: j['implemented'] == true,
        missing: [for (final m in (j['missing'] as List? ?? const [])) '$m'],
      );

  /// Situacao desconhecida (nao deu para consultar).
  static const unknown = IntegrationStatus(checked: false);

  final bool configured;
  final bool implemented;

  /// Nomes das secrets que faltam (nunca os valores).
  final List<String> missing;
  final bool checked;

  IntegrationState get state {
    if (!checked) return IntegrationState.unknown;
    if (!configured) return IntegrationState.pending;
    if (!implemented) return IntegrationState.preparing;
    return IntegrationState.ready;
  }

  bool get isReady => state == IntegrationState.ready;
}

class IntegrationStatusMap {
  const IntegrationStatusMap(this.items, {this.checked = true});

  factory IntegrationStatusMap.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as Map?)?.cast<String, dynamic>() ?? const {};
    return IntegrationStatusMap({
      for (final e in items.entries)
        e.key: IntegrationStatus.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    });
  }

  /// Nao deu para consultar: tudo fica "nao verificado".
  static const failed = IntegrationStatusMap({}, checked: false);

  final Map<String, IntegrationStatus> items;
  final bool checked;

  IntegrationStatus of(String code) => checked
      ? (items[code] ?? const IntegrationStatus())
      : IntegrationStatus.unknown;
}
