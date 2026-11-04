import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/agenda_controllers.dart';
import '../domain/agenda_models.dart';
import 'professional_form_dialog.dart';

/// Agenda, parte 1: profissionais (colunas da agenda) com cor, intervalo,
/// usuario vinculado e horario de atendimento. A grade de consultas e
/// compromissos usa estes dados.
class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = ref.watch(canReadProvider(ScreenCodes.agenda));
    return AppShell(
      section: AppSection.agenda,
      child: canRead
          ? const AgendaPageBody()
          : const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: Strings.noPermissionTitle,
              subtitle: Strings.noPermissionSubtitle,
            ),
    );
  }
}

/// Conteudo da Agenda (sem a moldura), para reuso e testes.
class AgendaPageBody extends ConsumerWidget {
  const AgendaPageBody({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ProfessionalListData data, [
    Professional? p,
  ]) async {
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.agenda));
    final saved = await ProfessionalFormDialog.show(
      context,
      professional: p,
      users: data.users,
      readOnly: p != null && !canUpdate,
    );
    if (saved && context.mounted) {
      AppSnack.success(context, Strings.savedSuccess);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.agenda));
    final showInactive = ref.watch(professionalShowInactiveProvider);
    final async = ref.watch(professionalsProvider);
    final data = async.valueOrNull;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageHeader(
              title: Strings.agenda,
              subtitle: Strings.agendaSubtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  Strings.professionals,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                FilterChip(
                  label: const Text(Strings.showInactive),
                  selected: showInactive,
                  onSelected: (v) =>
                      ref
                              .read(professionalShowInactiveProvider.notifier)
                              .state =
                          v,
                ),
                if (canCreate && data != null)
                  AppButton(
                    label: Strings.newProfessional,
                    icon: Icons.add_rounded,
                    expanded: false,
                    onPressed: () => _open(context, ref, data),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppEmptyState.error(
                  message: describeError(e),
                  onRetry: () => ref.invalidate(professionalsProvider),
                ),
                data: (d) => d.professionals.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.badge_outlined,
                        title: Strings.noProfessionals,
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            for (final p in d.professionals)
                              ProfessionalCard(
                                professional: p,
                                onTap: () => _open(context, ref, d, p),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartao do profissional: cor, nome, conselho, usuario, intervalo e o
/// horario da semana resumido.
class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({
    super.key,
    required this.professional,
    required this.onTap,
  });

  final Professional professional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = professional;
    final theme = Theme.of(context);
    final color = Color(AgendaColors.argb(p.vcColor));
    final hours = p.weeklyHours;
    return SizedBox(
      width: context.isMobile ? double.infinity : 340,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: color.withValues(alpha: 0.16),
                              child: Text(
                                _initials(p.vcName),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.vcName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    [
                                      if (p.vcCouncil != null) p.vcCouncil!,
                                      '${p.qtSlotMinutes} min',
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!p.isActive)
                              AppStatusChip(status: p.itStatus, compact: true),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (p.schedules.isEmpty)
                          const Text(
                            Strings.noWorkingHours,
                            style: TextStyle(color: AppColors.warning),
                          )
                        else ...[
                          for (final day in Weekday.all)
                            if (p.rangesOf(day).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        Weekday.short(day),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        p
                                            .rangesOf(day)
                                            .map(
                                              (r) => DayMinutes.range(
                                                r.qtMinuteStart,
                                                r.qtMinuteEnd,
                                              ),
                                            )
                                            .join(' · '),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Strings.weeklyHours(hours),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (p.vcUserName != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          AppTagChip(
                            label: p.vcUserName!,
                            icon: Icons.link_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(dra?\.?|dr\.?)\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
