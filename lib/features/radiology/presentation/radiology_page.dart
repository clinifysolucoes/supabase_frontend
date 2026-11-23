import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/radiology_controllers.dart';
import '../domain/radiology_models.dart';

Color _statusColor(RadiologyStatus s) => switch (s) {
  RadiologyStatus.requested => AppColors.primary,
  RadiologyStatus.scheduled => AppColors.warning,
  RadiologyStatus.done => const Color(0xFF3B82F6),
  RadiologyStatus.report => const Color(0xFF2E9E6B),
  RadiologyStatus.cancelled => AppColors.muted,
};

/// Tela Exames de Imagem: pedidos de exame aos centros radiologicos, com
/// totais por situacao, e o cadastro dos centros.
class RadiologyPage extends ConsumerWidget {
  const RadiologyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.radiology))) {
      return const AppShell(
        section: AppSection.radiology,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.radiology));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.radiology));
    final status = ref.watch(radiologyStatusFilterProvider);
    final async = ref.watch(radiologyListProvider);
    final d = async.valueOrNull;
    return AppShell(
      section: AppSection.radiology,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppPageHeader(
            title: Strings.radiology,
            subtitle: Strings.radiologySubtitle,
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.local_hospital_outlined),
                label: const Text(Strings.rxCenters),
                onPressed: () => RadiologyCentersDialog.show(context),
              ),
              if (canCreate)
                AppButton(
                  label: Strings.rxNew,
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () => RadiologyFormDialog.show(context),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text(Strings.alignerAll),
                selected: status == null,
                onSelected: (_) =>
                    ref.read(radiologyStatusFilterProvider.notifier).state =
                        null,
              ),
              for (final s in RadiologyStatus.values)
                if (s != RadiologyStatus.cancelled)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 9,
                      backgroundColor: _statusColor(s),
                      child: Text(
                        '${d?.totals[s] ?? 0}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    label: Text(s.plural),
                    selected: status == s,
                    onSelected: (_) =>
                        ref.read(radiologyStatusFilterProvider.notifier).state =
                            s,
                  ),
              ChoiceChip(
                label: const Text(Strings.rxCancelled),
                selected: status == RadiologyStatus.cancelled,
                onSelected: (_) =>
                    ref.read(radiologyStatusFilterProvider.notifier).state =
                        RadiologyStatus.cancelled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 420,
            child: AppTextField(
              label: Strings.rxSearch,
              prefixIcon: Icons.search_rounded,
              onChanged: (v) =>
                  ref.read(radiologySearchProvider.notifier).state = v.trim(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(radiologyListProvider),
            ),
            data: (data) => data.requests.isEmpty
                ? const AppEmptyState(
                    icon: Icons.document_scanner_outlined,
                    title: Strings.rxEmpty,
                  )
                : Column(
                    children: [
                      for (final r in data.requests)
                        _RequestCard(
                          item: r,
                          onTap: canUpdate
                              ? () => RadiologyFormDialog.show(context, item: r)
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, this.onTap});

  final RadiologyRequest item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = item;
    final color = _statusColor(r.status);
    final dates = [
      Strings.rxRequestedOn(Dates.format(r.dtRequest)),
      if (r.dtScheduled != null)
        Strings.rxScheduledOn(Dates.format(r.dtScheduled)),
      if (r.dtDone != null) Strings.rxDoneOn(Dates.format(r.dtDone)),
      if (r.dtReport != null) Strings.rxReportOn(Dates.format(r.dtReport)),
    ];
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.vcPatient,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      r.status.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: color.withValues(alpha: 0.12),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                [
                  r.exams.join(', '),
                  if ((r.vcRegion ?? '').isNotEmpty)
                    '${Strings.rxRegionShort} ${r.vcRegion}',
                ].join(' · '),
              ),
              Text(
                [
                  r.vcCenter ?? Strings.rxNoCenter,
                  if (r.vcProfessional != null) r.vcProfessional!,
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                dates.join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if ((r.vcReportUrl ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: SelectableText(
                          r.vcReportUrl!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: Strings.rxCopyLink,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: r.vcReportUrl!),
                          );
                          if (context.mounted) {
                            AppSnack.success(context, Strings.rxLinkCopied);
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pedido de exame: paciente, exames, centro, situacao, datas e laudo.
class RadiologyFormDialog extends ConsumerStatefulWidget {
  const RadiologyFormDialog({super.key, this.item});

  final RadiologyRequest? item;

  static Future<void> show(BuildContext context, {RadiologyRequest? item}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RadiologyFormDialog(item: item),
      );

  @override
  ConsumerState<RadiologyFormDialog> createState() =>
      _RadiologyFormDialogState();
}

class _RadiologyFormDialogState extends ConsumerState<RadiologyFormDialog> {
  RadiologyRequest? get _r => widget.item;
  late int? _nrPatient = _r?.nrPatient;
  late String? _vcPatient = _r?.vcPatient;
  late int? _nrProfessional = _r?.nrProfessional;
  late int? _nrCenter = _r?.nrCenter;
  late RadiologyStatus _status = _r?.status ?? RadiologyStatus.requested;
  late final Set<String> _exams = {...?_r?.exams};
  final _other = TextEditingController();
  late final _region = TextEditingController(text: _r?.vcRegion ?? '');
  late final _notes = TextEditingController(text: _r?.vcNotes ?? '');
  late final _requested = TextEditingController(
    text: Dates.toField(_r?.dtRequest ?? DateTime.now()),
  );
  late final _scheduled = TextEditingController(
    text: _r?.dtScheduled == null ? '' : Dates.toField(_r!.dtScheduled!),
  );
  late final _url = TextEditingController(text: _r?.vcReportUrl ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_other, _region, _notes, _requested, _scheduled, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null) {
      setState(() {
        _nrPatient = p.nrPatient;
        _vcPatient = p.vcName;
      });
    }
  }

  void _addOther() {
    final t = _other.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _exams.add(t);
      _other.clear();
    });
  }

  Future<void> _save() async {
    if (_nrPatient == null) {
      AppSnack.error(context, Strings.choosePatient);
      return;
    }
    _addOther();
    if (_exams.isEmpty) {
      AppSnack.error(context, Strings.rxExamsRequired);
      return;
    }
    final requested = Dates.parseField(_requested.text);
    final scheduled = _scheduled.text.trim().isEmpty
        ? null
        : Dates.parseField(_scheduled.text);
    if (requested == null ||
        (_scheduled.text.trim().isNotEmpty && scheduled == null)) {
      AppSnack.error(context, Strings.rxDateInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(radiologySaveProvider)(_r?.nrRequest, {
        if (_r == null) 'nr_patient': _nrPatient,
        'nr_center': _nrCenter,
        'nr_professional': _nrProfessional,
        'dt_request': Dates.toIso(requested),
        'ar_exams': _exams.toList(),
        'vc_region': _region.text.trim(),
        'vc_notes': _notes.text.trim(),
        'it_status': _status.code,
        'dt_scheduled': scheduled == null ? null : Dates.toIso(scheduled),
        'vc_report_url': _url.text.trim(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        AppSnack.success(context, Strings.savedSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final professionals =
        ref.watch(agendaProfessionalsProvider).valueOrNull ?? const [];
    final centers =
        ref.watch(radiologyListProvider).valueOrNull?.centers ?? const [];
    final options = [
      for (final c in centers)
        if (c.isActive || c.nrCenter == _r?.nrCenter) c,
    ];
    return AlertDialog(
      title: Text(_r == null ? Strings.rxNew : Strings.rxEdit),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_search_rounded),
                title: Text(_vcPatient ?? Strings.choosePatient),
                subtitle: const Text(Strings.patient),
                onTap: _saving || _r != null ? null : _pickPatient,
              ),
              Text(
                Strings.rxExams,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final e in {...radiologyExams, ..._exams})
                    FilterChip(
                      label: Text(e),
                      selected: _exams.contains(e),
                      onSelected: _saving
                          ? null
                          : (v) => setState(
                              () => v ? _exams.add(e) : _exams.remove(e),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: Strings.rxOtherExam,
                      controller: _other,
                      enabled: !_saving,
                      maxLength: 80,
                      onFieldSubmitted: (_) => _addOther(),
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.rxAddExam,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: _saving ? null : _addOther,
                  ),
                ],
              ),
              AppTextField(
                label: Strings.rxRegion,
                controller: _region,
                enabled: !_saving,
                maxLength: 120,
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _nrCenter,
                      decoration: const InputDecoration(
                        labelText: Strings.rxCenter,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(Strings.notInformed),
                        ),
                        for (final c in options)
                          DropdownMenuItem(
                            value: c.nrCenter,
                            child: Text(c.vcName),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _nrCenter = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _nrProfessional,
                      decoration: const InputDecoration(
                        labelText: Strings.professional,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(Strings.notInformed),
                        ),
                        for (final p in professionals)
                          DropdownMenuItem(
                            value: p.nrProfessional,
                            child: Text(p.vcName),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _nrProfessional = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<RadiologyStatus>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: Strings.alignerStatus,
                      ),
                      items: [
                        for (final s in RadiologyStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.label)),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _status = v ?? _status),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.rxRequestDate,
                      controller: _requested,
                      enabled: !_saving,
                      hint: 'dd/mm/aaaa',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.rxScheduledDate,
                      controller: _scheduled,
                      enabled: !_saving,
                      hint: 'dd/mm/aaaa',
                    ),
                  ),
                ],
              ),
              if (_r?.dtDone != null || _r?.dtReport != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    [
                      if (_r?.dtDone != null)
                        Strings.rxDoneOn(Dates.format(_r!.dtDone)),
                      if (_r?.dtReport != null)
                        Strings.rxReportOn(Dates.format(_r!.dtReport)),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.rxReportUrl,
                helperText: Strings.rxReportUrlHint,
                controller: _url,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                maxLength: 500,
              ),
              AppTextField(
                label: Strings.rxNotes,
                controller: _notes,
                enabled: !_saving,
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.save,
          expanded: false,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Lista dos centros radiologicos da filial, com cadastro e alteracao.
class RadiologyCentersDialog extends ConsumerWidget {
  const RadiologyCentersDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const RadiologyCentersDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.radiology));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.radiology));
    final centers =
        ref.watch(radiologyListProvider).valueOrNull?.centers ?? const [];
    return AlertDialog(
      title: const Text(Strings.rxCenters),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.rxCentersHint,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (centers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(Strings.rxCentersEmpty),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in centers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        c.itIntegration == 1
                            ? Icons.sync_rounded
                            : Icons.local_hospital_outlined,
                        color: c.isActive ? AppColors.primary : AppColors.muted,
                      ),
                      title: Text(
                        c.isActive
                            ? c.vcName
                            : '${c.vcName} (${Strings.statusInactive})',
                      ),
                      subtitle: Text(
                        [
                          if ((c.vcPhone ?? '').isNotEmpty)
                            Masks.format(MaskType.phone, c.vcPhone!),
                          if ((c.vcEmail ?? '').isNotEmpty) c.vcEmail!,
                          if (c.itIntegration == 1) Strings.rxIntegrationAuto,
                        ].join(' · '),
                      ),
                      onTap: canUpdate
                          ? () =>
                                RadiologyCenterFormDialog.show(context, item: c)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.close),
        ),
        if (canCreate)
          AppButton(
            label: Strings.rxCenterNew,
            icon: Icons.add_rounded,
            expanded: false,
            onPressed: () => RadiologyCenterFormDialog.show(context),
          ),
      ],
    );
  }
}

class RadiologyCenterFormDialog extends ConsumerStatefulWidget {
  const RadiologyCenterFormDialog({super.key, this.item});

  final RadiologyCenter? item;

  static Future<void> show(BuildContext context, {RadiologyCenter? item}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RadiologyCenterFormDialog(item: item),
      );

  @override
  ConsumerState<RadiologyCenterFormDialog> createState() =>
      _RadiologyCenterFormDialogState();
}

class _RadiologyCenterFormDialogState
    extends ConsumerState<RadiologyCenterFormDialog> {
  RadiologyCenter? get _c => widget.item;
  late final _name = TextEditingController(text: _c?.vcName ?? '');
  late final _phone = TextEditingController(
    text: (_c?.vcPhone ?? '').isEmpty
        ? ''
        : Masks.format(MaskType.phone, _c!.vcPhone!),
  );
  late final _email = TextEditingController(text: _c?.vcEmail ?? '');
  late final _address = TextEditingController(text: _c?.vcAddress ?? '');
  late final _notes = TextEditingController(text: _c?.vcNotes ?? '');
  late final _code = TextEditingController(text: _c?.vcExternalCode ?? '');
  late bool _auto = (_c?.itIntegration ?? 0) == 1;
  late bool _active = _c?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _notes, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(radiologyCenterSaveProvider)(_c?.nrCenter, {
        'vc_name': _name.text.trim(),
        'vc_phone': Masks.unmask(_phone.text),
        'vc_email': _email.text.trim(),
        'vc_address': _address.text.trim(),
        'vc_notes': _notes.text.trim(),
        'vc_external_code': _code.text.trim(),
        'it_integration': _auto ? 1 : 0,
        'it_status': _active ? 1 : 90,
      });
      if (mounted) {
        Navigator.of(context).pop();
        AppSnack.success(context, Strings.savedSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_c == null ? Strings.rxCenterNew : Strings.rxCenter),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: Strings.rxCenterName,
                controller: _name,
                enabled: !_saving,
                maxLength: 120,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: Strings.phone,
                      controller: _phone,
                      enabled: !_saving,
                      mask: MaskType.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.email,
                      controller: _email,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.rxAddress,
                controller: _address,
                enabled: !_saving,
                maxLength: 200,
              ),
              AppTextField(
                label: Strings.notes,
                controller: _notes,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 2,
                minLines: 1,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Strings.rxIntegrationAuto),
                subtitle: const Text(Strings.rxIntegrationHint),
                value: _auto,
                onChanged: _saving ? null : (v) => setState(() => _auto = v),
              ),
              if (_auto)
                AppTextField(
                  label: Strings.rxExternalCode,
                  controller: _code,
                  enabled: !_saving,
                  maxLength: 60,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Strings.statusActive),
                value: _active,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.save,
          expanded: false,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
