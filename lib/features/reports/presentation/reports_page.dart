import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/report_controllers.dart';
import '../domain/report_models.dart';

/// Tela Relatorios: escolhe o relatorio, o periodo e o profissional;
/// mostra o resumo, o resumo por profissional e as linhas (exporta CSV).
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReadProvider(ScreenCodes.reports))) {
      return const AppShell(
        section: AppSection.reports,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canFinance = ref.watch(canReadProvider(ScreenCodes.finance));
    final q = ref.watch(reportQueryProvider);
    final result = ref.watch(reportProvider);
    return AppShell(
      section: AppSection.reports,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppPageHeader(
            title: Strings.reports,
            subtitle: Strings.reportsSubtitle,
            actions: [
              AppButton(
                label: Strings.reportExport,
                icon: Icons.download_rounded,
                expanded: false,
                variant: AppButtonVariant.secondary,
                onPressed: (result.valueOrNull?.rows.isEmpty ?? true)
                    ? null
                    : () => _export(context, result.requireValue, q),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final k in ReportKind.values)
                if (!k.needsFinance || canFinance)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: q.kind == k,
                    onSelected: (_) =>
                        ref.read(reportQueryProvider.notifier).state = q
                            .copyWith(kind: k),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _Filters(),
          const SizedBox(height: AppSpacing.md),
          result.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(reportProvider),
            ),
            data: (r) => ReportView(result: r),
          ),
        ],
      ),
    );
  }

  static Future<void> _export(
    BuildContext context,
    ReportResult r,
    ReportQuery q,
  ) async {
    try {
      await FileDownload.saveCsv(
        name:
            'relatorio_${r.kind.code}_${ReportRepository.isoDate(q.from)}_'
            '${ReportRepository.isoDate(q.to)}',
        bytes: r.toCsv(),
      );
      if (context.mounted) AppSnack.success(context, Strings.reportExported);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }
}

/// Periodo (atalhos e intervalo livre) e profissional.
class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(reportQueryProvider);
    final set = ref.read(reportQueryProvider.notifier);
    final now = DateTime.now();
    final pros = q.kind.byProfessional
        ? ref.watch(agendaProfessionalsProvider).valueOrNull ?? const []
        : const [];

    void range(DateTime a, DateTime b) =>
        set.state = q.copyWith(from: a, to: b);

    bool isMonth(int add) {
      final a = DateTime(now.year, now.month + add);
      final b = DateTime(now.year, now.month + add + 1, 0);
      return _same(q.from, a) && _same(q.to, b);
    }

    Widget month(String label, int add) => ChoiceChip(
      label: Text(label),
      selected: isMonth(add),
      onSelected: (_) => range(
        DateTime(now.year, now.month + add),
        DateTime(now.year, now.month + add + 1, 0),
      ),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (q.kind == ReportKind.birthdays) ...[
          month(Strings.reportThisMonth, 0),
          month(Strings.reportNextMonth, 1),
        ] else ...[
          month(Strings.reportLastMonth, -1),
          month(Strings.reportThisMonth, 0),
        ],
        ActionChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text('${Dates.format(q.from)} – ${Dates.format(q.to)}'),
          onPressed: () async {
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 2, 12, 31),
              initialDateRange: DateTimeRange(start: q.from, end: q.to),
              locale: const Locale('pt', 'BR'),
            );
            if (r == null) return;
            if (r.end.difference(r.start).inDays > 366) {
              if (context.mounted) {
                AppSnack.error(context, Strings.reportPeriodTooLong);
              }
              return;
            }
            range(r.start, r.end);
          },
        ),
        if (q.kind.byProfessional && pros.isNotEmpty)
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: q.nrProfessional,
              key: ValueKey(q.nrProfessional),
              decoration: const InputDecoration(
                isDense: true,
                labelText: Strings.reportColProfessional,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(Strings.reportAllProfessionals),
                ),
                for (final p in pros)
                  DropdownMenuItem(
                    value: p.nrProfessional,
                    child: Text(p.vcName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => set.state = q.copyWith(nrProfessional: () => v),
            ),
          ),
      ],
    );
  }

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Resumo, resumo por profissional e linhas de um relatorio.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final cols = reportColumns(r.kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [for (final k in _kpis(r)) _Kpi(k.$1, k.$2)],
        ),
        if (r.byProfessional.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            Strings.reportByProfessional,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Table(columns: _profColumns(r.kind), rows: r.byProfessional),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (r.rows.isEmpty)
          const AppEmptyState(
            icon: Icons.insert_chart_outlined_rounded,
            title: Strings.reportEmpty,
          )
        else ...[
          if (r.idTruncated)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                Strings.reportTruncated(r.rows.length, r.qtRows),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          _Table(columns: cols, rows: r.rows),
        ],
      ],
    );
  }

  static List<(String, String)> _kpis(ReportResult r) => switch (r.kind) {
    ReportKind.noShow => [
      (Strings.reportKpiAppointments, '${r.qt('qt_total')}'),
      (Strings.reportKpiNoShow, '${r.qt('qt_no_show')}'),
      (Strings.reportKpiCancelled, '${r.qt('qt_cancelled')}'),
      (Strings.reportKpiNoShowRate, Numbers.percent(r.vl('pc_no_show'))),
    ],
    ReportKind.birthdays => [
      (Strings.reportKpiPatients, '${r.qt('qt_patients')}'),
    ],
    ReportKind.procedures => [
      (Strings.reportKpiProcedures, '${r.qt('qt_procedures')}'),
      (Strings.reportKpiValue, Numbers.money(r.vl('vl_total'))),
    ],
    ReportKind.commissions => [
      (Strings.reportKpiTotal, Numbers.money(r.vl('vl_total'))),
      (Strings.reportPaid, Numbers.money(r.vl('vl_paid'))),
      (Strings.reportOpen, Numbers.money(r.vl('vl_open'))),
    ],
  };

  static List<ReportColumn> _profColumns(ReportKind kind) {
    String q(Object? v) => '${(v as num?)?.toInt() ?? 0}';
    String m(Object? v) => Numbers.money((v as num?) ?? 0);
    final name = ReportColumn(
      Strings.reportColProfessional,
      (r) => r['vc_professional']?.toString() ?? Strings.reportNoProfessional,
    );
    return switch (kind) {
      ReportKind.noShow => [
        name,
        ReportColumn(
          Strings.reportKpiAppointments,
          (r) => q(r['qt_total']),
          numeric: true,
        ),
        ReportColumn(
          Strings.reportKpiNoShow,
          (r) => q(r['qt_no_show']),
          numeric: true,
        ),
        ReportColumn(
          Strings.reportKpiCancelled,
          (r) => q(r['qt_cancelled']),
          numeric: true,
        ),
      ],
      ReportKind.procedures => [
        name,
        ReportColumn(
          Strings.reportKpiProcedures,
          (r) => q(r['qt_procedures']),
          numeric: true,
        ),
        ReportColumn(
          Strings.reportKpiValue,
          (r) => m(r['vl_total']),
          numeric: true,
        ),
      ],
      ReportKind.commissions => [
        name,
        ReportColumn(
          Strings.reportKpiTotal,
          (r) => m(r['vl_total']),
          numeric: true,
        ),
        ReportColumn(Strings.reportPaid, (r) => m(r['vl_paid']), numeric: true),
        ReportColumn(Strings.reportOpen, (r) => m(r['vl_open']), numeric: true),
      ],
      ReportKind.birthdays => [name],
    };
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});

  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 48,
        columns: [
          for (final c in columns)
            DataColumn(label: Text(c.title), numeric: c.numeric),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [for (final c in columns) DataCell(Text(c.text(r)))],
            ),
        ],
      ),
    ),
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

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
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
