import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/pricing_controllers.dart';
import '../domain/pricing_models.dart';
import 'pricing_breakdown.dart';
import 'procedure_form_dialog.dart';
import 'procedures_tab.dart';
import 'specialty_form_dialog.dart';

/// Aba Especialidades: um cartao por especialidade (lucro, quantos
/// procedimentos e quantos precos cobrados estao em alerta) com o botao
/// "Nova especialidade". Ao abrir uma especialidade, lista os procedimentos
/// dela com a situacao do valor cobrado e o botao "Novo procedimento" ja
/// ligado a ela.
class SpecialtiesTab extends ConsumerStatefulWidget {
  const SpecialtiesTab({super.key});

  @override
  ConsumerState<SpecialtiesTab> createState() => _SpecialtiesTabState();
}

/// Cartao virtual dos procedimentos sem especialidade.
const _noSpecialty = -1;

class _SpecialtiesTabState extends ConsumerState<SpecialtiesTab>
    with AutomaticKeepAliveClientMixin {
  /// Especialidade aberta (null = grade de especialidades).
  int? _open;

  @override
  bool get wantKeepAlive => true;

  Future<void> _openSpecialtyForm(double branchProfit, [Specialty? s]) async {
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.pricing));
    final saved = await SpecialtyFormDialog.show(
      context,
      specialty: s,
      branchProfit: branchProfit,
      readOnly: s != null && !canUpdate,
    );
    if (saved && mounted) AppSnack.success(context, Strings.savedSuccess);
  }

  Future<void> _openProcedureForm(
    ProcedureListData data, {
    Procedure? procedure,
    int? specialty,
  }) async {
    final canUpdate = ref.read(canUpdateProvider(ScreenCodes.pricing));
    final saved = await ProcedureFormDialog.show(
      context,
      procedure: procedure,
      params: data.params,
      summary: data.summary,
      readOnly: procedure != null && !canUpdate,
      initialSpecialty: specialty,
    );
    if (saved && mounted) AppSnack.success(context, Strings.savedSuccess);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(specialtiesProvider);
    final procAsync = ref.watch(specialtyProceduresProvider);
    final data = procAsync.valueOrNull;
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.pricing));
    final showInactive = ref.watch(specialtyShowInactiveProvider);
    final branchProfit = data?.params.pcProfit ?? 30;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(specialtiesProvider),
      ),
      data: (specialties) {
        final procedures = data?.procedures ?? const <Procedure>[];
        final orphans = [
          for (final p in procedures)
            if (p.nrSpecialty == null ||
                !specialties.any((s) => s.nrSpecialty == p.nrSpecialty))
              p,
        ];

        if (_open != null) {
          final specialty = _open == _noSpecialty
              ? null
              : specialties.where((s) => s.nrSpecialty == _open).firstOrNull;
          if (_open != _noSpecialty && specialty == null) {
            // especialidade sumiu da lista (inativada): volta para a grade
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => mounted ? setState(() => _open = null) : null,
            );
          } else {
            return _SpecialtyDetail(
              specialty: specialty,
              procedures: specialty == null
                  ? orphans
                  : [
                      for (final p in procedures)
                        if (p.nrSpecialty == specialty.nrSpecialty) p,
                    ],
              loading: procAsync.isLoading,
              branchProfit: branchProfit,
              canCreate: canCreate && data != null,
              onBack: () => setState(() => _open = null),
              onEdit: specialty == null
                  ? null
                  : () => _openSpecialtyForm(branchProfit, specialty),
              onNewProcedure: data == null
                  ? null
                  : () => _openProcedureForm(
                      data,
                      specialty: specialty?.nrSpecialty,
                    ),
              onOpenProcedure: (p) {
                if (data != null) _openProcedureForm(data, procedure: p);
              },
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  Strings.specialtiesHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                FilterChip(
                  label: const Text(Strings.showInactive),
                  selected: showInactive,
                  onSelected: (v) =>
                      ref.read(specialtyShowInactiveProvider.notifier).state =
                          v,
                ),
                if (canCreate)
                  AppButton(
                    label: Strings.newSpecialty,
                    icon: Icons.add_rounded,
                    expanded: false,
                    onPressed: () => _openSpecialtyForm(branchProfit),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: specialties.isEmpty && orphans.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.category_outlined,
                      title: Strings.noSpecialties,
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final s in specialties)
                            _SpecialtyCard(
                              title: s.vcName,
                              profit: s.pcProfit,
                              branchProfit: branchProfit,
                              procedures: [
                                for (final p in procedures)
                                  if (p.nrSpecialty == s.nrSpecialty) p,
                              ],
                              qtProcedures: s.qtProcedures,
                              itStatus: s.itStatus,
                              onTap: () =>
                                  setState(() => _open = s.nrSpecialty),
                            ),
                          if (orphans.isNotEmpty)
                            _SpecialtyCard(
                              title: Strings.proceduresWithoutSpecialty,
                              branchProfit: branchProfit,
                              procedures: orphans,
                              qtProcedures: orphans.length,
                              muted: true,
                              onTap: () => setState(() => _open = _noSpecialty),
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
}

/// Cartao (botao) de uma especialidade na grade.
class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({
    required this.title,
    this.profit,
    required this.branchProfit,
    required this.procedures,
    required this.qtProcedures,
    this.itStatus = 1,
    this.muted = false,
    required this.onTap,
  });

  final String title;
  final double? profit;
  final double branchProfit;
  final List<Procedure> procedures;
  final int qtProcedures;
  final int itStatus;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = context.isMobile ? double.infinity : 300.0;
    int count(int status) =>
        procedures.where((p) => p.priceStatus == status).length;
    final alerts = [
      for (final st in const [
        PriceStatus.belowCost,
        PriceStatus.belowMin,
        PriceStatus.belowSuggested,
      ])
        if (count(st) > 0) (st, count(st)),
    ];
    final checked = procedures.where((p) => p.vlCurrentPrice != null).length;

    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: muted ? AppColors.surface : AppColors.mint,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        muted
                            ? Icons.help_outline_rounded
                            : Icons.category_outlined,
                        color: muted ? AppColors.muted : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (itStatus != 1)
                      AppStatusChip(status: itStatus, compact: true),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  [
                    Strings.proceduresCount(qtProcedures),
                    if (!muted)
                      '${Strings.profit} ${Numbers.percent(profit ?? branchProfit, decimals: 2)}'
                          '${profit == null ? ' (${Strings.branchDefault.toLowerCase()})' : ''}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (alerts.isEmpty)
                  checked == 0
                      ? const SizedBox(height: 22)
                      : const PriceStatusChip(status: PriceStatus.ok)
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final (st, n) in alerts)
                        Tooltip(
                          message: PriceStatus.help(st) ?? '',
                          child: _CountChip(status: st, count: n),
                        ),
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

/// "3 · Abaixo do custo" com a cor da situacao.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.status, required this.count});

  final int status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = priceStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priceStatusIcon(status), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$count · ${PriceStatus.label(status)}',
            style: TextStyle(
              color: Color.alphaBlend(
                Colors.black.withValues(alpha: 0.25),
                color,
              ),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Especialidade aberta: cabecalho (voltar, editar, novo procedimento) e os
/// procedimentos dela com o preco calculado e a situacao do valor cobrado.
class _SpecialtyDetail extends StatelessWidget {
  const _SpecialtyDetail({
    required this.specialty,
    required this.procedures,
    required this.loading,
    required this.branchProfit,
    required this.canCreate,
    required this.onBack,
    required this.onEdit,
    required this.onNewProcedure,
    required this.onOpenProcedure,
  });

  /// null = procedimentos sem especialidade.
  final Specialty? specialty;
  final List<Procedure> procedures;
  final bool loading;
  final double branchProfit;
  final bool canCreate;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onNewProcedure;
  final ValueChanged<Procedure> onOpenProcedure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = specialty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text(Strings.backToSpecialties),
            ),
            Text(
              s?.vcName ?? Strings.proceduresWithoutSpecialty,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (s != null)
              AppTagChip(
                label:
                    '${Strings.profit} ${Numbers.percent(s.pcProfit ?? branchProfit, decimals: 2)}',
                highlighted: s.pcProfit != null,
              ),
            if (onEdit != null)
              IconButton(
                tooltip: Strings.editSpecialty,
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            if (canCreate && (s == null || s.isActive))
              AppButton(
                label: Strings.newProcedure,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: onNewProcedure,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: loading && procedures.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : procedures.isEmpty
              ? const AppEmptyState(
                  icon: Icons.medical_services_outlined,
                  title: Strings.noProceduresInSpecialty,
                )
              : ResponsiveBuilder(
                  mobile: (_) => ProcedureCards(
                    items: procedures,
                    onTap: onOpenProcedure,
                    showSpecialty: false,
                  ),
                  desktop: (_) => ProcedureTable(
                    items: procedures,
                    onTap: onOpenProcedure,
                    showSpecialty: false,
                  ),
                ),
        ),
      ],
    );
  }
}
