import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import 'app_button.dart';

/// Lista vazia, erro de carregamento ou "sem dados": icone, texto e acao.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Variante para falha de carregamento, com botao de tentar de novo.
  factory AppEmptyState.error({
    required String message,
    required VoidCallback onRetry,
  }) => AppEmptyState(
    icon: Icons.cloud_off_rounded,
    title: Strings.loadError,
    subtitle: message,
    actionLabel: Strings.retry,
    onAction: onRetry,
  );

  final IconData? icon;

  /// Desenho no lugar de [icon] (ex.: MenuGlyphIcon), no mesmo circulo.
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child:
                    iconWidget ??
                    Icon(icon, size: 30, color: AppColors.primaryDark),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.secondary,
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
