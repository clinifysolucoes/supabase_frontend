import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../application/integration_controllers.dart';
import '../domain/integration_models.dart';

/// Aviso de "preenchimento futuro" numa tela que depende de uma integracao
/// externa: some quando a integracao esta pronta. [codes] aceita mais de uma
/// (ex.: e-mail e SMS); o aviso aparece se alguma nao estiver pronta.
class IntegrationBanner extends ConsumerWidget {
  const IntegrationBanner({
    super.key,
    required this.codes,
    required this.pendingText,
    this.extra,
  });

  final List<String> codes;

  /// O que falta, em palavras de clinica (ex.: "contratar o emissor de notas").
  final String pendingText;

  /// Observacao a mais (ex.: "cada clinica usa o proprio numero").
  final String? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(integrationStatusProvider).valueOrNull;
    if (map == null) return const SizedBox.shrink();
    final states = [for (final c in codes) map.of(c)];
    if (states.every((s) => s.isReady)) return const SizedBox.shrink();
    final unknown = states.any((s) => s.state == IntegrationState.unknown);
    final preparing =
        !unknown &&
        states.every(
          (s) =>
              s.state == IntegrationState.preparing ||
              s.state == IntegrationState.ready,
        );
    final missing = {for (final s in states) ...s.missing}.toList()..sort();
    return IntegrationNotice(
      title: unknown
          ? Strings.intUnknownTitle
          : preparing
          ? Strings.intPreparingTitle
          : Strings.intPendingTitle,
      text: unknown
          ? Strings.intUnknownText
          : preparing
          ? Strings.intPreparingText
          : pendingText,
      extra: extra,
      technical: missing.isEmpty
          ? null
          : Strings.intMissing(missing.join(', ')),
    );
  }
}

/// Caixa amarela de aviso (usada pelo banner e pela secao Integracoes).
class IntegrationNotice extends StatelessWidget {
  const IntegrationNotice({
    super.key,
    required this.title,
    required this.text,
    this.extra,
    this.technical,
  });

  final String title;
  final String text;
  final String? extra;
  final String? technical;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(text),
                if (extra != null)
                  Text(
                    extra!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                if (technical != null)
                  Text(
                    technical!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
