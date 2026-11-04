import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../domain/finance_models.dart';

/// `< Novembro 2026 >`: troca o mes das listas.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: Strings.previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          SizedBox(
            width: 140,
            child: Text(
              '${Strings.monthName(month.month)} ${month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: Strings.nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

/// Cartao de indicador: rotulo, valor em destaque e uma linha de apoio.
class FinKpiCard extends StatelessWidget {
  const FinKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.ink,
    this.caption,
    this.onTap,
  });

  final String label;
  final double value;
  final IconData? icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.isMobile ? double.infinity : 230,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Numbers.money(value),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Situacao do lancamento com cor (aberto, vencido, pago, cancelado).
class EntryStatusChip extends StatelessWidget {
  const EntryStatusChip({super.key, required this.entry});

  final FinEntry entry;

  static Color colorOf(FinEntry e) => switch (e.itStatus) {
    EntryStatus.paid => AppColors.success,
    EntryStatus.cancelled => AppColors.muted,
    _ => e.idOverdue ? AppColors.danger : AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(entry);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        EntryStatus.label(entry.itStatus, overdue: entry.idOverdue),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Valor com sinal e cor: entrada verde, saida vermelha.
class SignedMoney extends StatelessWidget {
  const SignedMoney(this.value, {super.key, this.bold = false});

  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final color = value < 0
        ? AppColors.danger
        : (value > 0 ? AppColors.success : AppColors.muted);
    return Text(
      '${value > 0 ? '+' : ''}${Numbers.money(value)}',
      style: TextStyle(
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

/// Titulo de secao dentro das abas.
class FinSectionTitle extends StatelessWidget {
  const FinSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
