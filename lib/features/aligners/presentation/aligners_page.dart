import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
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
import '../application/aligner_controllers.dart';
import '../domain/aligner_models.dart';

Color _statusColor(AlignerStatus s) => switch (s) {
  AlignerStatus.started => AppColors.primary,
  AlignerStatus.pendingClinic ||
  AlignerStatus.pendingCompany => AppColors.warning,
  AlignerStatus.treatment => const Color(0xFF3B82F6),
  AlignerStatus.finished => const Color(0xFF2E9E6B),
  AlignerStatus.cancelled => AppColors.muted,
};

/// Tela Gestao de Casos de Alinhadores: totais por situacao (iniciados,
/// pendencias da clinica e da empresa, em tratamento, finalizados), lista e
/// cadastro dos casos com o historico.
class AlignersPage extends ConsumerWidget {
  const AlignersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.aligners))) {
      return const AppShell(
        section: AppSection.aligners,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.aligners));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.aligners));
    final status = ref.watch(alignerStatusFilterProvider);
    final async = ref.watch(alignerListProvider);
    final d = async.valueOrNull;
    return AppShell(
      section: AppSection.aligners,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppPageHeader(
            title: Strings.aligners,
            subtitle: Strings.alignersSubtitle,
            actions: [
              if (canCreate)
                AppButton(
                  label: Strings.alignerNew,
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () => AlignerFormDialog.show(context),
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
                    ref.read(alignerStatusFilterProvider.notifier).state = null,
              ),
              for (final s in AlignerStatus.values)
                if (s != AlignerStatus.cancelled)
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
                    label: Text(s.label),
                    selected: status == s,
                    onSelected: (_) =>
                        ref.read(alignerStatusFilterProvider.notifier).state =
                            s,
                  ),
              ChoiceChip(
                label: const Text(Strings.alignerCancelled),
                selected: status == AlignerStatus.cancelled,
                onSelected: (_) =>
                    ref.read(alignerStatusFilterProvider.notifier).state =
                        AlignerStatus.cancelled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 420,
            child: AppTextField(
              label: Strings.alignerSearch,
              prefixIcon: Icons.search_rounded,
              onChanged: (v) =>
                  ref.read(alignerSearchProvider.notifier).state = v.trim(),
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
              onRetry: () => ref.invalidate(alignerListProvider),
            ),
            data: (data) => data.cases.isEmpty
                ? const AppEmptyState(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    title: Strings.alignerEmpty,
                  )
                : Column(
                    children: [
                      for (final c in data.cases)
                        _CaseCard(
                          item: c,
                          onTap: canUpdate
                              ? () => AlignerFormDialog.show(context, item: c)
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

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, this.onTap});

  final AlignerCase item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = item;
    final color = _statusColor(c.status);
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
                      c.vcPatient,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      c.status.label,
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
                  c.vcSystem,
                  if ((c.vcCaseNumber ?? '').isNotEmpty)
                    '${Strings.alignerCaseNumberShort} ${c.vcCaseNumber}',
                  if (c.vcProfessional != null) c.vcProfessional!,
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      color: color,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(Strings.alignerProgress(c.qtCurrent, c.qtAligners)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                c.status == AlignerStatus.finished
                    ? Strings.alignerFinishedOn(Dates.format(c.dtFinished))
                    : Strings.alignerDates(
                        Dates.format(c.dtStart),
                        Dates.format(c.dtForecast),
                      ),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (c.status.isPending && (c.vcPending ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    c.vcPending!,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadastro / alteracao do caso, com o historico.
class AlignerFormDialog extends ConsumerStatefulWidget {
  const AlignerFormDialog({super.key, this.item});

  final AlignerCase? item;

  static Future<void> show(BuildContext context, {AlignerCase? item}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlignerFormDialog(item: item),
      );

  @override
  ConsumerState<AlignerFormDialog> createState() => _AlignerFormDialogState();
}

class _AlignerFormDialogState extends ConsumerState<AlignerFormDialog> {
  AlignerCase? get _c => widget.item;
  late int? _nrPatient = _c?.nrPatient;
  late String? _vcPatient = _c?.vcPatient;
  late int? _nrProfessional = _c?.nrProfessional;
  late AlignerStatus _status = _c?.status ?? AlignerStatus.started;
  late final _system = TextEditingController(text: _c?.vcSystem ?? '');
  late final _caseNumber = TextEditingController(text: _c?.vcCaseNumber ?? '');
  late final _aligners = TextEditingController(text: '${_c?.qtAligners ?? 1}');
  late final _current = TextEditingController(text: '${_c?.qtCurrent ?? 0}');
  late final _days = TextEditingController(text: '${_c?.qtDaysChange ?? 14}');
  late final _start = TextEditingController(
    text: Dates.toField(_c?.dtStart ?? DateTime.now()),
  );
  late final _pending = TextEditingController(text: _c?.vcPending ?? '');
  late final _notes = TextEditingController(text: _c?.vcNotes ?? '');
  final _event = TextEditingController();
  TextEditingController? _systemField;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _system,
      _caseNumber,
      _aligners,
      _current,
      _days,
      _start,
      _pending,
      _notes,
      _event,
    ]) {
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

  Future<void> _save() async {
    if (_nrPatient == null) {
      AppSnack.error(context, Strings.choosePatient);
      return;
    }
    final start = Dates.parseField(_start.text);
    if (start == null) {
      AppSnack.error(context, Strings.alignerStartInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(alignerSaveProvider)(_c?.nrCase, {
        'nr_patient': _nrPatient,
        'nr_professional': _nrProfessional,
        'vc_system': (_systemField ?? _system).text.trim(),
        'vc_case_number': _caseNumber.text.trim(),
        'qt_aligners': int.tryParse(_aligners.text.trim()),
        'qt_current': int.tryParse(_current.text.trim()),
        'qt_days_change': int.tryParse(_days.text.trim()),
        'dt_start': Dates.toIso(start),
        'it_status': _status.code,
        'vc_pending': _pending.text.trim(),
        'vc_notes': _notes.text.trim(),
        if (_event.text.trim().isNotEmpty) 'vc_event_text': _event.text.trim(),
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

  Widget _num(String label, TextEditingController c) => Expanded(
    child: AppTextField(
      label: label,
      controller: c,
      enabled: !_saving,
      keyboardType: TextInputType.number,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final professionals =
        ref.watch(agendaProfessionalsProvider).valueOrNull ?? const [];
    return AlertDialog(
      title: Text(_c == null ? Strings.alignerNew : Strings.alignerEdit),
      content: SizedBox(
        width: 620,
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
                onTap: _saving || _c != null ? null : _pickPatient,
              ),
              DropdownButtonFormField<int?>(
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
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _system.text),
                      optionsBuilder: (v) => alignerSystems.where(
                        (s) => s.toLowerCase().contains(v.text.toLowerCase()),
                      ),
                      onSelected: (v) => _system.text = v,
                      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                        _systemField = ctrl;
                        return TextField(
                          controller: ctrl,
                          focusNode: focus,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: Strings.alignerSystem,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: Strings.alignerCaseNumber,
                      controller: _caseNumber,
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _num(Strings.alignerQty, _aligners),
                  const SizedBox(width: AppSpacing.sm),
                  _num(Strings.alignerCurrent, _current),
                  const SizedBox(width: AppSpacing.sm),
                  _num(Strings.alignerDays, _days),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.alignerStart,
                      controller: _start,
                      enabled: !_saving,
                      hint: 'dd/mm/aaaa',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AlignerStatus>(
                isExpanded: true,
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: Strings.alignerStatus,
                ),
                items: [
                  for (final s in AlignerStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _status = v ?? _status),
              ),
              if (_status.isPending) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: Strings.alignerPending,
                  controller: _pending,
                  enabled: !_saving,
                  maxLength: 500,
                ),
              ],
              AppTextField(
                label: Strings.notes,
                controller: _notes,
                enabled: !_saving,
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
              ),
              AppTextField(
                label: Strings.alignerEventText,
                controller: _event,
                enabled: !_saving,
                maxLength: 500,
              ),
              if ((_c?.events ?? const []).isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Strings.alignerHistory,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final e in _c!.events)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: _statusColor(e.status),
                    ),
                    title: Text(
                      '${e.status.label} · ${Strings.alignerProgress(e.qtCurrent, _c!.qtAligners)}',
                    ),
                    subtitle: Text(
                      [
                        if (e.dhEvent != null) Dates.formatTime(e.dhEvent!),
                        if (e.vcUser != null) e.vcUser!,
                        if ((e.vcText ?? '').isNotEmpty) e.vcText!,
                      ].join(' · '),
                    ),
                  ),
              ],
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
