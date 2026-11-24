import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../application/pricing_controllers.dart';
import '../domain/pricing_models.dart';
import '../../integrations/presentation/integration_banner.dart';
import '../../integrations/domain/integration_models.dart';

/// Pesquisa de preco de mercado (Edge Function material-price-lookup).
/// Devolve a oferta escolhida ou null.
class PriceLookupSheet extends ConsumerStatefulWidget {
  const PriceLookupSheet({super.key, required this.query});

  final String query;

  static Future<PriceOffer?> show(
    BuildContext context, {
    required String query,
  }) {
    final sheet = PriceLookupSheet(query: query);
    if (context.isMobile) {
      return showModalBottomSheet<PriceOffer>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: sheet),
      );
    }
    return showDialog<PriceOffer>(
      context: context,
      builder: (_) =>
          Dialog(child: SizedBox(width: 600, height: 640, child: sheet)),
    );
  }

  @override
  ConsumerState<PriceLookupSheet> createState() => _PriceLookupSheetState();
}

class _PriceLookupSheetState extends ConsumerState<PriceLookupSheet> {
  late final _query = TextEditingController(text: widget.query);
  bool _loading = false;
  PriceLookupResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.query.trim().length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 3 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(materialsProvider.notifier).lookupPrice(q);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Strings.lookupTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: Strings.close,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: IntegrationBanner(
            codes: [IntegrationCode.priceLookup],
            pendingText: Strings.intPricePending,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            Strings.lookupHelp,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _query,
            autofocus: widget.query.trim().isEmpty,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: Strings.lookupQuery,
              hintText: Strings.lookupQueryHint,
              prefixIcon: const Icon(Icons.travel_explore_rounded),
              suffixIcon: IconButton(
                tooltip: Strings.search,
                icon: const Icon(Icons.search_rounded),
                onPressed: _loading ? null : _search,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text(
              Strings.lookupSearching,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: Strings.loadError,
        subtitle: _error,
        actionLabel: Strings.retry,
        onAction: _search,
      );
    }
    final result = _result;
    if (result == null) {
      return const AppEmptyState(
        icon: Icons.travel_explore_rounded,
        title: Strings.lookupTitle,
        subtitle: Strings.lookupHelp,
      );
    }
    if (result.offers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: Strings.lookupEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        if (result.vlSuggested != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${Strings.lookupSuggested}: ${Numbers.money(result.vlSuggested)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        for (final o in result.offers)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => Navigator.of(context).pop(o),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.vcStore,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            [
                              o.vcTitle,
                              if (o.vcPackage != null) o.vcPackage!,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      Numbers.money(o.vlPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppButton(
                      label: Strings.useOffer,
                      variant: AppButtonVariant.text,
                      expanded: false,
                      onPressed: () => Navigator.of(context).pop(o),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
