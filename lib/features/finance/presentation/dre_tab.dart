import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../settings/data/data_export.dart';
import '../application/finance_controllers.dart';
import '../domain/dre_models.dart';

/// DRE gerencial: um ano (meses nas colunas), por competencia ou por caixa.
class DreTab extends ConsumerWidget {
  const DreTab({super.key});

  static const _monthNames = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', //
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  static String monthLabel(String ym) {
    final p = ym.split('-');
    final m = int.tryParse(p.length > 1 ? p[1] : '') ?? 1;
    return '${_monthNames[(m - 1).clamp(0, 11)]}/${p[0].substring(2)}';
  }

  Future<void> _export(BuildContext context, int year, DreReport r) async {
    final table = ExportTable(
      columns: [
        Strings.dreLine,
        for (final m in r.months) monthLabel(m),
        Strings.dreTotal,
        Strings.drePercent,
      ],
      rows: [
        for (final l in r.lines)
          [
            '${l.isCategory ? '    ' : ''}${l.vcLabel}',
            for (final v in l.values) v,
            l.vlTotal,
            l.pcRevenue,
          ],
      ],
    );
    try {
      await FileDownload.saveXlsx(
        name: 'dre_$year',
        bytes: DataExportXlsx.build(table, sheetName: 'DRE $year'),
      );
      if (context.mounted) AppSnack.success(context, Strings.exportDone);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(dreYearProvider);
    final basis = ref.watch(dreBasisProvider);
    final async = ref.watch(dreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: Strings.drePrevYear,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () =>
                      ref.read(dreYearProvider.notifier).state = year - 1,
                ),
                Text(
                  '$year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  tooltip: Strings.dreNextYear,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () =>
                      ref.read(dreYearProvider.notifier).state = year + 1,
                ),
              ],
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'competence',
                  label: Text(Strings.dreCompetence),
                ),
                ButtonSegment(value: 'cash', label: Text(Strings.dreCash)),
              ],
              selected: {basis},
              onSelectionChanged: (s) =>
                  ref.read(dreBasisProvider.notifier).state = s.first,
            ),
            if (async.valueOrNull != null)
              TextButton.icon(
                onPressed: () => _export(context, year, async.value!),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text(Strings.exportExcel),
              ),
          ],
        ),
        Text(
          basis == 'cash' ? Strings.dreCashHint : Strings.dreCompetenceHint,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(dreProvider),
            ),
            data: (r) =>
                r.line('gross')?.vlTotal == 0 &&
                    (r.line('variable')?.vlTotal ?? 0) == 0 &&
                    (r.line('fixed')?.vlTotal ?? 0) == 0
                ? const AppEmptyState(
                    icon: Icons.analytics_outlined,
                    title: Strings.dreEmpty,
                    subtitle: Strings.dreEmptyHint,
                  )
                : _DreTable(report: r),
          ),
        ),
      ],
    );
  }
}

class _DreTable extends StatelessWidget {
  const _DreTable({required this.report});

  final DreReport report;

  @override
  Widget build(BuildContext context) {
    const labelW = 240.0;
    const cellW = 96.0;
    Widget cell(
      String text, {
      double width = cellW,
      bool bold = false,
      Color? color,
      TextAlign align = TextAlign.right,
    }) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 10,
        ),
        child: Text(
          text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
            color: color,
            fontSize: 13,
          ),
        ),
      ),
    );
    String money(double v) => v == 0 ? '–' : Numbers.money(v);
    Color? tone(DreLine l, double v) {
      if (l.isTotal && v < 0) return AppColors.danger;
      if (l.itSign == 0 || l.isCategory) return AppColors.muted;
      return null;
    }

    final header = Container(
      color: AppColors.surface,
      child: Row(
        children: [
          cell(
            Strings.dreLine,
            width: labelW,
            bold: true,
            align: TextAlign.left,
          ),
          for (final m in report.months) cell(DreTab.monthLabel(m), bold: true),
          cell(Strings.dreTotal, bold: true),
          cell(Strings.drePercent, width: 72, bold: true),
        ],
      ),
    );
    final rows = [
      for (final l in report.lines)
        Container(
          decoration: BoxDecoration(
            color: l.isTotal ? AppColors.mint : null,
            border: const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              cell(
                '${l.isCategory ? '      ' : ''}${l.vcLabel}'
                '${l.idEstimated ? ' *' : ''}',
                width: labelW,
                bold: l.isTotal,
                color: l.isCategory ? AppColors.muted : null,
                align: TextAlign.left,
              ),
              for (final v in l.values)
                cell(money(v), bold: l.isTotal, color: tone(l, v)),
              cell(money(l.vlTotal), bold: true, color: tone(l, l.vlTotal)),
              cell(
                l.pcRevenue == null ? '' : Numbers.percent(l.pcRevenue),
                width: 72,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
    ];
    final hasEstimate = report.lines.any((l) => l.idEstimated);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: labelW + cellW * (report.months.length + 1) + 72,
                child: Column(
                  children: [
                    header,
                    Expanded(child: ListView(children: rows)),
                  ],
                ),
              ),
            ),
          ),
          if (hasEstimate)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Text(
                Strings.dreEstimatedHint,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
