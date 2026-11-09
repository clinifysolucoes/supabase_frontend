import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../agenda/domain/agenda_models.dart';
import '../../finance/application/finance_controllers.dart';
import '../../finance/data/receipt_pdf.dart';
import '../../finance/domain/finance_models.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/patient_repository.dart';
import '../domain/patient_summary_models.dart';

/// Resumo do paciente para as abas da ficha (uma chamada para as tres).
final patientSummaryProvider = FutureProvider.autoDispose
    .family<PatientSummary, int>((ref, nrPatient) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const PatientSummary();
      return ref
          .read(patientRepositoryProvider)
          .summary(nrCompany: c, nrBranch: b, nrPatient: nrPatient);
    });

class _SummaryLoader extends ConsumerWidget {
  const _SummaryLoader({required this.nrPatient, required this.builder});

  final int nrPatient;
  final Widget Function(BuildContext, WidgetRef, PatientSummary) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(patientSummaryProvider(nrPatient))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState.error(
          message: describeError(e),
          onRetry: () => ref.invalidate(patientSummaryProvider(nrPatient)),
        ),
        data: (s) => builder(context, ref, s),
      );
}

const _noPermission = AppEmptyState(
  icon: Icons.lock_outline_rounded,
  title: Strings.noPermissionTitle,
  subtitle: Strings.noPermissionSubtitle,
);

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

// --- Agendamentos ------------------------------------------------------------

/// Aba Agendamentos: proximas consultas e historico do paciente.
class PatientAppointmentsTab extends StatelessWidget {
  const PatientAppointmentsTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  Widget build(BuildContext context) => _SummaryLoader(
    nrPatient: nrPatient,
    builder: (context, ref, s) {
      final list = s.appointments;
      if (list == null) return _noPermission;
      if (list.isEmpty) {
        return const AppEmptyState(
          icon: Icons.event_outlined,
          title: Strings.noPatientAppointments,
          subtitle: Strings.noPatientAppointmentsHint,
        );
      }
      final now = DateTime.now();
      final next = list.where((a) => a.isUpcoming(now)).toList().reversed;
      final past = list.where((a) => !a.isUpcoming(now)).toList();
      final faltas = past
          .where((a) => a.itStatus == AppointmentStatus.noShow)
          .length;
      return ListView(
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Stat(
                label: Strings.upcomingAppointments,
                value: '${next.length}',
              ),
              _Stat(label: Strings.pastAppointments, value: '${past.length}'),
              _Stat(
                label: Strings.statusNoShow,
                value: '$faltas',
                color: faltas > 0 ? AppColors.danger : null,
              ),
            ],
          ),
          if (next.isNotEmpty) ...[
            const _Title(Strings.upcomingAppointments),
            for (final a in next) _AppointmentTile(a),
          ],
          if (past.isNotEmpty) ...[
            const _Title(Strings.pastAppointments),
            for (final a in past) _AppointmentTile(a),
          ],
        ],
      );
    },
  );
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile(this.a);

  final PatientAppointment a;

  @override
  Widget build(BuildContext context) {
    final color = Color(AppointmentStatus.color(a.itStatus));
    return Card(
      child: ListTile(
        leading: Container(width: 6, height: 40, color: color),
        title: Text(
          '${Dates.formatTime(a.dhStart)} · ${a.vcProfessional ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            ?a.vcProcedure,
            if (a.itOrigin == 2) Strings.onlineOrigin,
            if (a.vcWaReply == 'CONFIRM') Strings.waConfirmedByPatient,
            if (a.vcWaReply == 'RESCHEDULE') Strings.waRescheduleByPatient,
          ].join(' · '),
        ),
        trailing: Chip(
          label: Text(AppointmentStatus.label(a.itStatus)),
          side: BorderSide(color: color),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

// --- Financeiro e Recibos ----------------------------------------------------

/// Aba Financeiro: contas a receber do paciente, totais e recibos emitidos.
class PatientFinanceTab extends StatelessWidget {
  const PatientFinanceTab({super.key, required this.nrPatient});

  final int nrPatient;

  Future<void> _receipt(
    BuildContext context,
    WidgetRef ref,
    int nrEntry,
  ) async {
    try {
      final doc = await ref.read(financeActionsProvider).receiptOf(nrEntry);
      await FileDownload.savePdf(
        name: ReceiptPdf.fileName(doc.receipt),
        bytes: await ReceiptPdf.build(doc),
      );
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) => _SummaryLoader(
    nrPatient: nrPatient,
    builder: (context, ref, s) {
      final f = s.finance;
      if (f == null) return _noPermission;
      final today = DateTime.now();
      return ListView(
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Stat(label: Strings.patientOpen, value: Numbers.money(f.vlOpen)),
              _Stat(
                label: Strings.patientOverdue(f.qtOverdue),
                value: Numbers.money(f.vlOverdue),
                color: f.vlOverdue > 0 ? AppColors.danger : null,
              ),
              _Stat(
                label: Strings.patientPaid,
                value: Numbers.money(f.vlPaid),
                color: AppColors.success,
              ),
            ],
          ),
          const _Title(Strings.patientEntries),
          if (f.entries.isEmpty)
            const Text(
              Strings.noPatientEntries,
              style: TextStyle(color: AppColors.muted),
            ),
          for (final e in f.entries)
            Card(
              child: ListTile(
                leading: Icon(
                  e.isPaid
                      ? Icons.check_circle_rounded
                      : e.isOverdue(today)
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
                  color: e.isPaid
                      ? AppColors.success
                      : e.isOverdue(today)
                      ? AppColors.danger
                      : AppColors.warning,
                ),
                title: Text(e.title),
                subtitle: Text(
                  e.isPaid
                      ? '${Strings.paidOn} ${Dates.format(e.dtPaid)} · ${PaymentMethod.label(e.itPaymentMethod)}'
                      : '${Strings.dueOn} ${Dates.format(e.dtDue)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Numbers.money(e.vlPaid ?? e.vlAmount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (e.nrReceipt != null)
                      IconButton(
                        tooltip:
                            '${Strings.receipt} ${e.vcReceiptNumber ?? ''}',
                        icon: const Icon(Icons.receipt_long_outlined),
                        onPressed: () => _receipt(context, ref, e.nrEntry),
                      ),
                  ],
                ),
              ),
            ),
          const _Title(Strings.receipts),
          if (f.receipts.isEmpty)
            const Text(
              Strings.noPatientReceipts,
              style: TextStyle(color: AppColors.muted),
            ),
          for (final r in f.receipts)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.receipt_long_outlined,
                  color: r.isCancelled ? AppColors.muted : AppColors.primary,
                ),
                title: Text(
                  '${Strings.receipt} ${r.vcNumber}${r.isCancelled ? ' · ${Strings.statusCancelled}' : ''}',
                ),
                subtitle: Text(
                  [Dates.format(r.dtPaid), ?r.vcDescription].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Numbers.money(r.vlAmount)),
                    if (!r.isCancelled)
                      IconButton(
                        tooltip: Strings.downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: () => _receipt(context, ref, r.nrEntry),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

// --- Plano de tratamento -----------------------------------------------------

/// Aba Plano de tratamento: orcamentos aprovados com o progresso de cada item
/// (realizado na evolucao clinica).
class TreatmentPlanTab extends StatelessWidget {
  const TreatmentPlanTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  Widget build(BuildContext context) => _SummaryLoader(
    nrPatient: nrPatient,
    builder: (context, ref, s) {
      final plans = s.plan;
      if (plans == null) return _noPermission;
      if (plans.isEmpty) {
        return const AppEmptyState(
          icon: Icons.fact_check_outlined,
          title: Strings.noTreatmentPlan,
          subtitle: Strings.noTreatmentPlanHint,
        );
      }
      final theme = Theme.of(context);
      return ListView(
        children: [
          for (final p in plans)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.vcTitle ?? Strings.budgetNo(p.nrBudget),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          Strings.planProgress(p.qtDone, p.items.length),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      [
                        Strings.budgetNo(p.nrBudget),
                        Dates.format(p.dtBudget),
                        ?p.vcProfessional,
                        Numbers.money(p.vlTotal),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: p.progress,
                      minHeight: 6,
                      color: AppColors.success,
                      backgroundColor: AppColors.line,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final i in p.items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          i.isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: i.isDone ? AppColors.success : AppColors.muted,
                        ),
                        title: Text(
                          i.vcTooth == null || i.vcTooth!.isEmpty
                              ? i.vcDescription
                              : '${i.vcDescription} · ${Strings.tooth} ${i.vcTooth}',
                        ),
                        subtitle: Text(
                          i.isDone
                              ? '${Strings.doneOn} ${Dates.format(i.dtDone)}'
                              : Strings.toDo,
                        ),
                        trailing: Text(Numbers.money(i.vlTotal)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
