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
    this.vcPatientRequired = const [],
    this.hours = const [],
    this.itDebtRule = DebtRule.none,
    this.qtDebtDays = 0,
    this.idCashEnabled = true,
    this.itPaymentMethods = allPaymentMethods,
    this.pcLateFee = 0,
    this.pcLateInterest = 0,
    this.canUpdate = false,
    this.canEditClinic = false,
  });

  factory BranchSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (j['permission'] as Map?)?.cast<String, dynamic>() ?? const {};
    int i(String k, int d) => (s[k] as num?)?.toInt() ?? d;
    double d(String k) => (s[k] as num?)?.toDouble() ?? 0;
    final methods = s['it_payment_methods'];
    return BranchSettings(
      clinic: ClinicData.fromJson(
        (j['clinic'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      qtSlotMinutes: i('qt_slot_minutes', 15),
      qtMaxParallel: i('qt_max_parallel', 1),
      idAllowOutsideHours: s['id_allow_outside_hours'] != false,
      idAutoRecordNumber: s['id_auto_record_number'] == true,
      nrNextRecord: i('nr_next_record', 1),
      vcPatientRequired: [
        for (final f in (s['vc_patient_required'] as List? ?? const [])) '$f',
      ],
      hours: [
        for (final h in (j['hours'] as List? ?? const []))
          ScheduleRange.fromJson((h as Map).cast<String, dynamic>()),
      ],
      itDebtRule: i('it_debt_rule', DebtRule.none),
      qtDebtDays: i('qt_debt_days', 0),
      idCashEnabled: s['id_cash_enabled'] != false,
      itPaymentMethods: methods is List
          ? [for (final m in methods) (m as num).toInt()]
          : allPaymentMethods,
      pcLateFee: d('pc_late_fee'),
      pcLateInterest: d('pc_late_interest'),
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

  /// Campos obrigatorios do paciente marcados pela filial (PatientRequired).
  final List<String> vcPatientRequired;
  final List<ScheduleRange> hours;
  final int itDebtRule;
  final int qtDebtDays;
  final bool idCashEnabled;
  final List<int> itPaymentMethods;
  final double pcLateFee;
  final double pcLateInterest;
  final bool canUpdate;
  final bool canEditClinic;

  static const slotOptions = [5, 15, 20, 30];

  /// Formas de pagamento (od.fin_entry.it_payment_method) aceitas por padrao.
  static const allPaymentMethods = [1, 2, 3, 4, 5, 6, 7, 9];
}

/// Campos do cadastro do paciente que a filial pode tornar obrigatorios
/// (od.branch_setting.vc_patient_required). Nome, nascimento e CPF sempre sao.
abstract final class PatientRequired {
  static const rg = 'rg';
  static const gender = 'gender';
  static const maritalStatus = 'marital_status';
  static const education = 'education';
  static const source = 'source';
  static const referral = 'referral';
  static const mobile = 'mobile';
  static const phone = 'phone';
  static const email = 'email';
  static const address = 'address';
  static const profession = 'profession';
  static const plan = 'plan';

  static const all = [
    rg,
    gender,
    maritalStatus,
    education,
    source,
    referral,
    mobile,
    phone,
    email,
    address,
    profession,
    plan,
  ];

  /// Colunas do paciente (od.patient) de cada opcao.
  static const columns = {
    rg: ['vc_rg'],
    gender: ['it_gender'],
    maritalStatus: ['it_marital_status'],
    education: ['it_education'],
    source: ['it_source'],
    referral: ['vc_referral'],
    mobile: ['vc_mobile'],
    phone: ['vc_phone'],
    email: ['vc_email'],
    address: [
      'vc_zip',
      'vc_address',
      'vc_address_number',
      'vc_district',
      'vc_city',
      'vc_state',
    ],
    profession: ['vc_profession'],
    plan: ['vc_plan_name'],
  };

  /// Colunas obrigatorias a partir das opcoes marcadas.
  static Set<String> columnsOf(Iterable<String> options) => {
    for (final o in options) ...?columns[o],
  };
}

/// Paciente com conta vencida ao agendar (od.branch_setting.it_debt_rule).
abstract final class DebtRule {
  static const none = 1;
  static const warn = 2;
  static const approval = 3;
  static const block = 4;
  static const all = [none, warn, approval, block];
}
