import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../domain/pricing_models.dart';
import 'factor_edit_dialog.dart';

/// Composicao do preco de um procedimento: custos, percentuais e o preco
/// sugerido. Usada na simulacao do formulario e no detalhe do procedimento.
/// Com [onEditFactor], cada fator vira clicavel (edicao inline).
class PricingBreakdown extends StatelessWidget {
  const PricingBreakdown({
    super.key,
    required this.result,
    this.currentPrice,
    this.pcCard,
    this.pcCommission,
    this.pcFees,
    this.pcTax,
    this.pcProfit,
    this.onEditFactor,
  });

  final PricingResult result;
  final double? currentPrice;
  final double? pcCard;
  final double? pcCommission;
  final double? pcFees;
  final double? pcTax;
  final double? pcProfit;
  final ValueChanged<PricingFactor>? onEditFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final taxLabel = r.itTaxRegime == TaxRegime.pj
        ? '${Strings.incomeTax} (${Strings.taxRegimePjShort})'
        : '${Strings.incomeTax} (${Strings.taxRegimePfShort})';
    VoidCallback? edit(PricingFactor f) =>
        onEditFactor == null ? null : () => onEditFactor!(f);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(Strings.materialsCost, Numbers.money(r.vlMaterial)),
        _Line(Strings.labCostShort, Numbers.money(r.vlLab)),
        _Line(
          Strings.structureCost,
          Numbers.money(r.vlStructure),
          onTap: edit(PricingFactor.structure),
        ),
        _Line(
          Strings.professionalCost,
          Numbers.money(r.vlProfessional),
          onTap: edit(PricingFactor.professional),
        ),
        _Line(Strings.directCost, Numbers.money(r.vlDirectCost), strong: true),
        const Divider(height: AppSpacing.lg),
        if (!r.idValid) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.danger),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    Strings.priceInvalid,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          if (onEditFactor != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Line(
              _pct(Strings.cardFee, pcCard),
              '',
              onTap: edit(PricingFactor.card),
            ),
            _Line(
              _pct(Strings.commission, pcCommission),
              '',
              onTap: edit(PricingFactor.commission),
            ),
            _Line(
              _pct(Strings.extraFees, pcFees),
              '',
              onTap: edit(PricingFactor.fees),
            ),
            _Line(_pct(taxLabel, pcTax), '', onTap: edit(PricingFactor.tax)),
            _Line(
              _pct(Strings.profit, pcProfit),
              '',
              onTap: edit(PricingFactor.profit),
            ),
          ],
        ] else ...[
          _Line(
            _pct(Strings.cardFee, pcCard),
            Numbers.money(r.vlCard),
            onTap: edit(PricingFactor.card),
          ),
          _Line(
            _pct(Strings.commission, pcCommission),
            Numbers.money(r.vlCommission),
            onTap: edit(PricingFactor.commission),
          ),
          _Line(
            _pct(Strings.extraFees, pcFees),
            Numbers.money(r.vlFees),
            onTap: edit(PricingFactor.fees),
          ),
          _Line(
            _pct(taxLabel, pcTax),
            Numbers.money(r.vlTax),
            onTap: edit(PricingFactor.tax),
          ),
          _Line(
            '${Strings.profit} (${Numbers.percent(r.pcProfitReal)})',
            Numbers.money(r.vlProfit),
            strong: true,
            color: AppColors.success,
            onTap: edit(PricingFactor.profit),
          ),
          const Divider(height: AppSpacing.lg),
          _Line(
            Strings.minPrice,
            Numbers.money(r.vlPriceMin),
            help: Strings.minPriceHelp,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.suggestedPrice,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  Numbers.money(r.vlPrice),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (currentPrice != null && r.vlCurrentPrice != null) ...[
          const SizedBox(height: AppSpacing.md),
          PriceCheckPanel(result: r),
        ],
      ],
    );
  }

  static String _pct(String label, double? pc) =>
      pc == null ? label : '$label (${Numbers.percent(pc, decimals: 2)})';
}

class _Line extends StatelessWidget {
  const _Line(
    this.label,
    this.value, {
    this.strong = false,
    this.color,
    this.help,
    this.onTap,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? color;
  final String? help;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (strong ? AppColors.ink : AppColors.muted),
    );
    final row = Padding(
      padding: EdgeInsets.symmetric(
        vertical: 3,
        horizontal: onTap == null ? 0 : AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (help != null)
                  Text(
                    help!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              color: color ?? AppColors.ink,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Tooltip(
      message: Strings.editFactor,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: AppColors.mint,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// Cor de cada situacao do valor cobrado (verde, amarelo, laranja, vermelho).
Color priceStatusColor(int status) => switch (status) {
  PriceStatus.ok => AppColors.success,
  PriceStatus.belowSuggested => AppColors.warning,
  PriceStatus.belowMin => const Color(0xFFE07B2E),
  PriceStatus.belowCost => AppColors.danger,
  _ => AppColors.muted,
};

IconData priceStatusIcon(int status) => switch (status) {
  PriceStatus.ok => Icons.check_circle_rounded,
  PriceStatus.belowSuggested => Icons.info_rounded,
  PriceStatus.belowMin => Icons.warning_amber_rounded,
  PriceStatus.belowCost => Icons.error_rounded,
  _ => Icons.remove_circle_outline_rounded,
};

/// Valor cobrado hoje x calculo: situacao, explicacao, lucro que sobra e a
/// diferenca para o preco sugerido. E o alerta que o dentista ve no
/// procedimento.
class PriceCheckPanel extends StatelessWidget {
  const PriceCheckPanel({super.key, required this.result});

  final PricingResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final status = r.itPriceStatus;
    final color = priceStatusColor(status);
    final help = PriceStatus.help(status);
    final diff = r.vlCurrentDiff;
    final profit = r.vlCurrentProfit;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // titulo em linha propria (quebra normal) e chip embaixo: no painel
          // estreito do formulario o titulo nao pode ficar espremido ao lado
          // do chip, senao quebra letra por letra e empurra o Salvar
          Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      priceStatusIcon(status),
                      color: color,
                      size: 20,
                    ),
                  ),
                ),
                TextSpan(
                  text:
                      '${Strings.priceCheckTitle}: ${Numbers.money(r.vlCurrentPrice)}',
                ),
              ],
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: PriceStatusChip(status: status),
          ),
          if (help != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              help,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (profit != null)
            _Line(
              r.pcCurrentProfit == null
                  ? Strings.currentProfit
                  : '${Strings.currentProfit} (${Numbers.percent(r.pcCurrentProfit)})',
              Numbers.money(profit),
              strong: true,
              color: profit < 0 ? AppColors.danger : AppColors.ink,
            ),
          if (diff != null)
            _Line(
              Strings.diffToSuggested,
              '${diff >= 0 ? '+' : ''}${Numbers.money(diff)}',
              color: diff >= 0 ? AppColors.success : AppColors.danger,
            ),
        ],
      ),
    );
  }
}

/// Chip com a situacao do valor cobrado hoje.
class PriceStatusChip extends StatelessWidget {
  const PriceStatusChip({super.key, required this.status});

  final int status;

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
            PriceStatus.label(status),
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

/// Chips de alerta do procedimento.
class ProcedureAlertChips extends StatelessWidget {
  const ProcedureAlertChips({super.key, required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final a in alerts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  ProcedureAlert.label(a),
                  style: const TextStyle(
                    color: Color(0xFF8A5A0B),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
