import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../budgets/presentation/budgets_page.dart';
import '../../clinical_record/presentation/anamnesis_tab.dart';
import '../../clinical_record/presentation/evolution_tab.dart';
import '../../clinical_record/presentation/odontogram_tab.dart';
import '../../clinical_record/presentation/record_common.dart';
import '../../documents/presentation/documents_tab.dart';
import '../../patient_files/domain/patient_file_models.dart';
import '../../patient_files/presentation/patient_files_tab.dart';
import '../../clinical_record/application/clinical_record_controllers.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/patients_controllers.dart';
import '../domain/patient_models.dart';
import 'patient_form_dialog.dart';
import 'patient_summary_tabs.dart';
import 'patient_widgets.dart';

/// Ficha do paciente: cabecalho (avatar, nome, CPF, idade, situacao, acoes),
/// abas (Visao geral + modulos futuros) e, na Visao geral, o card
/// "Informacoes do paciente" (Cadastro / Contato / Complemento) ao lado dos
/// cards Proximo agendamento, Anamnese, Alerta de retorno, Orcamentos em
/// aberto e Notas gerais.
class PatientRecordPage extends ConsumerStatefulWidget {
  const PatientRecordPage({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  ConsumerState<PatientRecordPage> createState() => _PatientRecordPageState();
}

class _PatientRecordPageState extends ConsumerState<PatientRecordPage> {
  static const _tabs = [
    Strings.tabOverview,
    Strings.tabAppointments,
    Strings.tabBudgets,
    Strings.tabTreatmentPlan,
    Strings.tabFinance,
    Strings.tabAnamnesis,
    Strings.tabEvolution,
    Strings.tabOdontogram,
    Strings.tabPhotos,
    Strings.tabDocuments,
    Strings.tabExams,
  ];

  int _section = 0;

  PatientRecordController get _controller =>
      ref.read(patientRecordProvider(widget.nrPatient).notifier);

  Future<void> _edit(Patient p, {int tab = 0}) async {
    final saved = await PatientFormDialog.show(
      context,
      patient: p,
      initialTab: tab,
    );
    if (saved != null && mounted) {
      AppSnack.success(context, Strings.savedSuccess);
    }
  }

  Future<void> _toggleActive(Patient p) async {
    if (p.isActive) {
      final ok = await AppConfirmDialog.show(
        context,
        title: Strings.inactivatePatient,
        message: Strings.inactivateConfirm,
        confirmLabel: Strings.inactivatePatient,
      );
      if (!ok) return;
    }
    await _run(
      () => _controller.setActive(!p.isActive),
      p.isActive ? Strings.patientInactivated : Strings.patientReactivated,
    );
  }

  Future<void> _editAlert(Patient p) async {
    final result = await _ReturnAlertDialog.show(context, patient: p);
    if (result == null) return;
    await _run(() => _controller.save(result), Strings.returnAlertSaved);
  }

  Future<void> _removeAlert() async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.removeReturnAlert,
      message: Strings.returnAlert,
      confirmLabel: Strings.remove,
    );
    if (!ok) return;
    await _run(
      () =>
          _controller.save({'dt_return_alert': null, 'vc_return_alert': null}),
      Strings.returnAlertRemoved,
    );
  }

  Future<void> _addNote() async {
    final text = await _NoteDialog.show(context);
    if (text == null) return;
    await _run(() => _controller.addNote(text), Strings.noteAdded);
  }

  Future<void> _deleteNote(PatientNote n) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.deleteNote,
      message: Strings.deleteNoteConfirm,
      confirmLabel: Strings.remove,
    );
    if (!ok) return;
    await _run(() => _controller.deleteNote(n.nrNote), Strings.noteDeleted);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) AppSnack.success(context, success);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRead = ref.watch(canReadProvider(ScreenCodes.patients));
    if (!canRead) {
      return const AppShell(
        section: AppSection.patients,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.patients));
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.patients));
    final async = ref.watch(patientRecordProvider(widget.nrPatient));

    return AppShell(
      section: AppSection.patients,
      title: Strings.patients,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState.error(
          message: describeError(e),
          onRetry: () =>
              ref.invalidate(patientRecordProvider(widget.nrPatient)),
        ),
        data: (record) {
          if (record == null) {
            return AppEmptyState(
              icon: Icons.person_off_outlined,
              title: Strings.patientNotFound,
              actionLabel: Strings.backToPatients,
              onAction: () => context.go(AppRoutes.patients),
            );
          }
          final p = record.patient;
          return DefaultTabController(
            length: _tabs.length,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go(AppRoutes.patients),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text(Strings.backToPatients),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Header(
                    patient: p,
                    canUpdate: canUpdate,
                    onEdit: () => _edit(p, tab: _section),
                    onToggleActive: () => _toggleActive(p),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TabStrip(tabs: _tabs),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Overview(
                          record: record,
                          section: _section,
                          onSection: (i) => setState(() => _section = i),
                          canUpdate: canUpdate,
                          canNote: canUpdate || canCreate,
                          onEdit: (tab) => _edit(p, tab: tab),
                          onEditAlert: () => _editAlert(p),
                          onRemoveAlert: _removeAlert,
                          onAddNote: _addNote,
                          onDeleteNote: _deleteNote,
                        ),
                        PatientAppointmentsTab(nrPatient: p.nrPatient),
                        ref.watch(canReadProvider(ScreenCodes.budgets))
                            ? BudgetList(
                                nrPatient: p.nrPatient,
                                vcPatient: p.vcName,
                              )
                            : const AppEmptyState(
                                icon: Icons.lock_outline_rounded,
                                title: Strings.noPermissionTitle,
                                subtitle: Strings.noPermissionSubtitle,
                              ),
                        TreatmentPlanTab(nrPatient: p.nrPatient),
                        PatientFinanceTab(nrPatient: p.nrPatient),
                        AnamnesisTab(nrPatient: p.nrPatient),
                        EvolutionTab(nrPatient: p.nrPatient),
                        OdontogramTab(nrPatient: p.nrPatient),
                        PatientFilesTab(
                          nrPatient: p.nrPatient,
                          type: PatientFileType.photo,
                        ),
                        DocumentsTab(nrPatient: p.nrPatient),
                        PatientFilesTab(
                          nrPatient: p.nrPatient,
                          type: PatientFileType.exam,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- cabecalho ----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.patient,
    required this.canUpdate,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Patient patient;
  final bool canUpdate;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = patient;
    final isMobile = context.isMobile;

    final meta = Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Meta(
          icon: Icons.badge_outlined,
          text: p.vcCpf == null ? Strings.cpfNotInformed : p.cpfFormatted,
        ),
        if (p.dtBirth != null)
          _Meta(
            icon: Icons.cake_outlined,
            text: p.age == null
                ? Dates.format(p.dtBirth)
                : '${Dates.format(p.dtBirth)} · ${Strings.yearsOld(p.age!)}',
          ),
        if (p.vcMobile != null)
          _Meta(icon: Icons.phone_android_rounded, text: p.mobileFormatted),
        if (p.vcRecordNumber != null)
          _Meta(
            icon: Icons.folder_shared_outlined,
            text: '${Strings.recordNumber} ${p.vcRecordNumber}',
          ),
        if (p.isMinor)
          const AppTagChip(
            icon: Icons.child_care_rounded,
            label: Strings.minorTag,
            highlighted: true,
          ),
      ],
    );

    final actions = [
      if (canUpdate)
        AppButton(
          label: Strings.edit,
          icon: Icons.edit_outlined,
          variant: AppButtonVariant.secondary,
          expanded: false,
          onPressed: onEdit,
        ),
      if (canUpdate)
        PopupMenuButton<String>(
          tooltip: Strings.actions,
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (_) => onToggleActive(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'status',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  p.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_outlined,
                  color: p.isActive ? AppColors.danger : AppColors.success,
                ),
                title: Text(
                  p.isActive
                      ? Strings.inactivatePatient
                      : Strings.reactivatePatient,
                ),
              ),
            ),
          ],
        ),
    ];

    final nameRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            p.vcName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppStatusChip(status: p.itStatus, compact: true),
      ],
    );

    final subtitle = p.vcNickname == null
        ? null
        : Text(
            p.vcNickname!,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PatientAvatar(patient: p, size: 56),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [nameRow, if (subtitle != null) subtitle],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  meta,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PatientAvatar(patient: p, size: 72),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameRow,
                        if (subtitle != null) subtitle,
                        const SizedBox(height: AppSpacing.sm),
                        meta,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ...actions,
                ],
              ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

/// Abas da ficha (mesmo visual da Precificacao).
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.line),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.muted,
          labelStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          tabs: [
            for (final t in tabs)
              SizedBox(height: 44, child: Center(child: Text(t))),
          ],
        ),
      ),
    );
  }
}

// --- visao geral ----------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview({
    required this.record,
    required this.section,
    required this.onSection,
    required this.canUpdate,
    required this.canNote,
    required this.onEdit,
    required this.onEditAlert,
    required this.onRemoveAlert,
    required this.onAddNote,
    required this.onDeleteNote,
  });

  final PatientRecord record;
  final int section;
  final ValueChanged<int> onSection;
  final bool canUpdate;
  final bool canNote;
  final ValueChanged<int> onEdit;
  final VoidCallback onEditAlert;
  final VoidCallback onRemoveAlert;
  final VoidCallback onAddNote;
  final ValueChanged<PatientNote> onDeleteNote;

  @override
  Widget build(BuildContext context) {
    final p = record.patient;
    final info = _InfoCard(
      patient: p,
      section: section,
      onSection: onSection,
      onEdit: canUpdate ? () => onEdit(section) : null,
    );
    final side = [
      _SideCard(
        title: Strings.nextAppointment,
        child: const _EmptyHint(
          icon: Icons.event_busy_rounded,
          title: Strings.noNextAppointment,
          hint: Strings.noNextAppointmentHint,
        ),
      ),
      _SideCard(
        title: Strings.tabAnamnesis,
        child: Consumer(
          builder: (context, ref, _) {
            final r = ref
                .watch(clinicalRecordProvider(record.patient.nrPatient))
                .valueOrNull;
            final last = r?.anamneses.firstOrNull;
            if (last == null) {
              return const _EmptyHint(
                icon: Icons.assignment_outlined,
                title: Strings.noAnamnesis,
                hint: Strings.noAnamnesisHint,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${last.vcModel} · ${Dates.format(last.dtFilled)}'),
                const SizedBox(height: AppSpacing.xs),
                RecordAlerts(alerts: r!.alerts),
              ],
            );
          },
        ),
      ),
      _SideCard(
        title: Strings.returnAlert,
        action: canUpdate
            ? AppButton(
                label: p.hasReturnAlert
                    ? Strings.editReturnAlert
                    : Strings.newReturnAlert,
                icon: Icons.notification_add_outlined,
                variant: AppButtonVariant.text,
                expanded: false,
                onPressed: onEditAlert,
              )
            : null,
        child: p.hasReturnAlert
            ? _AlertContent(
                patient: p,
                onRemove: canUpdate ? onRemoveAlert : null,
              )
            : const _EmptyHint(
                icon: Icons.notifications_none_rounded,
                title: Strings.noReturnAlert,
                hint: Strings.noReturnAlertHint,
              ),
      ),
      _SideCard(
        title: Strings.openBudgets,
        child: const _EmptyHint(
          icon: Icons.request_quote_outlined,
          title: Strings.noOpenBudgets,
          hint: Strings.noOpenBudgetsHint,
        ),
      ),
      _SideCard(
        title: Strings.generalNotes,
        action: canNote
            ? AppButton(
                label: Strings.addNote,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.text,
                expanded: false,
                onPressed: onAddNote,
              )
            : null,
        child: record.notes.isEmpty
            ? const _EmptyHint(
                icon: Icons.sticky_note_2_outlined,
                title: Strings.noNotes,
                hint: Strings.noNotesHint,
              )
            : _NotesList(
                notes: record.notes,
                onDelete: canUpdate ? onDeleteNote : null,
              ),
      ),
    ];

    return SingleChildScrollView(
      child: ResponsiveBuilder(
        mobile: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info,
            for (final c in side) ...[const SizedBox(height: AppSpacing.md), c],
          ],
        ),
        desktop: (_) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: info),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < side.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    side[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card "Informacoes do paciente" com as secoes Cadastro / Contato / Complemento.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.patient,
    required this.section,
    required this.onSection,
    this.onEdit,
  });

  final Patient patient;
  final int section;
  final ValueChanged<int> onSection;
  final VoidCallback? onEdit;

  static const _sections = [
    Strings.sectionRegistration,
    Strings.sectionContact,
    Strings.sectionComplement,
  ];

  List<(String, String?)> _rows() {
    final p = patient;
    String? phone(String col) {
      final v = p.text(col);
      return v == null ? null : Masks.format(MaskType.phone, v);
    }

    String? cpf(String col) {
      final v = p.text(col);
      return v == null ? null : Masks.format(MaskType.cpf, v);
    }

    return switch (section) {
      0 => [
        (
          Strings.birthDate,
          p.dtBirth == null
              ? null
              : p.age == null
              ? Dates.format(p.dtBirth)
              : '${Dates.format(p.dtBirth)} (${Strings.yearsOld(p.age!)})',
        ),
        (Strings.cpf, p.vcCpf == null ? null : p.cpfFormatted),
        (Strings.rg, p.text('vc_rg')),
        (Strings.gender, p.itGender == null ? null : Gender.label(p.itGender)),
        (
          Strings.maritalStatus,
          p.code('it_marital_status') == null
              ? null
              : MaritalStatus.label(p.code('it_marital_status')),
        ),
        (
          Strings.education,
          p.code('it_education') == null
              ? null
              : Education.label(p.code('it_education')),
        ),
        (Strings.howFound, p.itSource == null ? null : p.sourceLabel),
        (Strings.recordNumber, p.vcRecordNumber),
        (Strings.registeredAt, Dates.formatTime(p.dhCreated)),
        (Strings.observations, p.text('vc_notes')),
      ],
      1 => [
        (Strings.mobileWhatsapp, phone('vc_mobile')),
        (Strings.landline, phone('vc_phone')),
        (Strings.otherPhone, phone('vc_phone_other')),
        (Strings.contactName, p.text('vc_contact_name')),
        (Strings.email, p.idNoEmail ? Strings.noEmail : p.vcEmail),
        (
          Strings.zip,
          p.text('vc_zip') == null
              ? null
              : Masks.format(MaskType.cep, p.text('vc_zip')!),
        ),
        (
          Strings.street,
          [
                p.text('vc_address'),
                p.text('vc_address_number'),
              ].whereType<String>().join(', ').trim().isEmpty
              ? null
              : [
                  p.text('vc_address'),
                  p.text('vc_address_number'),
                ].whereType<String>().join(', '),
        ),
        (Strings.addressComplement, p.text('vc_address_complement')),
        (Strings.district, p.text('vc_district')),
        (
          Strings.city,
          [
                p.text('vc_city'),
                p.text('vc_state'),
              ].whereType<String>().join(' - ').trim().isEmpty
              ? null
              : [
                  p.text('vc_city'),
                  p.text('vc_state'),
                ].whereType<String>().join(' - '),
        ),
      ],
      _ => [
        (Strings.profession, p.text('vc_profession')),
        (Strings.workplace, p.text('vc_workplace')),
        (Strings.workTime, p.text('vc_work_time')),
        (Strings.planName, p.text('vc_plan_name')),
        (Strings.planNumber, p.text('vc_plan_number')),
        (Strings.fatherName, p.text('vc_father_name')),
        (Strings.fatherCpf, cpf('vc_father_cpf')),
        (Strings.fatherRg, p.text('vc_father_rg')),
        (Strings.fatherProfession, p.text('vc_father_profession')),
        (Strings.motherName, p.text('vc_mother_name')),
        (Strings.motherCpf, cpf('vc_mother_cpf')),
        (Strings.motherRg, p.text('vc_mother_rg')),
        (Strings.motherProfession, p.text('vc_mother_profession')),
        (
          '${Strings.legalGuardian}: ${Strings.name}',
          p.text('vc_guardian_name'),
        ),
        ('${Strings.legalGuardian}: ${Strings.cpf}', cpf('vc_guardian_cpf')),
        ('${Strings.legalGuardian}: ${Strings.rg}', p.text('vc_guardian_rg')),
        (
          '${Strings.legalGuardian}: ${Strings.phone}',
          phone('vc_guardian_phone'),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _rows();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.patientInfo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < _sections.length; i++)
                  ChoiceChip(
                    label: Text(_sections[i]),
                    selected: section == i,
                    onSelected: (_) => onSection(i),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, value) in rows)
              _InfoRow(label: label, value: value),
            if (onEdit != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: Strings.edit,
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: onEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '-',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: value == null ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// "Sem X" com icone, no estilo dos cards da ficha.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertContent extends StatelessWidget {
  const _AlertContent({required this.patient, this.onRemove});

  final Patient patient;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = !patient.dtReturnAlert!.isAfter(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: due ? AppColors.goldPale : AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            due ? Icons.notifications_active_rounded : Icons.event_rounded,
            color: due ? AppColors.goldDark : AppColors.primaryDark,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Dates.format(patient.dtReturnAlert),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (patient.vcReturnAlert != null)
                  Text(
                    patient.vcReturnAlert!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: Strings.removeReturnAlert,
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({required this.notes, this.onDelete});

  final List<PatientNote> notes;
  final ValueChanged<PatientNote>? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notes[i].vcNote, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${notes[i].vcUser} · ${Dates.formatTime(notes[i].dhNote)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: Strings.deleteNote,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        onPressed: () => onDelete!(notes[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// --- dialogos ----------------------------------------------------------------

/// Nova nota. Devolve o texto ou null.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const _NoteDialog());

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.addNote),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AppTextField(
            label: Strings.noteText,
            hint: Strings.noteHint,
            controller: _text,
            maxLines: 5,
            minLines: 3,
            maxLength: 4000,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            validator: Validators.required(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text(Strings.save)),
      ],
    );
  }
}

/// Alerta de retorno: data + motivo. Devolve as duas colunas prontas para
/// patient_save ou null.
class _ReturnAlertDialog extends StatefulWidget {
  const _ReturnAlertDialog({required this.patient});

  final Patient patient;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Patient patient,
  }) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _ReturnAlertDialog(patient: patient),
  );

  @override
  State<_ReturnAlertDialog> createState() => _ReturnAlertDialogState();
}

class _ReturnAlertDialogState extends State<_ReturnAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _date = TextEditingController(
    text: Dates.toField(widget.patient.dtReturnAlert),
  );
  late final _reason = TextEditingController(
    text: widget.patient.vcReturnAlert ?? '',
  );

  @override
  void dispose() {
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = Dates.parseField(_date.text);
    if (date == null) return;
    Navigator.of(context).pop({
      'dt_return_alert': Dates.toIso(date),
      'vc_return_alert': _reason.text.trim().isEmpty
          ? null
          : _reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.patient.hasReturnAlert
            ? Strings.editReturnAlert
            : Strings.newReturnAlert,
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: '${Strings.returnAlertDate} *',
                hint: Strings.dateHint,
                controller: _date,
                mask: MaskType.date,
                prefixIcon: Icons.event_rounded,
                autofocus: true,
                validator: Validators.compose([
                  Validators.required(),
                  Validators.date(),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.returnAlertReason,
                hint: Strings.returnAlertReasonHint,
                controller: _reason,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text(Strings.save)),
      ],
    );
  }
}
