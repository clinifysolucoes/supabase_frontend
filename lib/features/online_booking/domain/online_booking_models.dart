/// Agendamento online: configuracao (ad.online_booking_settings_get) e a
/// pagina publica (Edge Function online-booking).
library;

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;

class OnlineProfessional {
  const OnlineProfessional({
    required this.nrProfessional,
    required this.vcName,
    this.vcCouncil,
    this.qtSlotMinutes = 30,
    this.idOnline = false,
  });

  factory OnlineProfessional.fromJson(Map<String, dynamic> j) =>
      OnlineProfessional(
        nrProfessional: _int(j['nr_professional']),
        vcName: j['vc_name'] as String? ?? '',
        vcCouncil: j['vc_council'] as String?,
        qtSlotMinutes: _int(j['qt_slot_minutes'], 30),
        idOnline: j['id_online'] as bool? ?? false,
      );

  final int nrProfessional;
  final String vcName;
  final String? vcCouncil;
  final int qtSlotMinutes;
  final bool idOnline;
}

class OnlineBookingSettings {
  const OnlineBookingSettings({
    this.idEnabled = false,
    this.vcSlug = '',
    this.qtDaysAhead = 30,
    this.qtMinHours = 2,
    this.vcMessage,
    this.idSaved = false,
    this.professionals = const [],
    this.canUpdate = false,
  });

  factory OnlineBookingSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OnlineBookingSettings(
      idEnabled: s['id_enabled'] as bool? ?? false,
      vcSlug: s['vc_slug'] as String? ?? '',
      qtDaysAhead: _int(s['qt_days_ahead'], 30),
      qtMinHours: _int(s['qt_min_hours'], 2),
      vcMessage: s['vc_message'] as String?,
      idSaved: s['id_saved'] as bool? ?? false,
      professionals: ((j['professionals'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OnlineProfessional.fromJson)
          .toList(),
      canUpdate: (j['permission'] as Map?)?['id_update'] as bool? ?? false,
    );
  }

  final bool idEnabled;
  final String vcSlug;
  final int qtDaysAhead;
  final int qtMinHours;
  final String? vcMessage;
  final bool idSaved;
  final List<OnlineProfessional> professionals;
  final bool canUpdate;

  /// Endereco publico da pagina (mesmo dominio do app).
  static String publicUrl(String origin, String slug) =>
      '$origin/agendar/$slug';
}

/// Dados publicos da clinica (acao "info").
class OnlineClinic {
  const OnlineClinic({
    required this.vcName,
    this.vcAddress,
    this.vcPhone,
    this.vcCity,
    this.vcState,
    this.vcMessage,
    required this.dtToday,
    required this.dtLast,
    this.professionals = const [],
  });

  factory OnlineClinic.fromJson(Map<String, dynamic> j) {
    final c = (j['clinic'] as Map?)?.cast<String, dynamic>() ?? const {};
    final today =
        DateTime.tryParse(j['dt_today'] as String? ?? '') ?? DateTime.now();
    return OnlineClinic(
      vcName: c['vc_name'] as String? ?? '',
      vcAddress: c['vc_address'] as String?,
      vcPhone: c['vc_phone'] as String?,
      vcCity: c['vc_city'] as String?,
      vcState: c['vc_state'] as String?,
      vcMessage: j['vc_message'] as String?,
      dtToday: today,
      dtLast:
          DateTime.tryParse(j['dt_last'] as String? ?? '') ??
          today.add(const Duration(days: 30)),
      professionals: ((j['professionals'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(OnlineProfessional.fromJson)
          .toList(),
    );
  }

  final String vcName;
  final String? vcAddress;
  final String? vcPhone;
  final String? vcCity;
  final String? vcState;
  final String? vcMessage;
  final DateTime dtToday;
  final DateTime dtLast;
  final List<OnlineProfessional> professionals;

  /// Dias que a pagina oferece (hoje ate a janela).
  List<DateTime> get days => [
    for (
      var d = DateTime(dtToday.year, dtToday.month, dtToday.day);
      !d.isAfter(dtLast);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// Consulta marcada (acao "book").
class OnlineBookingResult {
  const OnlineBookingResult({
    required this.dhStart,
    required this.vcProfessional,
    required this.vcClinic,
  });

  factory OnlineBookingResult.fromJson(Map<String, dynamic> j) =>
      OnlineBookingResult(
        dhStart: j['dh_start'] as String? ?? '',
        vcProfessional: j['vc_professional'] as String? ?? '',
        vcClinic: j['vc_clinic'] as String? ?? '',
      );

  /// 'YYYY-MM-DD HH:MI' no fuso da clinica.
  final String dhStart;
  final String vcProfessional;
  final String vcClinic;
}
