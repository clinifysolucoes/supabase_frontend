import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../patients/domain/patient_models.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/referral_controllers.dart';
import '../domain/referral_models.dart';

/// Tela Indicacoes: quem indicou cada paciente novo, conversao, ranking de
/// quem mais indica, origem dos pacientes e recompensas.
class ReferralsPage extends ConsumerWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.referrals))) {
      return const AppShell(
        section: AppSection.referrals,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final period = ref.watch(referralPeriodProvider);
    final data = ref.watch(referralProvider);
    return AppShell(
      section: AppSection.referrals,
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageHeader(
                    title: Strings.referrals,
                    subtitle: Strings.referralsSubtitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final p in ReferralPeriod.values)
                        ChoiceChip(
                          label: Text(switch (p) {
                            ReferralPeriod.last12 => Strings.refLast12,
                            ReferralPeriod.thisYear => Strings.dashThisYear,
                            ReferralPeriod.lastYear => Strings.refLastYear,
                          }),
                          selected: period == p,
                          onSelected: (_) =>
                              ref.read(referralPeriodProvider.notifier).state =
                                  p,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.valueOrNull case final d?) ReferralTotals(data: d),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: Strings.refTabReferred),
                Tab(text: Strings.refTabRanking),
                Tab(text: Strings.refTabSources),
              ],
            ),
            Expanded(
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppEmptyState.error(
                  message: describeError(e),
                  onRetry: () => ref.invalidate(referralProvider),
                ),
                data: (d) => TabBarView(
                  children: [
                    ReferralListTab(data: d),
                    ReferrerRankingTab(data: d),
                    ReferralSourcesTab(data: d),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class ReferralTotals extends StatelessWidget {
  const ReferralTotals({super.key, required this.data});

  final ReferralData data;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      _Kpi(Strings.dashNewPatients, '${data.qtNew}'),
      _Kpi(Strings.refKpiReferred, '${data.qtReferred}'),
      _Kpi(
        Strings.refKpiConverted,
        '${data.qtConverted} (${Numbers.percent(data.pcConversion)})',
      ),
      _Kpi(
        Strings.refKpiPending,
        '${data.qtPending}',
        color: data.qtPending > 0 ? AppColors.warning : null,
      ),
      _Kpi(
        Strings.refKpiRewards,
        data.vlRewards > 0
            ? '${data.qtRewarded} · ${Numbers.money(data.vlRewards)}'
            : '${data.qtRewarded}',
      ),
    ],
  );
}

/// Pacientes indicados, com conversao e recompensa.
class ReferralListTab extends ConsumerWidget {
  const ReferralListTab({super.key, required this.data});

  final ReferralData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(referralPendingProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: const Text(Strings.refOnlyPending),
            selected: pending,
            onSelected: (v) =>
                ref.read(referralPendingProvider.notifier).state = v,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (data.referrals.isEmpty)
          const AppEmptyState(
            icon: Icons.connect_without_contact_outlined,
            title: Strings.refEmpty,
            subtitle: Strings.refEmptyHint,
          )
        else
          for (final r in data.referrals)
            ReferralCard(referral: r, canUpdate: data.canUpdate),
        if (data.idTruncated)
          const Text(
            Strings.refTruncated,
            style: TextStyle(color: AppColors.muted),
          ),
      ],
    );
  }
}

class ReferralCard extends ConsumerWidget {
  const ReferralCard({
    super.key,
    required this.referral,
    required this.canUpdate,
  });

  final Referral referral;
  final bool canUpdate;

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.refUndoTitle,
      message: Strings.refUndoMessage(referral.vcReferrer),
      confirmLabel: Strings.refUndo,
    );
    if (!ok) return;
    try {
      await ref.read(referralActionsProvider).undo(referral.nrPatient);
      if (context.mounted) AppSnack.success(context, Strings.refUndone);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = referral;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: r.isPending ? AppColors.warning : AppColors.line,
          width: r.isPending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.patient(r.nrPatient)),
                    child: Text(
                      r.vcPatient,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  Text(
                    [
                      Strings.refBy(r.vcReferrer),
                      if (r.dhCreated != null)
                        Strings.refSince(Dates.format(r.dhCreated)),
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  Text(
                    r.idConverted
                        ? r.vlApproved == null
                              ? Strings.refConverted
                              : Strings.refConvertedValue(
                                  Numbers.money(r.vlApproved),
                                )
                        : Strings.refNotConverted,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.idConverted
                          ? AppColors.success
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (r.isRewarded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      [
                        r.vcReward ?? '',
                        if (r.vlReward != null) Numbers.money(r.vlReward),
                        Dates.format(r.dtReward),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canUpdate)
                    IconButton(
                      tooltip: Strings.refUndo,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      onPressed: () => _undo(context, ref),
                    ),
                ],
              )
            else if (canUpdate)
              AppButton(
                label: Strings.refReward,
                icon: Icons.card_giftcard_rounded,
                expanded: false,
                variant: r.isPending
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                onPressed: () => ReferralRewardDialog.show(context, r),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ranking de quem indicou.
class ReferrerRankingTab extends StatelessWidget {
  const ReferrerRankingTab({super.key, required this.data});

  final ReferralData data;

  @override
  Widget build(BuildContext context) {
    if (data.referrers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.emoji_events_outlined,
        title: Strings.refEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('#')),
                const DataColumn(label: Text(Strings.refReferrer)),
                const DataColumn(
                  label: Text(Strings.refKpiReferred),
                  numeric: true,
                ),
                const DataColumn(
                  label: Text(Strings.refKpiConverted),
                  numeric: true,
                ),
                if (data.canBudgets)
                  const DataColumn(
                    label: Text(Strings.refApproved),
                    numeric: true,
                  ),
                if (data.canFinance)
                  const DataColumn(
                    label: Text(Strings.refReceived),
                    numeric: true,
                  ),
                const DataColumn(label: Text(Strings.refRewardsCol)),
              ],
              rows: [
                for (final (i, r) in data.referrers.indexed)
                  DataRow(
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              r.isPatient
                                  ? Icons.person_outline_rounded
                                  : Icons.badge_outlined,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(r.vcReferrer),
                          ],
                        ),
                        onTap: r.nrReferrer == null
                            ? null
                            : () =>
                                  context.go(AppRoutes.patient(r.nrReferrer!)),
                      ),
                      DataCell(Text('${r.qtReferred}')),
                      DataCell(Text('${r.qtConverted}')),
                      if (data.canBudgets)
                        DataCell(Text(Numbers.money(r.vlApproved ?? 0))),
                      if (data.canFinance)
                        DataCell(Text(Numbers.money(r.vlReceived ?? 0))),
                      DataCell(
                        Text(
                          r.qtPending > 0
                              ? Strings.refRewardsPending(
                                  r.qtRewarded,
                                  r.qtPending,
                                )
                              : '${r.qtRewarded}',
                          style: TextStyle(
                            color: r.qtPending > 0 ? AppColors.warning : null,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pacientes novos e convertidos por origem.
class ReferralSourcesTab extends StatelessWidget {
  const ReferralSourcesTab({super.key, required this.data});

  final ReferralData data;

  @override
  Widget build(BuildContext context) {
    final max = data.bySource.fold<int>(0, (m, s) => s.qtNew > m ? s.qtNew : m);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (data.bySource.isEmpty)
          const AppEmptyState(
            icon: Icons.campaign_outlined,
            title: Strings.refNoPatients,
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in data.bySource)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.source == null
                                      ? Strings.dashSourceUnknown
                                      : PatientSource.label(s.source),
                                ),
                              ),
                              Text(
                                Strings.refSourceCount(s.qtNew, s.qtConverted),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          LinearProgressIndicator(
                            value: max == 0 ? 0 : s.qtNew / max,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: AppColors.mint,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Registra o retorno dado a quem indicou.
class ReferralRewardDialog extends ConsumerStatefulWidget {
  const ReferralRewardDialog({super.key, required this.referral});

  final Referral referral;

  static Future<bool?> show(BuildContext context, Referral r) =>
      showDialog<bool>(
        context: context,
        builder: (_) => ReferralRewardDialog(referral: r),
      );

  @override
  ConsumerState<ReferralRewardDialog> createState() =>
      _ReferralRewardDialogState();
}

class _ReferralRewardDialogState extends ConsumerState<ReferralRewardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reward = TextEditingController();
  final _value = TextEditingController();
  final _date = TextEditingController(text: Dates.toField(DateTime.now()));
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_reward, _value, _date]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(referralActionsProvider)
          .reward(
            widget.referral.nrPatient,
            reward: _reward.text.trim(),
            date: Dates.parseField(_date.text),
            value: Numbers.parse(_value.text),
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.refRewarded);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(Strings.refRewardTitle(widget.referral.vcReferrer)),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.refRewardFor(widget.referral.vcPatient),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: '${Strings.refRewardWhat} *',
              hint: Strings.refRewardHint,
              controller: _reward,
              autofocus: true,
              maxLength: 200,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? Strings.refRewardRequired : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: Strings.stockDate,
                    controller: _date,
                    mask: MaskType.date,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final d = Dates.parseField(v);
                      if (d == null) return Strings.invalidDate;
                      return d.isAfter(DateTime.now())
                          ? Strings.prosFutureDate
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: Strings.refRewardValue,
                    controller: _value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = Numbers.parse(v);
                      return n == null || n < 0
                          ? Strings.stockQtyInvalid
                          : null;
                    },
                  ),
                ),
              ],
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
        onPressed: _save,
      ),
    ],
  );
}
