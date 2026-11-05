import '../../agenda/domain/agenda_models.dart';

/// Dados da clinica (ad.branch) mostrados nas Configuracoes.
class ClinicData {
  const ClinicData({
    this.vcName = '',
    this.vcLegalName,
    this.vcCnpj,
    this.vcEmail,
    this.vcPhone,
    this.vcPhoneExtra,
    this.vcZipCode,
    this.vcAddress,
    this.vcAddressNumber,
    this.vcAddressExtra,
    this.vcDistrict,
    this.vcCity,
    this.vcState,
    this.vcTechnicalName,
    this.vcTechnicalCro,
    this.vcTechnicalCroState,
    this.vcForumCity,
  });

  factory ClinicData.fromJson(Map<String, dynamic> j) => ClinicData(
    vcName: j['vc_name']?.toString() ?? '',
    vcLegalName: j['vc_legal_name']?.toString(),
    vcCnpj: j['vc_cnpj']?.toString(),
    vcEmail: j['vc_email']?.toString(),
    vcPhone: j['vc_phone']?.toString(),
    vcPhoneExtra: j['vc_phone_extra']?.toString(),
    vcZipCode: j['vc_zip_code']?.toString(),
    vcAddress: j['vc_address']?.toString(),
    vcAddressNumber: j['vc_address_number']?.toString(),
    vcAddressExtra: j['vc_address_extra']?.toString(),
    vcDistrict: j['vc_district']?.toString(),
    vcCity: j['vc_city']?.toString(),
    vcState: j['vc_state']?.toString(),
    vcTechnicalName: j['vc_technical_name']?.toString(),
    vcTechnicalCro: j['vc_technical_cro']?.toString(),
    vcTechnicalCroState: j['vc_technical_cro_state']?.toString(),
    vcForumCity: j['vc_forum_city']?.toString(),
  );

  final String vcName;
  final String? vcLegalName;
  final String? vcCnpj;
  final String? vcEmail;
  final String? vcPhone;
  final String? vcPhoneExtra;
  final String? vcZipCode;
  final String? vcAddress;
  final String? vcAddressNumber;
  final String? vcAddressExtra;
  final String? vcDistrict;
  final String? vcCity;
  final String? vcState;
  final String? vcTechnicalName;
  final String? vcTechnicalCro;
  final String? vcTechnicalCroState;
  final String? vcForumCity;
}

/// Configuracoes da filial (ad.settings_get).
class BranchSettings {
  const BranchSettings({
    this.clinic = const ClinicData(),
    this.qtSlotMinutes = 15,
    this.qtMaxParallel = 1,
    this.idAllowOutsideHours = true,
    this.idAutoRecordNumber = false,
    this.nrNextRecord = 1,
    this.idRequireCpf = false,
    this.idRequireMobile = false,
    this.hours = const [],
    this.canUpdate = false,
    this.canEditClinic = false,
  });

  factory BranchSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (j['permission'] as Map?)?.cast<String, dynamic>() ?? const {};
    int i(String k, int d) => (s[k] as num?)?.toInt() ?? d;
    return BranchSettings(
      clinic: ClinicData.fromJson(
        (j['clinic'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      qtSlotMinutes: i('qt_slot_minutes', 15),
      qtMaxParallel: i('qt_max_parallel', 1),
      idAllowOutsideHours: s['id_allow_outside_hours'] != false,
      idAutoRecordNumber: s['id_auto_record_number'] == true,
      nrNextRecord: i('nr_next_record', 1),
      idRequireCpf: s['id_require_cpf'] == true,
      idRequireMobile: s['id_require_mobile'] == true,
      hours: [
        for (final h in (j['hours'] as List? ?? const []))
          ScheduleRange.fromJson((h as Map).cast<String, dynamic>()),
      ],
      canUpdate: p['id_update'] == true,
      canEditClinic: p['id_clinic'] == true,
    );
  }

  final ClinicData clinic;
  final int qtSlotMinutes;
  final int qtMaxParallel;
  final bool idAllowOutsideHours;
  final bool idAutoRecordNumber;
  final int nrNextRecord;
  final bool idRequireCpf;
  final bool idRequireMobile;
  final List<ScheduleRange> hours;
  final bool canUpdate;
  final bool canEditClinic;

  static const slotOptions = [5, 15, 20, 30];
}
