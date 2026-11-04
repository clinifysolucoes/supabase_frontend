import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_table.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'finance_widgets.dart';

/// Fluxo de caixa do mes: grafico de entradas/saidas por dia com a linha do
/// saldo projetado, e a tabela dos dias com movimento.
class CashflowTab extends ConsumerWidget {
  const CashflowTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(cashflowMonthProvider);
    final async = ref.watch(cashflowProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MonthSwitcher(
            month: month,
            onChanged: (m) =>
                ref.read(cashflowMonthProvider.notifier).state = m,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState.error(
              message: describeError(e),
              onRetry: () => ref.invalidate(cashflowProvider),
            ),
            data: (c) {
              final last = c.days.isEmpty ? null : c.days.last;
              final active = [
                for (final d in c.days)
                  if (d.hasMovement) d,
              ];
              return ListView(
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      FinKpiCard(
                        label: Strings.finOpeningBalance,
                        value: c.vlOpening,
                      ),
                      FinKpiCard(
                        label: '${Strings.finIn} · ${Strings.finRealized}',
                        value: c.vlIn,
                        color: AppColors.success,
                        caption:
                            '${Strings.finPlanned}: ${Numbers.money(c.vlInPlanned)}',
                      ),
                      FinKpiCard(
                        label: '${Strings.finOut} · ${Strings.finRealized}',
                        value: c.vlOut,
                        color: AppColors.danger,
                        caption:
                            '${Strings.finPlanned}: ${Numbers.money(c.vlOutPlanned)}',
                      ),
                      FinKpiCard(
                        label: Strings.finProjected,
                        value: last?.vlProjected ?? c.vlOpening,
                        color: (last?.vlProjected ?? 0) < 0
                            ? AppColors.danger
                            : AppColors.primaryDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 240,
                            child: CustomPaint(
                              painter: CashflowChartPainter(c.days),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _Legend(
                                color: AppColors.success,
                                label: Strings.finIn,
                              ),
                              _Legend(
                                color: AppColors.danger,
                                label: Strings.finOut,
                              ),
                              _Legend(
                                color: AppColors.primaryDark,
                                label: Strings.finProjected,
                                line: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            Strings.finOverdueCarried,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (active.isNotEmpty)
                    SizedBox(
                      height: math.min(56.0 * active.length + 60, 520),
                      child: AppTable(
                        minWidth: context.isMobile ? 640 : 760,
                        columns: const [
                          DataColumn(label: Text(Strings.finDay)),
                          DataColumn(label: Text(Strings.finIn), numeric: true),
                          DataColumn(
                            label: Text(Strings.finOut),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              '${Strings.finIn} (${Strings.finPlanned})',
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              '${Strings.finOut} (${Strings.finPlanned})',
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(Strings.finProjected),
                            numeric: true,
                          ),
                        ],
                        rows: [
                          for (final d in active)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${d.day.day.toString().padLeft(2, '0')}/'
                                    '${d.day.month.toString().padLeft(2, '0')}',
                                  ),
                                ),
                                DataCell(_money(d.vlIn, AppColors.success)),
                                DataCell(_money(d.vlOut, AppColors.danger)),
                                DataCell(
                                  _money(d.vlInPlanned, AppColors.muted),
                                ),
                                DataCell(
                                  _money(d.vlOutPlanned, AppColors.muted),
                                ),
                                DataCell(
                                  Text(
                                    Numbers.money(d.vlProjected),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: d.vlProjected < 0
                                          ? AppColors.danger
                                          : AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _money(double v, Color color) => Text(
    v == 0 ? '-' : Numbers.money(v),
    style: TextStyle(color: v == 0 ? AppColors.muted : color),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.line = false});

  final Color color;
  final String label;
  final bool line;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: line ? 18 : 10,
          height: line ? 3 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Barras de entrada (realizado cheio, previsto claro) acima do zero, saidas
/// abaixo, e a linha do saldo projetado.
class CashflowChartPainter extends CustomPainter {
  CashflowChartPainter(this.days);

  final List<CashflowDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const left = 4.0;
    const bottomPad = 16.0;
    final w = size.width - left;
    final h = size.height - bottomPad;

    var maxIn = 0.0;
    var maxOut = 0.0;
    var minP = 0.0;
    var maxP = 0.0;
    for (final d in days) {
      maxIn = math.max(maxIn, d.vlIn + d.vlInPlanned);
      maxOut = math.max(maxOut, d.vlOut + d.vlOutPlanned);
      minP = math.min(minP, d.vlProjected);
      maxP = math.max(maxP, d.vlProjected);
    }
    final top = math.max(math.max(maxIn, maxP), 1.0);
    final bottom = math.max(math.max(maxOut, -minP), 0.0);
    final span = top + bottom;
    double y(double v) => h * (top - v) / span;

    final zero = y(0);
    canvas.drawLine(
      Offset(left, zero),
      Offset(size.width, zero),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );

    final slot = w / days.length;
    final bar = math.max(slot * 0.6, 1.0);
    final inDone = Paint()..color = AppColors.success;
    final inPlan = Paint()..color = AppColors.success.withValues(alpha: 0.3);
    final outDone = Paint()..color = AppColors.danger;
    final outPlan = Paint()..color = AppColors.danger.withValues(alpha: 0.3);
    final labelStyle = const TextStyle(color: AppColors.muted, fontSize: 10);

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = left + i * slot + (slot - bar) / 2;
      var cur = 0.0;
      void stack(double v, Paint p, {required bool up}) {
        if (v <= 0) return;
        final a = y(up ? cur : -cur);
        cur += v;
        final b = y(up ? cur : -cur);
        canvas.drawRect(
          Rect.fromLTRB(x, math.min(a, b), x + bar, math.max(a, b)),
          p,
        );
      }

      stack(d.vlIn, inDone, up: true);
      stack(d.vlInPlanned, inPlan, up: true);
      cur = 0;
      stack(d.vlOut, outDone, up: false);
      stack(d.vlOutPlanned, outPlan, up: false);

      final day = d.day.day;
      if (day == 1 || day % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$day', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + bar / 2 - tp.width / 2, h + 2));
      }
    }

    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final p = Offset(left + i * slot + slot / 2, y(days[i].vlProjected));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CashflowChartPainter old) => old.days != days;
}
