/// Alertas por WhatsApp (ad.whatsapp_settings_get / ad.whatsapp_message_list
/// e Edge Function whatsapp-config).
library;

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;

class WhatsappSettings {
  const WhatsappSettings({
    this.idEnabled = false,
    this.vcPhoneNumberId,
    this.vcWabaId,
    this.vcDisplayPhone,
    this.vcLanguage = 'pt_BR',
    this.idReminder = true,
    this.qtReminderHours = 24,
    this.vcTplReminder = 'lembrete_consulta',
    this.idBooked = false,
    this.vcTplBooked = 'consulta_agendada',
    this.idBirthday = false,
    this.vcTplBirthday = 'aniversario_paciente',
    this.idReturn = false,
    this.vcTplReturn = 'retorno_paciente',
    this.qtSendHour = 9,
    this.idToken = false,
    this.dhTokenSaved,
    this.totals = const {},
    this.canUpdate = false,
  });

  factory WhatsappSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final t = (j['totals'] as Map?) ?? const {};
    return WhatsappSettings(
      idEnabled: s['id_enabled'] as bool? ?? false,
      vcPhoneNumberId: s['vc_phone_number_id'] as String?,
      vcWabaId: s['vc_waba_id'] as String?,
      vcDisplayPhone: s['vc_display_phone'] as String?,
      vcLanguage: s['vc_language'] as String? ?? 'pt_BR',
      idReminder: s['id_reminder'] as bool? ?? true,
      qtReminderHours: _int(s['qt_reminder_hours'], 24),
      vcTplReminder: s['vc_tpl_reminder'] as String? ?? 'lembrete_consulta',
      idBooked: s['id_booked'] as bool? ?? false,
      vcTplBooked: s['vc_tpl_booked'] as String? ?? 'consulta_agendada',
      idBirthday: s['id_birthday'] as bool? ?? false,
      vcTplBirthday: s['vc_tpl_birthday'] as String? ?? 'aniversario_paciente',
      idReturn: s['id_return'] as bool? ?? false,
      vcTplReturn: s['vc_tpl_return'] as String? ?? 'retorno_paciente',
      qtSendHour: _int(s['qt_send_hour'], 9),
      idToken: s['id_token'] as bool? ?? false,
      dhTokenSaved: DateTime.tryParse(
        s['dh_token_saved'] as String? ?? '',
      )?.toLocal(),
      totals: {
        for (final e in t.entries) int.parse(e.key.toString()): _int(e.value),
      },
      canUpdate: (j['permission'] as Map?)?['id_update'] as bool? ?? false,
    );
  }

  final bool idEnabled;
  final String? vcPhoneNumberId;
  final String? vcWabaId;
  final String? vcDisplayPhone;
  final String vcLanguage;
  final bool idReminder;
  final int qtReminderHours;
  final String vcTplReminder;
  final bool idBooked;
  final String vcTplBooked;
  final bool idBirthday;
  final String vcTplBirthday;
  final bool idReturn;
  final String vcTplReturn;
  final int qtSendHour;
  final bool idToken;
  final DateTime? dhTokenSaved;

  /// Mensagens dos ultimos 30 dias por situacao.
  final Map<int, int> totals;
  final bool canUpdate;
}

/// Situacao da mensagem.
abstract final class WaStatus {
  static const queued = 1;
  static const sent = 2;
  static const delivered = 3;
  static const read = 4;
  static const sending = 5;
  static const error = 9;
  static const cancelled = 90;

  static const all = [queued, sending, sent, delivered, read, error, cancelled];

  static String label(int s) => switch (s) {
    queued => 'Na fila',
    sending => 'Enviando',
    sent => 'Enviada',
    delivered => 'Entregue',
    read => 'Lida',
    error => 'Erro',
    cancelled => 'Cancelada',
    _ => '$s',
  };
}

/// Tipo de alerta.
abstract final class WaKind {
  static String label(int k) => switch (k) {
    1 => 'Lembrete',
    2 => 'Agendamento',
    3 => 'Aniversário',
    4 => 'Retorno',
    9 => 'Teste',
    _ => '$k',
  };
}

class WhatsappMessage {
  const WhatsappMessage({
    required this.nrMessage,
    required this.itKind,
    required this.vcPatient,
    this.dhAppointment,
    required this.vcTo,
    required this.itStatus,
    this.vcError,
    this.vcReply,
    this.dhCreated,
  });

  factory WhatsappMessage.fromJson(Map<String, dynamic> j) => WhatsappMessage(
    nrMessage: _int(j['nr_message']),
    itKind: _int(j['it_kind'], 1),
    vcPatient: j['vc_patient'] as String? ?? '',
    dhAppointment: DateTime.tryParse(
      j['dh_appointment'] as String? ?? '',
    )?.toLocal(),
    vcTo: j['vc_to'] as String? ?? '',
    itStatus: _int(j['it_status'], 1),
    vcError: j['vc_error'] as String?,
    vcReply: j['vc_reply'] as String?,
    dhCreated: DateTime.tryParse(j['dh_created'] as String? ?? '')?.toLocal(),
  );

  final int nrMessage;
  final int itKind;
  final String vcPatient;
  final DateTime? dhAppointment;
  final String vcTo;
  final int itStatus;
  final String? vcError;

  /// CONFIRM | RESCHEDULE
  final String? vcReply;
  final DateTime? dhCreated;

  String? get replyLabel => switch (vcReply) {
    'CONFIRM' => 'Confirmou',
    'RESCHEDULE' => 'Pediu para remarcar',
    _ => null,
  };
}

class WhatsappMessagePage {
  const WhatsappMessagePage({this.messages = const [], this.qtTotal = 0});

  factory WhatsappMessagePage.fromJson(Map<String, dynamic> j) =>
      WhatsappMessagePage(
        messages: ((j['messages'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(WhatsappMessage.fromJson)
            .toList(),
        qtTotal: _int(j['qt_total']),
      );

  final List<WhatsappMessage> messages;
  final int qtTotal;
}
