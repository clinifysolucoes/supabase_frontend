import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../patients/domain/patient_models.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_models.dart';

/// Primeira tela depois do login: Dashboard Analitico da filial.
/// Cada bloco so aparece para quem le a tela dele.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider);
    final data = ref.watch(dashboardProvider);
    return AppShell(
      section: AppSection.dashboard,
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState.error(
          message: describeError(e),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => d.isEmpty
            ? const AppEmptyState(
                icon: Icons.insights_rounded,
                title: Strings.dashboardEmptyTitle,
                subtitle: Strings.dashboardEmptySubtitle,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final p in DashboardPeriod.values)
                        ChoiceChip(
                          label: Text(_periodLabel(p)),
                          selected: period == p,
                          onSelected: (_) =>
                              ref.read(dashboardPeriodProvider.notifier).state =
                                  p,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DashboardView(data: d),
                ],
              ),
      ),
    );
  }

  static String _periodLabel(DashboardPeriod p) => switch (p) {
    DashboardPeriod.thisMonth => Strings.reportThisMonth,
    DashboardPeriod.lastMonth => Strings.reportLastMonth,
    DashboardPeriod.thisYear => Strings.dashThisYear,
  };
}

/// Blocos do painel (separado da pagina para testar sem o shell).
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final a = data.agenda, p = data.patients, b = data.budgets;
    final f = data.finance;
    final hasRevenue = data.series.any((m) => m.vlRevenue != null);
    final hasAttended = data.series.any((m) => m.qtAttended != null);
    final hasNew = data.series.any((m) => m.qtNewPatients != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (f != null)
          _Block(
            title: Strings.finance,
            route: AppRoutes.finance,
            cards: [
              _Card(
                Strings.dashRevenue,
                Numbers.money(f.vlRevenue),
                delta: deltaPercent(f.vlRevenue, f.vlRevenuePrev),
              ),
              _Card(Strings.dashExpense, Numbers.money(f.vlExpense)),
              _Card(
                Strings.dashResult,
                Numbers.money(f.vlResult),
                color: f.vlResult < 0 ? AppColors.danger : AppColors.success,
              ),
              _Card(
                Strings.dashOverdue,
                Numbers.money(f.vlOverdue),
                hint: Strings.dashOverdueCount(f.qtOverdue),
                color: f.qtOverdue > 0 ? AppColors.danger : null,
              ),
              _Card(Strings.dashPayableWeek, Numbers.money(f.vlPayableWeek)),
            ],
          ),
        if (a != null)
          _Block(
            title: Strings.agenda,
            route: AppRoutes.agenda,
            cards: [
              _Card(
                Strings.dashToday,
                '${a.qtToday}',
                hint: Strings.dashTodayConfirmed(a.qtTodayConfirmed),
              ),
              _Card(
                Strings.reportKpiAppointments,
                '${a.qtAppointments}',
                delta: deltaPercent(a.qtAppointments, a.qtAppointmentsPrev),
              ),
              _Card(Strings.dashAttended, '${a.qtAttended}'),
              _Card(
                Strings.reportKpiNoShowRate,
                Numbers.percent(a.pcNoShow),
                hint: Strings.dashNoShowHint(a.qtNoShow, a.qtCancelled),
                color: a.pcNoShow >= 15 ? AppColors.warning : null,
              ),
              _Card(Strings.dashOnline, '${a.qtOnline}'),
            ],
          ),
        if (p != null)
          _Block(
            title: Strings.patients,
            route: AppRoutes.patients,
            cards: [
              _Card(
                Strings.dashNewPatients,
                '${p.qtNew}',
                delta: deltaPercent(p.qtNew, p.qtNewPrev),
              ),
              _Card(Strings.dashActivePatients, '${p.qtActive}'),
              _Card(Strings.dashBirthdaysToday, '${p.qtBirthdaysToday}'),
              _Card(Strings.reportKpiProcedures, '${p.qtProcedures}'),
            ],
          ),
        if (b != null)
          _Block(
            title: Strings.budgets,
            route: AppRoutes.budgets,
            cards: [
              _Card(
                Strings.dashBudgetsCreated,
                '${b.qtCreated}',
                hint: Numbers.money(b.vlCreated),
              ),
              _Card(
                Strings.dashBudgetsAccepted,
                '${b.qtAccepted}',
                hint: Numbers.money(b.vlAccepted),
              ),
              _Card(Strings.dashConversion, Numbers.percent(b.pcConversion)),
              _Card(
                Strings.dashBudgetsOpen,
                '${b.qtOpen}',
                hint: Numbers.money(b.vlOpen),
              ),
            ],
          ),
        if (data.series.isNotEmpty && (hasRevenue || hasAttended || hasNew))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                if (hasRevenue)
                  _Chart(
                    title: Strings.dashChartFinance,
                    months: data.series,
                    series: [
                      (
                        Strings.dashRevenue,
                        AppColors.primary,
                        (m) => m.vlRevenue ?? 0,
                      ),
                      (
                        Strings.dashExpense,
                        AppColors.warning,
                        (m) => m.vlExpense ?? 0,
                      ),
                    ],
                    money: true,
                  ),
                if (hasAttended)
                  _Chart(
                    title: Strings.dashChartAttended,
                    months: data.series,
                    series: [
                      (
                        Strings.dashAttended,
                        AppColors.primary,
                        (m) => (m.qtAttended ?? 0).toDouble(),
                      ),
                    ],
                  ),
                if (hasNew)
                  _Chart(
                    title: Strings.dashChartNewPatients,
                    months: data.series,
                    series: [
                      (
                        Strings.dashNewPatients,
                        AppColors.accent,
                        (m) => (m.qtNewPatients ?? 0).toDouble(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (p != null &&
            (p.topProcedures.isNotEmpty || p.bySource.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              if (p.topProcedures.isNotEmpty)
                _Ranking(
                  title: Strings.dashTopProcedures,
                  items: [for (final t in p.topProcedures) (t.name, t.qt)],
                ),
              if (p.bySource.isNotEmpty)
                _Ranking(
                  title: Strings.dashBySource,
                  items: [
                    for (final s in p.bySource)
                      (
                        s.source == null
                            ? Strings.dashSourceUnknown
                            : PatientSource.label(s.source),
                        s.qt,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.route, required this.cards});

  final String title;
  final String route;
  final List<_Card> cards;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: Strings.dashOpen,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              onPressed: () => context.go(route),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: cards,
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value, {this.hint, this.delta, this.color});

  final String label;
  final String value;
  final String? hint;

  /// Variacao contra o periodo anterior (%).
  final double? delta;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    return SizedBox(
      width: 200,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: color ?? AppColors.ink,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              if (d != null)
                Row(
                  children: [
                    Icon(
                      d >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: d >= 0 ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        Strings.dashDelta(Numbers.percent(d.abs())),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: d >= 0 ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Serie = (String, Color, double Function(DashboardMonth));

/// Barras simples por mes (sem biblioteca de graficos).
class _Chart extends StatelessWidget {
  const _Chart({
    required this.title,
    required this.months,
    required this.series,
    this.money = false,
  });

  final String title;
  final List<DashboardMonth> months;
  final List<_Serie> series;
  final bool money;

  static const _height = 140.0;

  @override
  Widget build(BuildContext context) {
    final max = months
        .expand((m) => series.map((s) => s.$3(m)))
        .fold<double>(0, math.max);
    return SizedBox(
      width: 380,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final s in series)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: s.$2),
                        const SizedBox(width: 4),
                        Text(
                          s.$1,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: _height + 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final m in months)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final s in series)
                                  Tooltip(
                                    message:
                                        '${s.$1}: ${money ? Numbers.money(s.$3(m)) : Numbers.integer(s.$3(m))}',
                                    child: Container(
                                      width: series.length > 1 ? 12 : 22,
                                      height: max == 0
                                          ? 2
                                          : math.max(
                                              2,
                                              _height * s.$3(m) / max,
                                            ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: s.$2,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Strings.monthShort(m.month.month),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
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

/// Lista com barra proporcional (procedimentos mais feitos, origem).
class _Ranking extends StatelessWidget {
  const _Ranking({required this.title, required this.items});

  final String title;
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<int>(0, (m, i) => math.max(m, i.$2));
    return SizedBox(
      width: 380,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              i.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${i.$2}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      LinearProgressIndicator(
                        value: max == 0 ? 0 : i.$2 / max,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: AppColors.mint,
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
