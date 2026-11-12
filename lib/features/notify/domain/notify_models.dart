/// Alertas por e-mail (Resend) e SMS (Zenvia): configuracao da filial,
/// historico e a confirmacao pelo link do lembrete.
library;

import '../../../l10n/strings.dart';

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
DateTime? _dt(Object? v) => DateTime.tryParse(v as String? ?? '')?.toLocal();

abstract final class NotifyChannel {
  static const email = 1;
  static const sms = 2;

  static String label(int c) => c == email ? Strings.ntEmail : Strings.ntSms;
}

abstract final class NotifyKind {
  static const reminder = 1;
  static const booked = 2;
  static const returnAlert = 4;

  static String label(int k) => switch (k) {
    reminder => Strings.waReminder,
    booked => Strings.waBooked,
    returnAlert => Strings.waReturn,
    _ => '-',
  };
}

abstract final class NotifyStatus {
  static const queued = 1;
  static const sent = 2;
  static const sending = 5;
  static const error = 9;
  static const cancelled = 90;

  static const all = [queued, sending, sent, error, cancelled];

  static String label(int s) => switch (s) {
    queued => Strings.ntQueued,
    sending => Strings.ntSending,
    sent => Strings.ntSent,
    error => Strings.ntError,
    cancelled => Strings.ntCancelled,
    _ => '-',
  };
}

/// Campos que os textos aceitam.
const notifyFields = [
  '{{nome}}',
  '{{clinica}}',
  '{{data}}',
  '{{hora}}',
  '{{profissional}}',
  '{{retorno}}',
  '{{link}}',
];

class NotifySettings {
  const NotifySettings({
    this.idEmail = false,
    this.idSms = false,
    this.vcEmailFromName,
    this.vcEmailReplyTo,
    this.idReminder = true,
    this.qtReminderHours = 24,
    this.idBooked = true,
    this.idReturn = false,
    this.qtSendHour = 9,
    this.vcTplReminder = '',
    this.vcTplBooked = '',
    this.vcTplReturn = '',
    this.vcClinic,
    this.totals = const {},
    this.canUpdate = false,
  });

  factory NotifySettings.fromJson(Map<String, dynamic> j) {
    final s = ((j['settings'] as Map?) ?? const {}).cast<String, dynamic>();
    final t = <(int, int), int>{};
    for (final x in (j['totals'] as List?) ?? const []) {
      final m = (x as Map).cast<String, dynamic>();
      t[(_int(m['it_channel']), _int(m['it_status']))] = _int(m['qt']);
    }
    return NotifySettings(
      idEmail: s['id_email'] as bool? ?? false,
      idSms: s['id_sms'] as bool? ?? false,
      vcEmailFromName: s['vc_email_from_name'] as String?,
      vcEmailReplyTo: s['vc_email_reply_to'] as String?,
      idReminder: s['id_reminder'] as bool? ?? true,
      qtReminderHours: _int(s['qt_reminder_hours'], 24),
      idBooked: s['id_booked'] as bool? ?? true,
      idReturn: s['id_return'] as bool? ?? false,
      qtSendHour: _int(s['qt_send_hour'], 9),
      vcTplReminder: s['vc_tpl_reminder'] as String? ?? '',
      vcTplBooked: s['vc_tpl_booked'] as String? ?? '',
      vcTplReturn: s['vc_tpl_return'] as String? ?? '',
      vcClinic: s['vc_clinic'] as String?,
      totals: t,
      canUpdate:
          ((j['permission'] as Map?) ?? const {})['id_update'] as bool? ??
          false,
    );
  }

  final bool idEmail;
  final bool idSms;
  final String? vcEmailFromName;
  final String? vcEmailReplyTo;
  final bool idReminder;
  final int qtReminderHours;
  final bool idBooked;
  final bool idReturn;
  final int qtSendHour;
  final String vcTplReminder;
  final String vcTplBooked;
  final String vcTplReturn;
  final String? vcClinic;

  /// (canal, situacao) -> quantidade nos ultimos 30 dias.
  final Map<(int, int), int> totals;
  final bool canUpdate;
}

/// Previa do texto com dados de exemplo (o envio usa os dados reais).
String notifyPreview(String tpl, {String? clinic}) {
  final sample = {
    '{{nome}}': 'Maria',
    '{{clinica}}': (clinic ?? '').isEmpty ? 'Clínica' : clinic!,
    '{{data}}': '15/03',
    '{{hora}}': '14:30',
    '{{profissional}}': 'Dra. Ana',
    '{{retorno}}': 'Limpeza semestral.',
    '{{link}}': 'https://…/confirmar/…',
  };
  var t = tpl;
  sample.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'\{\{[a-z_]+\}\}'), '').trim();
}

class NotifyMessage {
  const NotifyMessage({
    required this.nrMessage,
    required this.itChannel,
    required this.itKind,
    required this.vcPatient,
    required this.vcTo,
    required this.itStatus,
    this.dhAppointment,
    this.vcError,
    this.dhSent,
    this.dhConfirmed,
    this.dhCreated,
  });

  factory NotifyMessage.fromJson(Map<String, dynamic> j) => NotifyMessage(
    nrMessage: _int(j['nr_message']),
    itChannel: _int(j['it_channel'], 1),
    itKind: _int(j['it_kind'], 1),
    vcPatient: j['vc_patient'] as String? ?? '',
    vcTo: j['vc_to'] as String? ?? '',
    itStatus: _int(j['it_status'], 1),
    dhAppointment: _dt(j['dh_appointment']),
    vcError: j['vc_error'] as String?,
    dhSent: _dt(j['dh_sent']),
    dhConfirmed: _dt(j['dh_confirmed']),
    dhCreated: _dt(j['dh_created']),
  );

  final int nrMessage;
  final int itChannel;
  final int itKind;
  final String vcPatient;
  final String vcTo;
  final int itStatus;
  final DateTime? dhAppointment;
  final String? vcError;
  final DateTime? dhSent;
  final DateTime? dhConfirmed;
  final DateTime? dhCreated;
}

class NotifyMessagePage {
  const NotifyMessagePage({this.messages = const [], this.qtTotal = 0});

  factory NotifyMessagePage.fromJson(Map<String, dynamic> j) =>
      NotifyMessagePage(
        messages: [
          for (final m in (j['messages'] as List?) ?? const [])
            NotifyMessage.fromJson((m as Map).cast<String, dynamic>()),
        ],
        qtTotal: _int(j['qt_total']),
      );

  final List<NotifyMessage> messages;
  final int qtTotal;
}

/// Resposta da confirmacao pelo link (Edge Function notify-confirm).
class NotifyConfirmResult {
  const NotifyConfirmResult({
    required this.itResult,
    this.vcClinic,
    this.vcPatient,
    this.vcDate,
    this.vcTime,
    this.vcProfessional,
  });

  factory NotifyConfirmResult.fromJson(Map<String, dynamic> j) =>
      NotifyConfirmResult(
        itResult: _int(j['it_result']),
        vcClinic: j['vc_clinic'] as String?,
        vcPatient: j['vc_patient'] as String?,
        vcDate: j['vc_date'] as String?,
        vcTime: j['vc_time'] as String?,
        vcProfessional: j['vc_professional'] as String?,
      );

  /// 1 confirmada agora | 2 ja estava | 3 nao da mais | 0 link invalido
  final int itResult;
  final String? vcClinic;
  final String? vcPatient;
  final String? vcDate;
  final String? vcTime;
  final String? vcProfessional;

  bool get isConfirmed => itResult == 1 || itResult == 2;
}
