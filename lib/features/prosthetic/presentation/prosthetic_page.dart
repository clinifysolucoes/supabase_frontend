import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/prosthetic_controllers.dart';
import '../domain/prosthetic_models.dart';
import 'prosthetic_dialogs.dart';

/// Tela Controle Protetico: trabalhos enviados ao laboratorio, etapas,
/// atrasos e o recebimento (que gera a conta a pagar do laboratorio).
class ProstheticPage extends ConsumerWidget {
  const ProstheticPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.prosthetic))) {
      return const AppShell(
        section: AppSection.prosthetic,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.prosthetic));
    final filter = ref.watch(prostheticFilterProvider);
    final data = ref.watch(prostheticListProvider);
    final d = data.valueOrNull;
    return AppShell(
      section: AppSection.prosthetic,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppPageHeader(
            title: Strings.prosthetic,
            subtitle: Strings.prostheticSubtitle,
            actions: [
              if (canCreate)
                AppButton(
                  label: Strings.prosNew,
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () =>
                      ProstheticFormDialog.show(context, labs: d?.labs ?? []),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (d != null)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Total(ProstheticStage.toSend, d.qtToSend),
                _Total(ProstheticStage.atLab, d.qtAtLab),
                _Total(ProstheticStage.trial, d.qtTrial),
                _Total(ProstheticStage.received, d.qtReady),
                if (d.qtLate > 0) _Total(null, d.qtLate),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: AppTextField(
                  label: Strings.prosSearch,
                  prefixIcon: Icons.search_rounded,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (v) =>
                      ref.read(prostheticSearchProvider.notifier).state = v
                          .trim(),
                ),
              ),
              for (final f in ProstheticFilter.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: filter == f,
                  onSelected: (_) =>
                      ref.read(prostheticFilterProvider.notifier).state = f,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(prostheticListProvider),
            ),
            data: (d) => d.works.isEmpty
                ? const AppEmptyState(
                    icon: Icons.precision_manufacturing_outlined,
                    title: Strings.prosEmpty,
                    subtitle: Strings.prosEmptySubtitle,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final w in d.works)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ProstheticCard(work: w, labs: d.labs),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.stage, this.qt);

  /// null = atrasados.
  final int? stage;
  final int qt;

  @override
  Widget build(BuildContext context) {
    final s = stage;
    final color = s == null ? AppColors.danger : ProstheticStage.color(s);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              s == null ? Icons.schedule_rounded : ProstheticStage.icon(s),
              color: color,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s == null ? Strings.prosLate : ProstheticStage.label(s),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  '$qt',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: s == null ? color : AppColors.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Um trabalho: dados, etapa, prazos, acoes e o historico.
class ProstheticCard extends ConsumerWidget {
  const ProstheticCard({super.key, required this.work, required this.labs});

  final ProstheticWork work;
  final List<({int id, String name})> labs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = work;
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.prosthetic));
    final color = ProstheticStage.color(w.itStage);
    final info = [
      if ((w.vcTooth ?? '').isNotEmpty) '${Strings.prosTooth} ${w.vcTooth}',
      if ((w.vcShade ?? '').isNotEmpty) '${Strings.prosShade} ${w.vcShade}',
      if ((w.vcLab ?? '').isNotEmpty) w.vcLab!,
      if ((w.vcProfessional ?? '').isNotEmpty) w.vcProfessional!,
      if (w.vlCost != null) Numbers.money(w.vlCost),
    ].join(' · ');
    final dates = [
      if (w.dtSent != null) '${Strings.prosSentOn} ${Dates.format(w.dtSent)}',
      if (w.dtExpected != null &&
          (w.itStage == ProstheticStage.toSend ||
              w.itStage == ProstheticStage.atLab))
        '${Strings.prosExpectedOn} ${Dates.format(w.dtExpected)}',
      if (w.dtReceived != null)
        '${Strings.prosReceivedOn} ${Dates.format(w.dtReceived)}',
      if (w.dtInstalled != null)
        '${Strings.prosInstalledOn} ${Dates.format(w.dtInstalled)}',
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: w.idLate ? AppColors.danger : AppColors.line,
          width: w.idLate ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(ProstheticStage.icon(w.itStage), color: color),
          ),
          title: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                w.vcDescription,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _Badge(ProstheticStage.label(w.itStage), color),
              if (w.idLate) const _Badge(Strings.prosLate, AppColors.danger),
              if (w.nrEntry != null)
                const _Badge(Strings.prosPayableBadge, AppColors.primaryDark),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.vcPatient),
              if (info.isNotEmpty)
                Text(info, style: const TextStyle(color: AppColors.muted)),
              if (dates.isNotEmpty)
                Text(
                  dates,
                  style: TextStyle(
                    color: w.idLate ? AppColors.danger : AppColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          trailing: canUpdate && !w.isClosed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: Strings.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => ProstheticFormDialog.show(
                        context,
                        work: w,
                        labs: labs,
                      ),
                    ),
                    if (context.isMobile)
                      IconButton(
                        tooltip: Strings.prosStageButton,
                        icon: const Icon(Icons.arrow_circle_right_outlined),
                        onPressed: () => ProstheticStageDialog.show(context, w),
                      )
                    else
                      AppButton(
                        label: Strings.prosStageButton,
                        icon: Icons.arrow_forward_rounded,
                        expanded: false,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => ProstheticStageDialog.show(context, w),
                      ),
                  ],
                )
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((w.vcNotes ?? '').isNotEmpty) ...[
              Text(w.vcNotes!),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              Strings.prosHistory,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final s in w.steps)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ProstheticStage.icon(s.itStage),
                      size: 16,
                      color: ProstheticStage.color(s.itStage),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        [
                          Dates.format(s.dtStep),
                          ProstheticStage.label(s.itStage),
                          if ((s.vcNotes ?? '').isNotEmpty) s.vcNotes!,
                          if ((s.vcUser ?? '').isNotEmpty) s.vcUser!,
                        ].join(' · '),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
