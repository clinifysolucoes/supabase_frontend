import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../application/integration_controllers.dart';
import '../domain/integration_models.dart';

/// Onde abrir cada integracao nas Configuracoes.
enum IntegrationTarget { notify, whatsapp, patients, invoice }

class _Item {
  const _Item({
    required this.icon,
    required this.title,
    required this.text,
    required this.codes,
    this.anyReady = false,
    this.target,
    this.where,
    this.contract = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final List<String> codes;

  /// Basta uma das [codes] estar pronta (ex.: avaliacao por e-mail OU SMS).
  final bool anyReady;
  final IntegrationTarget? target;

  /// Onde fica, quando nao e uma secao das Configuracoes.
  final String? where;

  /// Depende de contrato de cada clinica/centro (nao ha chave do sistema).
  final bool contract;
}

const _items = [
  _Item(
    icon: Icons.email_outlined,
    title: Strings.intEmail,
    text: Strings.intEmailText,
    codes: [IntegrationCode.email],
    target: IntegrationTarget.notify,
  ),
  _Item(
    icon: Icons.sms_outlined,
    title: Strings.intSms,
    text: Strings.intSmsText,
    codes: [IntegrationCode.sms],
    target: IntegrationTarget.notify,
  ),
  _Item(
    icon: Icons.star_outline_rounded,
    title: Strings.intReview,
    text: Strings.intReviewText,
    codes: [IntegrationCode.email, IntegrationCode.sms],
    anyReady: true,
    target: IntegrationTarget.notify,
  ),
  _Item(
    icon: Icons.chat_outlined,
    title: Strings.intWhatsapp,
    text: Strings.intWhatsappText,
    codes: [IntegrationCode.whatsapp],
    target: IntegrationTarget.whatsapp,
  ),
  _Item(
    icon: Icons.manage_search_rounded,
    title: Strings.intCredit,
    text: Strings.intCreditText,
    codes: [IntegrationCode.credit],
    target: IntegrationTarget.patients,
  ),
  _Item(
    icon: Icons.receipt_long_outlined,
    title: Strings.intInvoice,
    text: Strings.intInvoiceText,
    codes: [IntegrationCode.invoice],
    target: IntegrationTarget.invoice,
  ),
  _Item(
    icon: Icons.document_scanner_outlined,
    title: Strings.intRadiology,
    text: Strings.intRadiologyText,
    codes: [],
    where: Strings.intRadiologyWhere,
    contract: true,
  ),
  _Item(
    icon: Icons.travel_explore_rounded,
    title: Strings.intPrice,
    text: Strings.intPriceText,
    codes: [IntegrationCode.priceLookup],
    where: Strings.intPriceWhere,
  ),
];

/// Configuracoes > Integracoes: todas as integracoes externas, o que cada uma
/// faz, se ja esta pronta e o que falta para funcionar.
class IntegrationsSection extends ConsumerWidget {
  const IntegrationsSection({super.key, this.onOpen});

  final ValueChanged<IntegrationTarget>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final map = ref.watch(integrationStatusProvider).valueOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.settingsIntegrations,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: Strings.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(integrationStatusProvider),
                ),
              ],
            ),
            Text(
              Strings.intHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (map == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final item in _items)
                _ItemTile(item: item, map: map, onOpen: onOpen),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.map, this.onOpen});

  final _Item item;
  final IntegrationStatusMap map;
  final ValueChanged<IntegrationTarget>? onOpen;

  IntegrationState get _state {
    if (item.contract) return IntegrationState.pending;
    final states = [for (final c in item.codes) map.of(c).state];
    if (states.contains(IntegrationState.unknown)) {
      return IntegrationState.unknown;
    }
    if (item.anyReady && states.contains(IntegrationState.ready)) {
      return IntegrationState.ready;
    }
    if (states.every((s) => s == IntegrationState.ready)) {
      return IntegrationState.ready;
    }
    if (states.every(
      (s) => s == IntegrationState.ready || s == IntegrationState.preparing,
    )) {
      return IntegrationState.preparing;
    }
    return IntegrationState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final (label, color) = switch (state) {
      IntegrationState.ready => (Strings.intReady, const Color(0xFF2E9E6B)),
      IntegrationState.preparing => (Strings.intPreparing, AppColors.warning),
      IntegrationState.unknown => (Strings.intUnknown, AppColors.muted),
      IntegrationState.pending =>
        item.contract
            ? (Strings.intContract, AppColors.warning)
            : (Strings.intPending, AppColors.warning),
    };
    final missing = {for (final c in item.codes) ...map.of(c).missing}.toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: color.withValues(alpha: 0.12),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Text(item.text),
                  if (item.where != null)
                    Text(
                      item.where!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  if (state != IntegrationState.ready &&
                      missing.isNotEmpty &&
                      !(item.anyReady && state == IntegrationState.ready))
                    Text(
                      Strings.intMissing(missing.join(', ')),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  if (item.target != null && onOpen != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text(Strings.intOpen),
                        onPressed: () => onOpen!(item.target!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
