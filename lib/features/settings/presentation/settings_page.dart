import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clinical_record/presentation/anamnesis_models_section.dart';
import '../../documents/presentation/document_settings_sections.dart';
import '../../online_booking/presentation/online_booking_section.dart';
import '../../whatsapp/presentation/whatsapp_section.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/domain/agenda_models.dart';
import '../../agenda/presentation/week_schedule_editor.dart';
import '../../finance/domain/finance_models.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../../profiles/application/profiles_controller.dart';
import '../application/settings_controller.dart';
import '../data/data_export.dart';
import '../domain/settings_models.dart';
import '../domain/trash_models.dart';
import 'security_section.dart';

enum _Section {
  clinic,
  agenda,
  patients,
  record,
  online,
  whatsapp,
  finance,
  security,
  export,
  trash,
}

/// Configuracoes da filial: dados da clinica, agenda (intervalo, consultas no
/// mesmo horario, fora do expediente, horario de funcionamento) e cadastro de
/// pacientes (prontuario automatico, obrigatorios) e financeiro (inadimplentes,
/// caixa, formas aceitas, multa e juros).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _Section _section = _Section.clinic;

  String _label(_Section s) => switch (s) {
    _Section.clinic => Strings.settingsClinic,
    _Section.agenda => Strings.settingsAgenda,
    _Section.patients => Strings.settingsPatients,
    _Section.record => Strings.settingsRecord,
    _Section.online => Strings.settingsOnline,
    _Section.whatsapp => Strings.settingsWhatsapp,
    _Section.finance => Strings.settingsFinance,
    _Section.security => Strings.settingsSecurity,
    _Section.export => Strings.settingsExport,
    _Section.trash => Strings.settingsTrash,
  };

  IconData _icon(_Section s) => switch (s) {
    _Section.clinic => Icons.storefront_outlined,
    _Section.agenda => Icons.calendar_month_outlined,
    _Section.patients => Icons.badge_outlined,
    _Section.record => Icons.assignment_outlined,
    _Section.online => Icons.public_rounded,
    _Section.whatsapp => Icons.chat_outlined,
    _Section.finance => Icons.account_balance_wallet_outlined,
    _Section.security => Icons.shield_outlined,
    _Section.export => Icons.file_download_outlined,
    _Section.trash => Icons.restore_from_trash_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canReadProvider(ScreenCodes.settings))) {
      return const AppShell(
        section: AppSection.settings,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final async = ref.watch(settingsProvider);
    final mobile = context.isMobile;
    final nav = [
      for (final s in _Section.values)
        mobile
            ? Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  avatar: Icon(_icon(s), size: 18),
                  label: Text(_label(s)),
                  selected: _section == s,
                  onSelected: (_) => setState(() => _section = s),
                ),
              )
            : ListTile(
                leading: Icon(_icon(s)),
                title: Text(_label(s)),
                selected: _section == s,
                selectedTileColor: AppColors.mint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                onTap: () => setState(() => _section = s),
              ),
    ];
    return AppShell(
      section: AppSection.settings,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(
              title: Strings.settingsTitle,
              subtitle: Strings.settingsSubtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppEmptyState.error(
                  message: describeError(e),
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
                data: (s) {
                  final body = SingleChildScrollView(
                    child: switch (_section) {
                      _Section.clinic => _ClinicForm(
                        key: ValueKey(s.clinic),
                        settings: s,
                      ),
                      _Section.agenda => _AgendaForm(
                        key: ValueKey(s.hashCode),
                        settings: s,
                      ),
                      _Section.patients => _PatientsForm(
                        key: ValueKey(s.hashCode),
                        settings: s,
                      ),
                      _Section.record => const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnamnesisModelsSection(),
                          SizedBox(height: AppSpacing.md),
                          DocumentTemplatesSection(),
                          SizedBox(height: AppSpacing.md),
                          MedicationsSection(),
                        ],
                      ),
                      _Section.online => const OnlineBookingSection(),
                      _Section.whatsapp => const WhatsappSection(),
                      _Section.finance => _FinanceForm(
                        key: ValueKey(s.hashCode),
                        settings: s,
                      ),
                      _Section.security => SecuritySection(
                        key: ValueKey(s.itMfaPolicy),
                        settings: s,
                      ),
                      _Section.export => _ExportForm(settings: s),
                      _Section.trash => const _TrashList(),
                    },
                  );
                  return mobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: nav),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(child: body),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 230,
                              child: Card(
                                // com muitas secoes o menu passa da altura: rola
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: Column(children: nav),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: body),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moldura de cada secao: titulo, dica, conteudo e o Salvar.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.hint,
    required this.children,
    this.onSave,
    this.saving = false,
  });

  final String title;
  final String hint;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(hint, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: AppSpacing.lg),
            ...children,
            if (onSave != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: Strings.save,
                  expanded: false,
                  loading: saving,
                  onPressed: onSave,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _subtitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
  child: Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
  ),
);

/// Campos lado a lado (empilhados no celular).
Widget _row(BuildContext context, List<Widget> children) => context.isMobile
    ? Column(
        children: [
          for (final c in children) ...[
            c,
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      )
    : Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );

class _ClinicForm extends ConsumerStatefulWidget {
  const _ClinicForm({super.key, required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<_ClinicForm> createState() => _ClinicFormState();
}

class _ClinicFormState extends ConsumerState<_ClinicForm> {
  final _formKey = GlobalKey<FormState>();
  late final ClinicData _c = widget.settings.clinic;
  late final _name = TextEditingController(text: _c.vcName);
  late final _legal = TextEditingController(text: _c.vcLegalName);
  late final _cnpj = TextEditingController(
    text: _c.vcCnpj == null ? '' : Masks.format(MaskType.cnpj, _c.vcCnpj!),
  );
  late final _email = TextEditingController(text: _c.vcEmail);
  late final _phone = TextEditingController(
    text: _c.vcPhone == null ? '' : Masks.format(MaskType.phone, _c.vcPhone!),
  );
  late final _phone2 = TextEditingController(
    text: _c.vcPhoneExtra == null
        ? ''
        : Masks.format(MaskType.phone, _c.vcPhoneExtra!),
  );
  late final _zip = TextEditingController(
    text: _c.vcZipCode == null ? '' : Masks.format(MaskType.cep, _c.vcZipCode!),
  );
  late final _address = TextEditingController(text: _c.vcAddress);
  late final _number = TextEditingController(text: _c.vcAddressNumber);
  late final _extra = TextEditingController(text: _c.vcAddressExtra);
  late final _district = TextEditingController(text: _c.vcDistrict);
  late final _city = TextEditingController(text: _c.vcCity);
  late final _state = TextEditingController(text: _c.vcState);
  late final _techName = TextEditingController(text: _c.vcTechnicalName);
  late final _techCro = TextEditingController(text: _c.vcTechnicalCro);
  late final _techState = TextEditingController(text: _c.vcTechnicalCroState);
  late final _forum = TextEditingController(text: _c.vcForumCity);
  late bool _sameForum = _c.vcForumCity == null;
  bool _saving = false;

  List<TextEditingController> get _all => [
    _name,
    _legal,
    _cnpj,
    _email,
    _phone,
    _phone2,
    _zip,
    _address,
    _number,
    _extra,
    _district,
    _city,
    _state,
    _techName,
    _techCro,
    _techState,
    _forum,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).saveClinic({
        'vc_name': _name.text.trim(),
        'vc_legal_name': _v(_legal),
        'vc_cnpj': _v(_cnpj),
        'vc_email': _v(_email),
        'vc_phone': _v(_phone) == null ? null : Masks.unmask(_phone.text),
        'vc_phone_extra': _v(_phone2),
        'vc_zip_code': _v(_zip),
        'vc_address': _v(_address),
        'vc_address_number': _v(_number),
        'vc_address_extra': _v(_extra),
        'vc_district': _v(_district),
        'vc_city': _v(_city),
        'vc_state': _v(_state),
        'vc_technical_name': _v(_techName),
        'vc_technical_cro': _v(_techCro),
        'vc_technical_cro_state': _v(_techState),
        'vc_forum_city': _sameForum ? null : _v(_forum),
      });
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.settings.canEditClinic && !_saving;
    AppTextField field(
      String label,
      TextEditingController c, {
      MaskType? mask,
      int? maxLength,
      TextInputType? keyboard,
      String? Function(String?)? validator,
    }) => AppTextField(
      label: label,
      controller: c,
      mask: mask,
      maxLength: maxLength,
      keyboardType: keyboard,
      enabled: enabled,
      validator: validator,
    );
    return Form(
      key: _formKey,
      child: _SectionCard(
        title: Strings.settingsClinic,
        hint: widget.settings.canEditClinic
            ? Strings.settingsClinicHint
            : Strings.settingsClinicReadOnly,
        onSave: widget.settings.canEditClinic ? _save : null,
        saving: _saving,
        children: [
          _subtitle(context, Strings.settingsClinicData),
          _row(context, [
            field(
              '${Strings.name} *',
              _name,
              maxLength: 60,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? Strings.required : null,
            ),
            field(Strings.settingsLegalName, _legal, maxLength: 80),
          ]),
          _row(context, [
            field(
              Strings.settingsCnpj,
              _cnpj,
              mask: MaskType.cnpj,
              keyboard: TextInputType.number,
            ),
            field(
              Strings.email,
              _email,
              maxLength: 200,
              keyboard: TextInputType.emailAddress,
            ),
          ]),
          _row(context, [
            field(
              Strings.phone,
              _phone,
              mask: MaskType.phone,
              keyboard: TextInputType.phone,
            ),
            field(
              Strings.settingsPhoneExtra,
              _phone2,
              mask: MaskType.phone,
              keyboard: TextInputType.phone,
            ),
          ]),
          _subtitle(context, Strings.settingsAddress),
          _row(context, [
            field(
              Strings.settingsZip,
              _zip,
              mask: MaskType.cep,
              keyboard: TextInputType.number,
            ),
            field(Strings.settingsStreet, _address, maxLength: 60),
          ]),
          _row(context, [
            field(Strings.settingsNumber, _number, maxLength: 10),
            field(Strings.settingsComplement, _extra, maxLength: 60),
            field(Strings.settingsDistrict, _district, maxLength: 30),
          ]),
          _row(context, [
            field(Strings.settingsCity, _city, maxLength: 30),
            field(Strings.settingsState, _state, maxLength: 2),
          ]),
          _subtitle(context, Strings.settingsTechnical),
          _row(context, [
            field(Strings.settingsTechnicalName, _techName, maxLength: 120),
            field(Strings.settingsTechnicalCro, _techCro, maxLength: 20),
            field(Strings.settingsTechnicalState, _techState, maxLength: 2),
          ]),
          _subtitle(context, Strings.settingsForum),
          const Text(
            Strings.settingsForumHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(Strings.settingsForumSame),
            value: _sameForum,
            onChanged: enabled
                ? (v) => setState(() => _sameForum = v ?? true)
                : null,
          ),
          if (!_sameForum)
            field(Strings.settingsForumCity, _forum, maxLength: 60),
        ],
      ),
    );
  }
}

class _AgendaForm extends ConsumerStatefulWidget {
  const _AgendaForm({super.key, required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<_AgendaForm> createState() => _AgendaFormState();
}

class _AgendaFormState extends ConsumerState<_AgendaForm> {
  late int _slot = widget.settings.qtSlotMinutes;
  late int _parallel = widget.settings.qtMaxParallel;
  late bool _outside = widget.settings.idAllowOutsideHours;
  late String _tz = widget.settings.clinic.vcTimezone ?? 'America/Sao_Paulo';
  late List<ScheduleRange> _hours = [...widget.settings.hours];
  bool _saving = false;

  Future<void> _save() async {
    final overlap = WeekScheduleEditor.overlapDay(_hours);
    if (overlap != null) {
      AppSnack.error(context, Strings.scheduleOverlap(Weekday.label(overlap)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).save({
        'qt_slot_minutes': _slot,
        'qt_max_parallel': _parallel,
        'id_allow_outside_hours': _outside,
        'hours': [for (final h in _hours) h.toJson()],
      });
      if (widget.settings.canEditClinic &&
          _tz != (widget.settings.clinic.vcTimezone ?? 'America/Sao_Paulo')) {
        await ref.read(settingsProvider.notifier).saveClinic({
          'vc_timezone': _tz,
        });
      }
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final can = widget.settings.canUpdate && !_saving;
    return _SectionCard(
      title: Strings.settingsAgenda,
      hint: Strings.settingsAgendaHint,
      onSave: widget.settings.canUpdate ? _save : null,
      saving: _saving,
      children: [
        _subtitle(context, Strings.settingsSlot),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final m in BranchSettings.slotOptions)
              ChoiceChip(
                label: Text(Strings.minutesShort(m)),
                selected: _slot == m,
                onSelected: can ? (_) => setState(() => _slot = m) : null,
              ),
          ],
        ),
        _subtitle(context, Strings.settingsParallel),
        Text(
          Strings.settingsParallelHint,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            IconButton(
              tooltip: '−',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: can && _parallel > 1
                  ? () => setState(() => _parallel--)
                  : null,
            ),
            Text(
              '$_parallel',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            IconButton(
              tooltip: '+',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: can && _parallel < 20
                  ? () => setState(() => _parallel++)
                  : null,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.settingsOutside),
          subtitle: const Text(Strings.settingsOutsideHint),
          value: _outside,
          onChanged: can ? (v) => setState(() => _outside = v) : null,
        ),
        _subtitle(context, Strings.settingsTimezone),
        SizedBox(
          width: 360,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: BranchSettings.timezones.contains(_tz)
                ? _tz
                : BranchSettings.timezones.first,
            decoration: InputDecoration(
              helperText: widget.settings.canEditClinic
                  ? null
                  : Strings.settingsClinicReadOnly,
            ),
            items: [
              for (final z in BranchSettings.timezones)
                DropdownMenuItem(
                  value: z,
                  child: Text(Strings.timezoneLabel(z)),
                ),
            ],
            onChanged: can && widget.settings.canEditClinic
                ? (v) => setState(() => _tz = v ?? _tz)
                : null,
          ),
        ),
        _subtitle(context, Strings.settingsBusinessHours),
        const Text(
          Strings.settingsBusinessHoursHint,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        WeekScheduleEditor(
          ranges: _hours,
          enabled: can,
          compact: context.isMobile,
          onChanged: (r) => setState(() => _hours = r),
        ),
      ],
    );
  }
}

class _PatientsForm extends ConsumerStatefulWidget {
  const _PatientsForm({super.key, required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<_PatientsForm> createState() => _PatientsFormState();
}

class _PatientsFormState extends ConsumerState<_PatientsForm> {
  static String _requiredLabel(String o) => switch (o) {
    PatientRequired.rg => Strings.rg,
    PatientRequired.gender => Strings.gender,
    PatientRequired.maritalStatus => Strings.maritalStatus,
    PatientRequired.education => Strings.education,
    PatientRequired.source => Strings.howFound,
    PatientRequired.referral => Strings.referredBy,
    PatientRequired.mobile => Strings.mobile,
    PatientRequired.phone => Strings.landline,
    PatientRequired.email => Strings.email,
    PatientRequired.address => Strings.settingsRequiredAddress,
    PatientRequired.profession => Strings.profession,
    PatientRequired.plan => Strings.settingsRequiredPlan,
    _ => o,
  };

  late bool _auto = widget.settings.idAutoRecordNumber;
  late final _next = TextEditingController(
    text: '${widget.settings.nrNextRecord}',
  );
  late final Set<String> _required = {...widget.settings.vcPatientRequired};
  bool _saving = false;

  @override
  void dispose() {
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = int.tryParse(_next.text.trim());
    if (next == null || next < 1) {
      AppSnack.error(context, Strings.settingsNextRecordInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).save({
        'id_auto_record_number': _auto,
        'nr_next_record': next,
        'vc_patient_required': [
          for (final o in PatientRequired.all)
            if (_required.contains(o)) o,
        ],
      });
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final can = widget.settings.canUpdate && !_saving;
    return _SectionCard(
      title: Strings.settingsPatients,
      hint: Strings.settingsPatientsHint,
      onSave: widget.settings.canUpdate ? _save : null,
      saving: _saving,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.settingsAutoRecord),
          subtitle: const Text(Strings.settingsAutoRecordHint),
          value: _auto,
          onChanged: can ? (v) => setState(() => _auto = v) : null,
        ),
        if (_auto)
          SizedBox(
            width: 220,
            child: AppTextField(
              label: Strings.settingsNextRecord,
              controller: _next,
              enabled: can,
              keyboardType: TextInputType.number,
            ),
          ),
        _subtitle(context, Strings.settingsRequired),
        const Text(
          Strings.settingsRequiredFixedHint,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        for (final label in const [
          Strings.fullName,
          Strings.birthDate,
          Strings.cpf,
        ])
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label),
            subtitle: const Text(Strings.settingsRequiredAlways),
            value: true,
            onChanged: null,
          ),
        _subtitle(context, Strings.settingsRequiredOptional),
        const Text(
          Strings.settingsRequiredOptionalHint,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in PatientRequired.all)
              FilterChip(
                label: Text(_requiredLabel(o)),
                selected: _required.contains(o),
                onSelected: can
                    ? (v) => setState(
                        () => v ? _required.add(o) : _required.remove(o),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _FinanceForm extends ConsumerStatefulWidget {
  const _FinanceForm({super.key, required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<_FinanceForm> createState() => _FinanceFormState();
}

class _FinanceFormState extends ConsumerState<_FinanceForm> {
  final _formKey = GlobalKey<FormState>();
  late int _rule = widget.settings.itDebtRule;
  late int _openRule = widget.settings.itOpenRule;
  late int _lateEdit = widget.settings.itLateEdit;
  late bool _budgetRequest = widget.settings.idBudgetRequestApproval;
  late bool _budgetBelowMin = widget.settings.idBudgetAdminBelowMin;
  late bool _budgetReduction = widget.settings.idBudgetReductionAsDiscount;
  late final _days = TextEditingController(
    text: '${widget.settings.qtDebtDays}',
  );
  late bool _cash = widget.settings.idCashEnabled;
  late final Set<int> _methods = {...widget.settings.itPaymentMethods};
  late final _fee = TextEditingController(
    text: Numbers.toField(widget.settings.pcLateFee),
  );
  late final _interest = TextEditingController(
    text: Numbers.toField(widget.settings.pcLateInterest),
  );
  late final _dreRevenue = TextEditingController(
    text: Numbers.toField(widget.settings.pcDreRevenueTax),
  );
  late final _dreIncome = TextEditingController(
    text: Numbers.toField(widget.settings.pcDreIncomeTax),
  );
  late final _dreCsll = TextEditingController(
    text: Numbers.toField(widget.settings.pcDreCsll),
  );
  late final _budgetMax = TextEditingController(
    text: Numbers.toField(widget.settings.pcBudgetMaxDiscount),
  );
  late final _budgetDays = TextEditingController(
    text: '${widget.settings.qtBudgetValidDays}',
  );
  late final _receiptPrefix = TextEditingController(
    text: widget.settings.vcReceiptPrefix,
  );
  late final _receiptNext = TextEditingController(
    text: '${widget.settings.nrNextReceipt}',
  );
  bool _saving = false;

  @override
  void dispose() {
    _days.dispose();
    _fee.dispose();
    _interest.dispose();
    _dreRevenue.dispose();
    _dreIncome.dispose();
    _dreCsll.dispose();
    _receiptPrefix.dispose();
    _budgetMax.dispose();
    _budgetDays.dispose();
    _receiptNext.dispose();
    super.dispose();
  }

  String _ruleLabel(int r) => switch (r) {
    DebtRule.warn => Strings.debtRuleWarn,
    DebtRule.approval => Strings.debtRuleApproval,
    DebtRule.block => Strings.debtRuleBlock,
    _ => Strings.debtRuleNone,
  };

  String _ruleHint(int r) => switch (r) {
    DebtRule.warn => Strings.debtRuleWarnHint,
    DebtRule.approval => Strings.debtRuleApprovalHint,
    DebtRule.block => Strings.debtRuleBlockHint,
    _ => Strings.debtRuleNoneHint,
  };

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_methods.isEmpty) {
      AppSnack.error(context, Strings.settingsMethodsRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).save({
        'it_debt_rule': _rule,
        'it_open_rule': _openRule,
        'it_late_edit': _lateEdit,
        'id_budget_request_approval': _budgetRequest,
        'id_budget_admin_below_min': _budgetBelowMin,
        'id_budget_reduction_as_discount': _budgetReduction,
        'qt_debt_days': int.tryParse(_days.text.trim()) ?? 0,
        'id_cash_enabled': _cash,
        'it_payment_methods': (_methods.toList()..sort()),
        'pc_late_fee': Numbers.parse(_fee.text) ?? 0,
        'pc_late_interest': Numbers.parse(_interest.text) ?? 0,
        'pc_dre_revenue_tax': Numbers.parse(_dreRevenue.text) ?? 0,
        'pc_dre_income_tax': Numbers.parse(_dreIncome.text) ?? 0,
        'pc_dre_csll': Numbers.parse(_dreCsll.text) ?? 0,
        'vc_receipt_prefix': _receiptPrefix.text.trim().toUpperCase(),
        'pc_budget_max_discount': Numbers.parse(_budgetMax.text) ?? 10,
        'qt_budget_valid_days': int.tryParse(_budgetDays.text.trim()) ?? 30,
        'nr_next_receipt': int.tryParse(_receiptNext.text.trim()) ?? 1,
      });
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _percent(String? v) {
    final n = Numbers.parse(v) ?? 0;
    return n < 0 || n > 10 ? Strings.settingsPercentRange : null;
  }

  String? _taxPercent(String? v) {
    final n = Numbers.parse(v) ?? 0;
    return n < 0 || n > 50 ? Strings.settingsTaxRange : null;
  }

  @override
  Widget build(BuildContext context) {
    final can = widget.settings.canUpdate && !_saving;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _SectionCard(
        title: Strings.settingsFinance,
        hint: Strings.settingsFinanceHint,
        onSave: widget.settings.canUpdate ? _save : null,
        saving: _saving,
        children: [
          _subtitle(context, Strings.settingsDebt),
          const Text(
            Strings.settingsDebtHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          RadioGroup<int>(
            groupValue: _rule,
            onChanged: (v) {
              if (can && v != null) setState(() => _rule = v);
            },
            child: Column(
              children: [
                for (final r in DebtRule.all)
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: r,
                    enabled: can,
                    title: Text(_ruleLabel(r)),
                    subtitle: Text(_ruleHint(r)),
                  ),
              ],
            ),
          ),
          if (_rule != DebtRule.none)
            SizedBox(
              width: 260,
              child: AppNumberField(
                label: Strings.settingsDebtDays,
                helper: Strings.settingsDebtDaysHint,
                controller: _days,
                decimals: 0,
                enabled: can,
                validator: (v) {
                  final n = int.tryParse(v ?? '') ?? 0;
                  return n < 0 || n > 365 ? '0 – 365' : null;
                },
              ),
            ),
          _subtitle(context, Strings.settingsOpen),
          const Text(
            Strings.settingsOpenHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          RadioGroup<int>(
            groupValue: _openRule,
            onChanged: (v) {
              if (can && v != null) setState(() => _openRule = v);
            },
            child: Column(
              children: [
                for (final r in DebtRule.all)
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: r,
                    enabled: can,
                    title: Text(_ruleLabel(r)),
                  ),
              ],
            ),
          ),
          _subtitle(context, Strings.settingsCash),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(Strings.settingsCashEnabled),
            subtitle: const Text(Strings.settingsCashEnabledHint),
            value: _cash,
            onChanged: can ? (v) => setState(() => _cash = v) : null,
          ),
          _subtitle(context, Strings.settingsMethods),
          const Text(
            Strings.settingsMethodsHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in BranchSettings.allPaymentMethods)
                FilterChip(
                  label: Text(PaymentMethod.label(m)),
                  selected: _methods.contains(m),
                  onSelected: can
                      ? (v) => setState(
                          () => v ? _methods.add(m) : _methods.remove(m),
                        )
                      : null,
                ),
            ],
          ),
          _subtitle(context, Strings.settingsLate),
          const Text(
            Strings.settingsLateHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context, [
            AppNumberField(
              label: Strings.settingsLateFee,
              controller: _fee,
              suffixText: '%',
              enabled: can,
              validator: _percent,
            ),
            AppNumberField(
              label: Strings.settingsLateInterest,
              controller: _interest,
              suffixText: Strings.settingsPerMonth,
              enabled: can,
              validator: _percent,
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _lateEdit,
            decoration: const InputDecoration(
              labelText: Strings.settingsLateEdit,
            ),
            items: const [
              DropdownMenuItem(
                value: 0,
                child: Text(Strings.settingsLateEdit0),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text(Strings.settingsLateEdit1),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text(Strings.settingsLateEdit2),
              ),
            ],
            onChanged: can ? (v) => setState(() => _lateEdit = v ?? 0) : null,
          ),
          _subtitle(context, Strings.settingsDre),
          const Text(
            Strings.settingsDreHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context, [
            AppNumberField(
              label: Strings.settingsDreRevenueTax,
              controller: _dreRevenue,
              suffixText: '%',
              enabled: can,
              validator: _taxPercent,
            ),
            AppNumberField(
              label: Strings.settingsDreIncomeTax,
              controller: _dreIncome,
              suffixText: '%',
              enabled: can,
              validator: _taxPercent,
            ),
            AppNumberField(
              label: Strings.settingsDreCsll,
              controller: _dreCsll,
              suffixText: '%',
              enabled: can,
              validator: _taxPercent,
            ),
          ]),
          _subtitle(context, Strings.settingsBudgets),
          const Text(
            Strings.settingsBudgetsHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context, [
            AppNumberField(
              label: Strings.settingsBudgetMax,
              controller: _budgetMax,
              suffixText: '%',
              enabled: can,
              validator: (v) {
                final n = Numbers.parse(v) ?? 0;
                return n < 0 || n > 100 ? '0 – 100' : null;
              },
            ),
            AppNumberField(
              label: Strings.settingsBudgetDays,
              controller: _budgetDays,
              decimals: 0,
              enabled: can,
              validator: (v) {
                final n = int.tryParse(v ?? '') ?? 0;
                return n < 1 || n > 365 ? '1 – 365' : null;
              },
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(Strings.settingsBudgetRequest),
            subtitle: const Text(Strings.settingsBudgetRequestHint),
            value: _budgetRequest,
            onChanged: can ? (v) => setState(() => _budgetRequest = v) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(Strings.settingsBudgetBelowMin),
            subtitle: const Text(Strings.settingsBudgetBelowMinHint),
            value: _budgetBelowMin,
            onChanged: can ? (v) => setState(() => _budgetBelowMin = v) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(Strings.settingsBudgetReduction),
            subtitle: const Text(Strings.settingsBudgetReductionHint),
            value: _budgetReduction,
            onChanged: can ? (v) => setState(() => _budgetReduction = v) : null,
          ),
          _subtitle(context, Strings.settingsReceipts),
          const Text(
            Strings.settingsReceiptsHint,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context, [
            AppTextField(
              label: Strings.settingsReceiptPrefix,
              hint: 'REC-',
              controller: _receiptPrefix,
              maxLength: 10,
              enabled: can,
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  RegExp(r'^[A-Za-z0-9./-]*$').hasMatch((v ?? '').trim())
                  ? null
                  : Strings.settingsReceiptPrefixInvalid,
            ),
            AppNumberField(
              label: Strings.settingsReceiptNext,
              controller: _receiptNext,
              decimals: 0,
              enabled: can,
              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                  ? Strings.settingsNextRecordInvalid
                  : null,
            ),
          ]),
        ],
      ),
    );
  }
}

class _ExportForm extends ConsumerStatefulWidget {
  const _ExportForm({required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<_ExportForm> createState() => _ExportFormState();
}

class _ExportFormState extends ConsumerState<_ExportForm> {
  final _formKey = GlobalKey<FormState>();
  late final _from = TextEditingController(
    text: Dates.toField(DateTime(DateTime.now().year, DateTime.now().month)),
  );
  late final _to = TextEditingController(
    text: Dates.toField(
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
    ),
  );
  int? _finKind;
  bool _inactive = false;
  ExportKind? _busy;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  String _code(ExportKind k) => switch (k) {
    ExportKind.patients => ScreenCodes.patients,
    ExportKind.finance => ScreenCodes.finance,
    ExportKind.procedures => ScreenCodes.pricing,
    ExportKind.agenda => ScreenCodes.agenda,
  };

  String _label(ExportKind k) => switch (k) {
    ExportKind.patients => Strings.exportPatients,
    ExportKind.finance => Strings.exportFinance,
    ExportKind.procedures => Strings.exportProcedures,
    ExportKind.agenda => Strings.exportAgenda,
  };

  String _hint(ExportKind k) => switch (k) {
    ExportKind.patients => Strings.exportPatientsHint,
    ExportKind.finance => Strings.exportFinanceHint,
    ExportKind.procedures => Strings.exportProceduresHint,
    ExportKind.agenda => Strings.exportAgendaHint,
  };

  IconData _icon(ExportKind k) => switch (k) {
    ExportKind.patients => Icons.people_outline_rounded,
    ExportKind.finance => Icons.account_balance_wallet_outlined,
    ExportKind.procedures => Icons.medical_services_outlined,
    ExportKind.agenda => Icons.calendar_month_outlined,
  };

  bool _periodic(ExportKind k) =>
      k == ExportKind.finance || k == ExportKind.agenda;

  Future<void> _export(ExportKind kind) async {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    final params = <String, dynamic>{};
    if (_periodic(kind)) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      final from = Dates.parseField(_from.text)!;
      final to = Dates.parseField(_to.text)!;
      if (to.isBefore(from) || to.difference(from).inDays > 400) {
        AppSnack.error(context, Strings.exportPeriodInvalid);
        return;
      }
      params['dt_from'] = Dates.toIso(from);
      params['dt_to'] = Dates.toIso(to);
      if (kind == ExportKind.finance && _finKind != null) {
        params['it_kind'] = _finKind;
      }
    } else {
      params['id_include_inactive'] = _inactive;
    }
    setState(() => _busy = kind);
    try {
      final table = await ref
          .read(settingsRepositoryProvider)
          .export(nrCompany: c, nrBranch: b, kind: kind, params: params);
      if (table.rows.isEmpty) {
        if (mounted) AppSnack.info(context, Strings.exportEmpty);
        return;
      }
      final now = DateTime.now();
      await FileDownload.saveXlsx(
        name: DataExportXlsx.fileName(kind, now),
        bytes: DataExportXlsx.build(table, sheetName: _label(kind)),
      );
      if (mounted) {
        AppSnack.success(context, Strings.exportRows(table.rows.length));
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.settings.canUpdate;
    String? date(String? v) =>
        Dates.parseField(v) == null ? Strings.invalidDate : null;
    return Form(
      key: _formKey,
      child: _SectionCard(
        title: Strings.settingsExport,
        hint: Strings.settingsExportHint,
        children: [
          if (!allowed)
            const Text(
              Strings.exportForbidden,
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            _subtitle(context, Strings.exportOptions),
            _row(context, [
              AppTextField(
                label: Strings.exportFrom,
                controller: _from,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
                validator: date,
              ),
              AppTextField(
                label: Strings.exportTo,
                controller: _to,
                mask: MaskType.date,
                keyboardType: TextInputType.number,
                validator: date,
              ),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _finKind,
                decoration: const InputDecoration(
                  labelText: Strings.exportFinanceKind,
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text(Strings.exportBoth),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(Strings.exportReceivable),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(Strings.exportPayable),
                  ),
                ],
                onChanged: (v) => setState(() => _finKind = v),
              ),
            ]),
            const Text(
              Strings.exportPeriodHint,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(Strings.exportInactive),
              value: _inactive,
              onChanged: (v) => setState(() => _inactive = v ?? false),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final k in ExportKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: AppColors.mint,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_icon(k), color: AppColors.primary),
                              const SizedBox(width: AppSpacing.md),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _label(k),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ref.watch(canReadProvider(_code(k)))
                                          ? _hint(k)
                                          : Strings.exportNoScreen,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: Strings.exportExcel,
                          icon: Icons.file_download_outlined,
                          expanded: false,
                          loading: _busy == k,
                          onPressed:
                              _busy == null &&
                                  ref.watch(canReadProvider(_code(k)))
                              ? () => _export(k)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrashList extends ConsumerStatefulWidget {
  const _TrashList();

  @override
  ConsumerState<_TrashList> createState() => _TrashListState();
}

class _TrashListState extends ConsumerState<_TrashList> {
  final _search = TextEditingController();
  TrashData? _data;
  Object? _error;
  String? _kind;
  int? _restoring;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    setState(() => _loading = true);
    try {
      final d = await ref
          .read(settingsRepositoryProvider)
          .trash(
            nrCompany: c,
            nrBranch: b,
            kind: _kind,
            search: _search.text.trim(),
          );
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(int index, TrashItem item) async {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    setState(() => _restoring = index);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .restore(nrCompany: c, nrBranch: b, item: item);
      if (mounted) AppSnack.success(context, Strings.trashRestored);
      await _load();
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return _SectionCard(
      title: Strings.settingsTrash,
      hint: Strings.settingsTrashHint,
      children: [
        AppTextField(
          label: Strings.search,
          controller: _search,
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _load(),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (d != null && d.kinds.length > 1)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text(Strings.trashAll),
                selected: _kind == null,
                onSelected: (_) {
                  setState(() => _kind = null);
                  _load();
                },
              ),
              for (final k in d.kinds)
                ChoiceChip(
                  avatar: Icon(TrashKind.icon(k), size: 18),
                  label: Text(TrashKind.label(k)),
                  selected: _kind == k,
                  onSelected: (_) {
                    setState(() => _kind = k);
                    _load();
                  },
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null)
          AppEmptyState.error(message: describeError(_error!), onRetry: _load)
        else if (d == null || (_loading && d.items.isEmpty))
          const Center(child: CircularProgressIndicator())
        else if (d.items.isEmpty)
          const AppEmptyState(
            icon: Icons.delete_outline_rounded,
            title: Strings.trashEmpty,
            subtitle: Strings.trashEmptyHint,
          )
        else
          for (var i = 0; i < d.items.length; i++)
            _TrashTile(
              item: d.items[i],
              restoring: _restoring == i,
              onRestore: _restoring == null && d.items[i].idRestore
                  ? () => _restore(i, d.items[i])
                  : null,
            ),
      ],
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.item,
    required this.restoring,
    required this.onRestore,
  });

  final TrashItem item;
  final bool restoring;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final who = item.vcUser == null ? '' : ' · ${item.vcUser}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Icon(TrashKind.icon(item.vcKind), color: AppColors.primary),
        ),
        title: Text(item.vcTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${TrashKind.label(item.vcKind)} · ${item.vcDetail}\n'
          '${Strings.trashDeletedAt(Dates.formatTime(item.dhDeleted))}$who',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: restoring
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded),
                label: const Text(Strings.trashRestore),
              ),
      ),
    );
  }
}
