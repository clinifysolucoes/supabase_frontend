import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/settings_models.dart';
import '../application/patients_controllers.dart';
import '../domain/patient_models.dart';

enum _Kind { text, cpf, phone, date, email, zip }

/// Um campo de texto da ficha. A chave e a coluna do backend (od.patient):
/// o formulario le e grava com as mesmas chaves, sem traducao no meio.
class _Field {
  const _Field(
    this.key,
    this.label, {
    this.hint,
    this.kind = _Kind.text,
    this.maxLength,
    this.required = false,
    this.capitalization = TextCapitalization.none,
    this.icon,
    this.lines = 1,
  });

  final String key;
  final String label;
  final String? hint;
  final _Kind kind;
  final int? maxLength;
  final bool required;
  final TextCapitalization capitalization;
  final IconData? icon;
  final int lines;

  MaskType? get mask => switch (kind) {
    _Kind.cpf => MaskType.cpf,
    _Kind.phone => MaskType.phone,
    _Kind.date => MaskType.date,
    _Kind.zip => MaskType.cep,
    _ => null,
  };

  /// [extra]: obrigatorio pelas configuracoes da filial.
  FormFieldValidator<String> validator({bool extra = false}) =>
      Validators.compose([
        if (required || extra) Validators.required(),
        switch (kind) {
          _Kind.cpf => Validators.cpf(),
          _Kind.phone => Validators.phone(),
          _Kind.date => Validators.date(),
          _Kind.email => Validators.email(),
          _ => (_) => null,
        },
      ]);

  /// Texto do campo a partir do valor gravado (poe a mascara de volta).
  String display(String? value) {
    if (value == null) return '';
    final m = mask;
    return m == null || kind == _Kind.date ? value : Masks.format(m, value);
  }

  /// Valor do campo pronto para o backend (sem mascara; data em ISO).
  Object? collect(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return switch (kind) {
      _Kind.date => switch (Dates.parseField(t)) {
        null => null,
        final d => Dates.toIso(d),
      },
      _Kind.cpf || _Kind.phone || _Kind.zip => Masks.unmask(t),
      _ => t,
    };
  }
}

const _name = _Field(
  'vc_name',
  Strings.name,
  hint: Strings.fullName,
  maxLength: 120,
  required: true,
  capitalization: TextCapitalization.words,
  icon: Icons.person_outline_rounded,
);
const _nickname = _Field(
  'vc_nickname',
  Strings.nickname,
  hint: Strings.nicknameHint,
  maxLength: 60,
  capitalization: TextCapitalization.words,
);
const _cpf = _Field('vc_cpf', Strings.cpf, kind: _Kind.cpf, required: true);
const _rg = _Field('vc_rg', Strings.rg, hint: Strings.rgHint, maxLength: 20);
const _birth = _Field(
  'dt_birth',
  Strings.birthDate,
  hint: Strings.dateHint,
  kind: _Kind.date,
  required: true,
  icon: Icons.cake_outlined,
);
const _referral = _Field(
  'vc_referral',
  Strings.referredBy,
  hint: Strings.referredByHint,
  maxLength: 120,
  capitalization: TextCapitalization.words,
);
const _notes = _Field(
  'vc_notes',
  Strings.observations,
  hint: Strings.observationsHint,
  capitalization: TextCapitalization.sentences,
  lines: 3,
);
const _mobile = _Field(
  'vc_mobile',
  Strings.mobileWhatsapp,
  kind: _Kind.phone,
  icon: Icons.phone_android_rounded,
);
const _phone = _Field('vc_phone', Strings.landline, kind: _Kind.phone);
const _phoneOther = _Field(
  'vc_phone_other',
  Strings.otherPhone,
  kind: _Kind.phone,
);
const _contactName = _Field(
  'vc_contact_name',
  Strings.contactName,
  hint: Strings.contactNameHint,
  maxLength: 80,
  capitalization: TextCapitalization.words,
);
const _email = _Field(
  'vc_email',
  Strings.email,
  kind: _Kind.email,
  maxLength: 120,
  icon: Icons.alternate_email_rounded,
);
const _zip = _Field('vc_zip', Strings.zip, kind: _Kind.zip);
const _city = _Field(
  'vc_city',
  Strings.city,
  maxLength: 80,
  capitalization: TextCapitalization.words,
);
const _street = _Field(
  'vc_address',
  Strings.street,
  maxLength: 120,
  capitalization: TextCapitalization.words,
);
const _number = _Field(
  'vc_address_number',
  Strings.addressNumber,
  maxLength: 10,
);
const _district = _Field(
  'vc_district',
  Strings.district,
  maxLength: 80,
  capitalization: TextCapitalization.words,
);
const _complement = _Field(
  'vc_address_complement',
  Strings.addressComplement,
  maxLength: 60,
);
const _record = _Field('vc_record_number', Strings.recordNumber, maxLength: 20);
const _profession = _Field(
  'vc_profession',
  Strings.profession,
  maxLength: 80,
  capitalization: TextCapitalization.sentences,
);
const _workplace = _Field(
  'vc_workplace',
  Strings.workplace,
  maxLength: 80,
  capitalization: TextCapitalization.sentences,
);
const _workTime = _Field('vc_work_time', Strings.workTime, maxLength: 40);
const _planName = _Field(
  'vc_plan_name',
  Strings.planName,
  maxLength: 80,
  capitalization: TextCapitalization.words,
);
const _planNumber = _Field('vc_plan_number', Strings.planNumber, maxLength: 40);
const _fatherName = _Field(
  'vc_father_name',
  Strings.fatherName,
  maxLength: 120,
  capitalization: TextCapitalization.words,
);
const _fatherCpf = _Field('vc_father_cpf', Strings.fatherCpf, kind: _Kind.cpf);
const _fatherRg = _Field('vc_father_rg', Strings.fatherRg, maxLength: 20);
const _fatherProfession = _Field(
  'vc_father_profession',
  Strings.fatherProfession,
  maxLength: 80,
  capitalization: TextCapitalization.sentences,
);
const _motherName = _Field(
  'vc_mother_name',
  Strings.motherName,
  maxLength: 120,
  capitalization: TextCapitalization.words,
);
const _motherCpf = _Field('vc_mother_cpf', Strings.motherCpf, kind: _Kind.cpf);
const _motherRg = _Field('vc_mother_rg', Strings.motherRg, maxLength: 20);
const _motherProfession = _Field(
  'vc_mother_profession',
  Strings.motherProfession,
  maxLength: 80,
  capitalization: TextCapitalization.sentences,
);
const _guardianName = _Field(
  'vc_guardian_name',
  Strings.name,
  maxLength: 120,
  capitalization: TextCapitalization.words,
);
const _guardianCpf = _Field('vc_guardian_cpf', Strings.cpf, kind: _Kind.cpf);
const _guardianRg = _Field('vc_guardian_rg', Strings.rg, maxLength: 20);
const _guardianPhone = _Field(
  'vc_guardian_phone',
  Strings.phone,
  kind: _Kind.phone,
);

/// Aba Dados cadastrais / Contato / Dados complementares.
const _registration = [_name, _nickname, _birth, _cpf, _rg, _referral, _notes];
const _contact = [
  _phone,
  _mobile,
  _phoneOther,
  _contactName,
  _email,
  _zip,
  _city,
  _street,
  _number,
  _district,
  _complement,
];
const _complementary = [
  _record,
  _profession,
  _workplace,
  _workTime,
  _planName,
  _planNumber,
  _fatherName,
  _fatherCpf,
  _fatherRg,
  _fatherProfession,
  _motherName,
  _motherCpf,
  _motherRg,
  _motherProfession,
  _guardianName,
  _guardianCpf,
  _guardianRg,
  _guardianPhone,
];

/// Cadastro rapido (Novo paciente): o essencial para abrir a ficha.
const _quick = [
  _name,
  _nickname,
  _cpf,
  _rg,
  _mobile,
  _phone,
  _email,
  _birth,
  _referral,
  _notes,
];

/// Novo paciente (cadastro rapido, um formulario) ou edicao da ficha
/// (tres abas: Dados cadastrais, Contato, Dados complementares).
/// Devolve o nr_patient quando salvou; null quando cancelou.
class PatientFormDialog extends ConsumerStatefulWidget {
  const PatientFormDialog({
    super.key,
    this.patient,
    this.initialTab = 0,
    this.readOnly = false,
  });

  final Patient? patient;
  final int initialTab;
  final bool readOnly;

  static Future<int?> show(
    BuildContext context, {
    Patient? patient,
    int initialTab = 0,
    bool readOnly = false,
  }) => showDialog<int>(
    context: context,
    builder: (_) => PatientFormDialog(
      patient: patient,
      initialTab: initialTab,
      readOnly: readOnly,
    ),
  );

  @override
  ConsumerState<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends ConsumerState<PatientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final f in _allFields) f.key: TextEditingController(text: _initial(f)),
  };
  late int? _gender = _p?.itGender;
  late int? _marital = _p?.code('it_marital_status');
  late int? _education = _p?.code('it_education');
  late int? _source = _p?.itSource;
  late String? _state = _p?.text('vc_state');
  late bool _noEmail = _p?.idNoEmail ?? false;
  late int _tab = widget.initialTab.clamp(0, 2);
  bool _saving = false;

  Patient? get _p => widget.patient;
  bool get _isEdit => _p != null;
  bool get _canEdit => !widget.readOnly && !_saving;

  /// Colunas obrigatorias pelas configuracoes da filial.
  Set<String> get _requiredCols => PatientRequired.columnsOf(
    ref.read(settingsProvider).valueOrNull?.vcPatientRequired ?? const [],
  );

  bool _req(String key) => _requiredCols.contains(key);

  /// Campo de texto obrigatorio pela filial (e-mail: "nao possui" dispensa).
  bool _extra(_Field f) => _req(f.key) && !(f.key == 'vc_email' && _noEmail);

  List<_Field> get _allFields => [
    ..._registration,
    ..._contact,
    ..._complementary,
  ];
  List<_Field> get _visibleFields =>
      _isEdit ? _allFields : [..._quick, ..._quickExtra];

  /// Cadastro rapido: campos de texto obrigatorios da filial que nao estao
  /// no formulario curto (endereco, profissao, convenio).
  List<_Field> get _quickExtra => [
    for (final f in [..._contact, ..._complementary])
      if (_req(f.key) && !_quick.contains(f)) f,
  ];

  String _initial(_Field f) {
    final p = _p;
    if (p == null) return '';
    if (f.key == 'dt_birth') return Dates.toField(p.dtBirth);
    return f.display(p.text(f.key));
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    final m = <String, dynamic>{
      for (final f in _visibleFields) f.key: f.collect(_c[f.key]!.text),
      'it_gender': _gender,
      'it_source': _source,
      'id_no_email': _noEmail,
    };
    if (_isEdit || _req('it_marital_status')) {
      m['it_marital_status'] = _marital;
    }
    if (_isEdit || _req('it_education')) m['it_education'] = _education;
    if (_isEdit || _req('vc_state')) m['vc_state'] = _state;
    return m;
  }

  /// Aba do primeiro campo invalido (para mostrar o erro escondido).
  int? _tabWithError() {
    final groups = [_registration, _contact, _complementary];
    for (var i = 0; i < groups.length; i++) {
      for (final f in groups[i]) {
        if (f.validator(extra: _extra(f))(_c[f.key]!.text) != null) return i;
      }
    }
    return null;
  }

  /// Selecao obrigatoria pela filial que ficou vazia (rotulo) e a aba dela.
  (String, int)? _missingSelect() {
    final checks = [
      ('it_gender', _gender, Strings.gender, 0),
      ('it_marital_status', _marital, Strings.maritalStatus, 0),
      ('it_education', _education, Strings.education, 0),
      ('it_source', _source, Strings.howFound, 0),
      ('vc_state', _state, Strings.state, 1),
    ];
    for (final (key, value, label, tab) in checks) {
      if (_req(key) && value == null) return (label, tab);
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      final tab = _isEdit ? _tabWithError() : null;
      if (tab != null && tab != _tab) setState(() => _tab = tab);
      return;
    }
    final missing = _missingSelect();
    if (missing != null) {
      if (_isEdit && missing.$2 != _tab) setState(() => _tab = missing.$2);
      AppSnack.error(context, Strings.fieldRequiredNamed(missing.$1));
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = _collect();
      final int nr;
      if (_isEdit) {
        nr = _p!.nrPatient;
        await ref.read(patientRecordProvider(nr).notifier).save(fields);
      } else {
        final created = await ref
            .read(patientsProvider.notifier)
            .create(fields);
        if (created == null) return;
        nr = created;
      }
      if (mounted) Navigator.of(context).pop(nr);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  // --- campos ------------------------------------------------------------------

  Widget _text(_Field f, {bool autofocus = false}) => AppTextField(
    label: f.required || _extra(f) ? '${f.label} *' : f.label,
    hint: f.hint,
    controller: _c[f.key],
    mask: f.mask,
    maxLength: f.maxLength,
    maxLines: f.lines,
    minLines: f.lines > 1 ? f.lines : null,
    enabled: _canEdit && !(f.key == 'vc_email' && _noEmail),
    autofocus: autofocus,
    prefixIcon: f.icon,
    keyboardType: f.kind == _Kind.email ? TextInputType.emailAddress : null,
    textCapitalization: f.capitalization,
    validator: f.validator(extra: _extra(f)),
  );

  Widget _select({
    required String label,
    String? requiredKey,
    required List<int> values,
    required int? value,
    required String Function(int?) labelOf,
    required ValueChanged<int?> onChanged,
    IconData? icon,
  }) {
    final choices = [
      Choice<int>(value: null, label: Strings.notInformed),
      for (final v in values) Choice<int>(value: v, label: labelOf(v)),
    ];
    return SearchableDropdown<Choice<int>>(
      label: requiredKey != null && _req(requiredKey) ? '$label *' : label,
      prefixIcon: icon,
      items: choices,
      value: choices.firstWhere((c) => c.value == value),
      itemLabel: (c) => c.label,
      enabled: _canEdit,
      onChanged: (c) => setState(() => onChanged(c.value)),
    );
  }

  Widget _genderChips() => InputDecorator(
    decoration: InputDecoration(
      labelText: _req('it_gender') ? '${Strings.gender} *' : Strings.gender,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final g in Gender.all)
          ChoiceChip(
            label: Text(Gender.label(g)),
            selected: _gender == g,
            onSelected: _canEdit
                ? (v) => setState(() => _gender = v ? g : null)
                : null,
          ),
      ],
    ),
  );

  Widget _noEmailCheck() => CheckboxListTile(
    value: _noEmail,
    onChanged: _canEdit ? (v) => setState(() => _noEmail = v ?? false) : null,
    title: const Text(Strings.noEmail),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
  );

  Widget _stateSelect() {
    final choices = [
      const Choice<String>(value: null, label: Strings.notInformed),
      for (final uf in brazilStates) Choice<String>(value: uf, label: uf),
    ];
    return SearchableDropdown<Choice<String>>(
      label: _req('vc_state') ? '${Strings.state} *' : Strings.state,
      items: choices,
      value: choices.firstWhere((c) => c.value == _state),
      itemLabel: (c) => c.label,
      enabled: _canEdit,
      onChanged: (c) => setState(() => _state = c.value),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDark,
      ),
    ),
  );

  // --- layout --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // obrigatorios da filial (Configuracoes): redesenha quando carregam
    ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    const gap = SizedBox(height: AppSpacing.md);

    /// Dois campos lado a lado no desktop, empilhados no mobile.
    Widget pair(Widget a, Widget b, {int flexA = 1, int flexB = 1}) => isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, gap, b],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: flexA, child: a),
              const SizedBox(width: AppSpacing.sm),
              Expanded(flex: flexB, child: b),
            ],
          );

    final registration = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(_text(_name, autofocus: !_isEdit), _text(_nickname)),
        gap,
        pair(_text(_birth), _genderChips()),
        gap,
        pair(_text(_cpf), _text(_rg)),
        gap,
        pair(
          _select(
            label: Strings.maritalStatus,
            requiredKey: 'it_marital_status',
            values: MaritalStatus.all,
            value: _marital,
            labelOf: MaritalStatus.label,
            onChanged: (v) => _marital = v,
          ),
          _select(
            label: Strings.education,
            requiredKey: 'it_education',
            values: Education.all,
            value: _education,
            labelOf: Education.label,
            onChanged: (v) => _education = v,
          ),
        ),
        gap,
        pair(
          _select(
            label: Strings.howFound,
            requiredKey: 'it_source',
            values: PatientSource.all,
            value: _source,
            labelOf: PatientSource.label,
            onChanged: (v) => _source = v,
            icon: Icons.campaign_outlined,
          ),
          _text(_referral),
        ),
        gap,
        _text(_notes),
      ],
    );

    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(_text(_mobile), _text(_phone)),
        gap,
        pair(_text(_phoneOther), _text(_contactName)),
        gap,
        _text(_email),
        _noEmailCheck(),
        _sectionTitle(Strings.addressSection),
        pair(_text(_zip), _stateSelect()),
        gap,
        _text(_city),
        gap,
        pair(_text(_street), _text(_number), flexA: 3, flexB: 1),
        gap,
        pair(_text(_district), _text(_complement)),
      ],
    );

    final complementary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(_record),
        gap,
        pair(_text(_profession), _text(_workplace)),
        gap,
        pair(_text(_workTime), _text(_planName)),
        gap,
        _text(_planNumber),
        _sectionTitle(Strings.filiation),
        pair(_text(_fatherName), _text(_fatherCpf)),
        gap,
        pair(_text(_fatherRg), _text(_fatherProfession)),
        gap,
        pair(_text(_motherName), _text(_motherCpf)),
        gap,
        pair(_text(_motherRg), _text(_motherProfession)),
        _sectionTitle(Strings.legalGuardian),
        pair(_text(_guardianName), _text(_guardianCpf)),
        gap,
        pair(_text(_guardianRg), _text(_guardianPhone)),
      ],
    );

    final quick = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(_text(_name, autofocus: true), _text(_nickname)),
        gap,
        pair(_text(_cpf), _text(_rg)),
        gap,
        pair(_text(_mobile), _text(_phone)),
        gap,
        pair(_text(_email), _noEmailCheck()),
        gap,
        pair(_text(_birth), _genderChips()),
        gap,
        pair(
          _select(
            label: Strings.howFound,
            requiredKey: 'it_source',
            values: PatientSource.all,
            value: _source,
            labelOf: PatientSource.label,
            onChanged: (v) => _source = v,
            icon: Icons.campaign_outlined,
          ),
          _text(_referral),
        ),
        gap,
        _text(_notes),
        if (_quickExtra.isNotEmpty ||
            _req('it_marital_status') ||
            _req('it_education') ||
            _req('vc_state')) ...[
          _sectionTitle(Strings.requiredByClinic),
          if (_req('it_marital_status')) ...[
            _select(
              label: Strings.maritalStatus,
              requiredKey: 'it_marital_status',
              values: MaritalStatus.all,
              value: _marital,
              labelOf: MaritalStatus.label,
              onChanged: (v) => _marital = v,
            ),
            gap,
          ],
          if (_req('it_education')) ...[
            _select(
              label: Strings.education,
              requiredKey: 'it_education',
              values: Education.all,
              value: _education,
              labelOf: Education.label,
              onChanged: (v) => _education = v,
            ),
            gap,
          ],
          if (_req('vc_state')) ...[_stateSelect(), gap],
          for (final f in _quickExtra) ...[_text(f), gap],
        ],
      ],
    );

    final title = widget.readOnly
        ? Strings.patientInfo
        : (_isEdit ? Strings.editPatient : Strings.newPatient);

    final body = _isEdit
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TabStrip(
                tabs: isMobile
                    ? const [
                        Strings.sectionRegistration,
                        Strings.sectionContact,
                        Strings.sectionComplement,
                      ]
                    : const [
                        Strings.tabRegistration,
                        Strings.tabContact,
                        Strings.tabComplement,
                      ],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: AppSpacing.lg),
              IndexedStack(
                index: _tab,
                children: [registration, contact, complementary],
              ),
            ],
          )
        : quick;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      Strings.requiredFieldsHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                body,
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: widget.readOnly ? Strings.close : Strings.cancel,
                      variant: AppButtonVariant.text,
                      expanded: false,
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: _isEdit ? Strings.save : Strings.registerPatient,
                        icon: _isEdit
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                        expanded: false,
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa de abas no estilo da tela (fundo claro, aba ativa em branco).
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Material(
                color: i == index ? AppColors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: i == index
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.line),
                          )
                        : null,
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: i == index
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: i == index
                            ? AppColors.primaryDark
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
