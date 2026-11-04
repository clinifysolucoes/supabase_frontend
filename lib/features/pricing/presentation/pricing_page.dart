import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import 'materials_tab.dart';
import 'params_tab.dart';
import 'procedures_tab.dart';
import 'specialties_tab.dart';

/// Precificacao: Especialidades (procedimentos agrupados, lucro por
/// especialidade e alerta do valor cobrado), Procedimentos (preco calculado), Materiais (custo por
/// unidade de uso, preco manual ou de mercado) e Parametros (custos da
/// clinica, estrutura, percentuais, regime PF/PJ, taxas adicionais).
class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = ref.watch(canReadProvider(ScreenCodes.pricing));
    if (!canRead) {
      return const AppShell(
        section: AppSection.pricing,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.pricing));
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.pricing));

    return AppShell(
      section: AppSection.pricing,
      child: DefaultTabController(
        length: 4,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: Strings.pricingTitle,
                subtitle: canUpdate || canCreate
                    ? Strings.pricingSubtitle
                    : '${Strings.pricingSubtitle} ${Strings.readOnlyHint}',
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.line),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primaryDark,
                    unselectedLabelColor: AppColors.muted,
                    labelStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    unselectedLabelStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    tabs: const [
                      _CompactTab(
                        icon: Icons.category_outlined,
                        label: Strings.tabSpecialties,
                      ),
                      _CompactTab(
                        icon: Icons.medical_services_outlined,
                        label: Strings.tabProcedures,
                      ),
                      _CompactTab(
                        icon: Icons.inventory_2_outlined,
                        label: Strings.tabMaterials,
                      ),
                      _CompactTab(
                        icon: Icons.tune_rounded,
                        label: Strings.tabParams,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Expanded(
                child: TabBarView(
                  children: [
                    SpecialtiesTab(),
                    ProceduresTab(),
                    MaterialsTab(),
                    ParamsTab(),
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

/// Aba com icone e texto na mesma linha (altura 44).
class _CompactTab extends StatelessWidget {
  const _CompactTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
