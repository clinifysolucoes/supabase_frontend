import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../features/session/application/session_controller.dart';
import '../../features/session/domain/screen_codes.dart';
import '../../features/session/presentation/branch_selection_dialog.dart';
import '../../l10n/strings.dart';
import 'app_logo.dart';

enum AppSection {
  dashboard,
  agenda,
  patients,
  finance,
  pricing,
  users,
  profiles,
  logs,
  settings,
  budgets,
}

class _Destination {
  const _Destination({
    required this.section,
    required this.code,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final AppSection section;
  final String code;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}

const _dashboard = _Destination(
  section: AppSection.dashboard,
  code: ScreenCodes.dashboard,
  icon: Icons.space_dashboard_outlined,
  selectedIcon: Icons.space_dashboard_rounded,
  label: Strings.dashboard,
  route: '/dashboard',
);

/// Telas de negocio: ficam no menu principal, abaixo do Dashboard.
const _agenda = _Destination(
  section: AppSection.agenda,
  code: ScreenCodes.agenda,
  icon: Icons.calendar_month_outlined,
  selectedIcon: Icons.calendar_month_rounded,
  label: Strings.agenda,
  route: '/agenda',
);

const _patients = _Destination(
  section: AppSection.patients,
  code: ScreenCodes.patients,
  icon: Icons.contact_page_outlined,
  selectedIcon: Icons.contact_page_rounded,
  label: Strings.patients,
  route: '/pacientes',
);

const _budgets = _Destination(
  section: AppSection.budgets,
  code: ScreenCodes.budgets,
  icon: Icons.request_quote_outlined,
  selectedIcon: Icons.request_quote_rounded,
  label: Strings.budgets,
  route: '/orcamentos',
);

const _finance = _Destination(
  section: AppSection.finance,
  code: ScreenCodes.finance,
  icon: Icons.account_balance_wallet_outlined,
  selectedIcon: Icons.account_balance_wallet_rounded,
  label: Strings.finance,
  route: '/financeiro',
);

const _pricing = _Destination(
  section: AppSection.pricing,
  code: ScreenCodes.pricing,
  icon: Icons.calculate_outlined,
  selectedIcon: Icons.calculate_rounded,
  label: Strings.pricing,
  route: '/precificacao',
);

const _mainItems = [
  _dashboard,
  _agenda,
  _patients,
  _budgets,
  _finance,
  _pricing,
];

/// Itens do quadrado de administracao (ao lado do Dashboard).
const _adminItems = [
  _Destination(
    section: AppSection.users,
    code: ScreenCodes.users,
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    label: Strings.users,
    route: '/usuarios',
  ),
  _Destination(
    section: AppSection.profiles,
    code: ScreenCodes.profiles,
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge_rounded,
    label: Strings.profiles,
    route: '/perfis',
  ),
  _Destination(
    section: AppSection.logs,
    code: ScreenCodes.logs,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    label: Strings.logs,
    route: '/logs',
  ),
  _Destination(
    section: AppSection.settings,
    code: ScreenCodes.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: Strings.settingsTitle,
    route: '/configuracoes',
  ),
];

/// Moldura das telas internas.
///   Desktop: menu lateral com o Dashboard e, ao lado dele, um quadrado que
///            abre/fecha Usuarios, Perfis e Logs (so os que o usuario pode ver).
///   Mobile:  barra inferior com Dashboard e o quadrado, que abre uma folha
///            com os tres itens.
/// Cabecalho com a filial atual (clicavel para trocar) e o usuario.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.section,
    required this.child,
    this.title,
  });

  final AppSection section;
  final Widget child;
  final String? title;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late bool _adminOpen = _adminItems.any((d) => d.section == widget.section);

  String get _pageTitle =>
      widget.title ??
      [
        ..._mainItems,
        ..._adminItems,
      ].firstWhere((d) => d.section == widget.section).label;

  void _go(BuildContext context, _Destination d) {
    if (d.section != widget.section) context.go(d.route);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      sessionControllerProvider.select((s) => s.selected),
    );
    final visibleAdmin = [
      for (final d in _adminItems)
        if (selected?.canRead(d.code) ?? false) d,
    ];
    final visibleMain = [
      for (final d in _mainItems)
        if (d.section == AppSection.dashboard ||
            (selected?.canRead(d.code) ?? false))
          d,
    ];
    final title = _pageTitle;

    return ResponsiveBuilder(
      mobile: (_) => _MobileShell(
        title: title,
        section: widget.section,
        mainItems: visibleMain,
        adminItems: visibleAdmin,
        onGo: (d) => _go(context, d),
        child: widget.child,
      ),
      desktop: (_) => Scaffold(
        body: Row(
          children: [
            _Sidebar(
              section: widget.section,
              mainItems: visibleMain,
              adminItems: visibleAdmin,
              adminOpen: _adminOpen,
              onToggleAdmin: () => setState(() => _adminOpen = !_adminOpen),
              onGo: (d) => _go(context, d),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: title),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- desktop -----------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.mainItems,
    required this.adminItems,
    required this.adminOpen,
    required this.onToggleAdmin,
    required this.onGo,
  });

  final AppSection section;
  final List<_Destination> mainItems;
  final List<_Destination> adminItems;
  final bool adminOpen;
  final VoidCallback onToggleAdmin;
  final ValueChanged<_Destination> onGo;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final adminSelected = adminItems.any((d) => d.section == section);

    return Container(
      width: wide ? 248 : 88,
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Center(child: AppLogo(size: 32, showWordmark: wide)),
          ),
          // Itens rolam quando a janela e baixa (logo fica fixo).
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavTile(
                            destination: _dashboard,
                            selected: section == AppSection.dashboard,
                            wide: wide,
                            onTap: () => onGo(_dashboard),
                          ),
                        ),
                        if (adminItems.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          _AdminSquare(
                            open: adminOpen,
                            highlighted: adminSelected,
                            onTap: onToggleAdmin,
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final d in mainItems.where((d) => d != _dashboard))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.xs,
                        AppSpacing.sm,
                        0,
                      ),
                      child: _NavTile(
                        destination: d,
                        selected: d.section == section,
                        wide: wide,
                        onTap: () => onGo(d),
                      ),
                    ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: adminOpen && adminItems.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.sm,
                              AppSpacing.sm,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (wide)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.md,
                                      AppSpacing.xs,
                                      AppSpacing.md,
                                      AppSpacing.xs,
                                    ),
                                    child: Text(
                                      Strings.adminMenu.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                  ),
                                for (final d in adminItems)
                                  _NavTile(
                                    destination: d,
                                    selected: d.section == section,
                                    wide: wide,
                                    onTap: () => onGo(d),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O "quadrado": abre e fecha os itens de administracao.
class _AdminSquare extends StatelessWidget {
  const _AdminSquare({
    required this.open,
    required this.highlighted,
    required this.onTap,
  });

  final bool open;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = open || highlighted;
    return Tooltip(
      message: Strings.openAdminMenu,
      child: Material(
        color: active ? AppColors.mint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              open ? Icons.grid_view_rounded : Icons.grid_view_outlined,
              size: 22,
              color: active ? AppColors.primaryDark : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.selected,
    required this.wide,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.muted;
    final tile = Material(
      color: selected ? AppColors.mint : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: wide
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              SizedBox(width: wide ? AppSpacing.md : 0),
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: color,
              ),
              if (wide) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return wide ? tile : Tooltip(message: destination.label, child: tile);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          const _BranchChip(),
          const SizedBox(width: AppSpacing.md),
          const _UserMenu(),
        ],
      ),
    );
  }
}

// --- mobile ------------------------------------------------------------------

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.title,
    required this.section,
    required this.mainItems,
    required this.adminItems,
    required this.onGo,
    required this.child,
  });

  final String title;
  final AppSection section;
  final List<_Destination> mainItems;
  final List<_Destination> adminItems;
  final ValueChanged<_Destination> onGo;
  final Widget child;

  Future<void> _openAdminSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<_Destination>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      Strings.adminMenu,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              for (final d in adminItems)
                ListTile(
                  leading: Icon(
                    d.section == section ? d.selectedIcon : d.icon,
                    color: d.section == section
                        ? AppColors.primaryDark
                        : AppColors.muted,
                  ),
                  title: Text(
                    d.label,
                    style: TextStyle(
                      fontWeight: d.section == section
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  selected: d.section == section,
                  selectedTileColor: AppColors.mint,
                  onTap: () => Navigator.of(context).pop(d),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onGo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final adminSelected = adminItems.any((d) => d.section == section);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          _BranchChip(compact: true),
          SizedBox(width: AppSpacing.xs),
          _UserMenu(compact: true),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: adminSelected
            ? mainItems.length
            : mainItems
                  .indexWhere((d) => d.section == section)
                  .clamp(0, mainItems.length - 1),
        onDestinationSelected: (i) {
          if (i < mainItems.length) {
            onGo(mainItems[i]);
          } else {
            _openAdminSheet(context);
          }
        },
        destinations: [
          for (final d in mainItems)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          if (adminItems.isNotEmpty)
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: Strings.adminMenu,
            ),
        ],
      ),
    );
  }
}

// --- cabecalho: filial e usuario --------------------------------------------

/// Empresa · filial atual. Clique abre o pop-up para trocar.
class _BranchChip extends ConsumerWidget {
  const _BranchChip({this.compact = false});

  final bool compact;

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final state = ref.read(sessionControllerProvider);
    final session = state.context;
    if (session == null) return;
    final result = await BranchSelectionDialog.show(
      context,
      session: session,
      current: state.selected,
      allowCancel: true,
    );
    if (result != null) {
      await ref.read(sessionControllerProvider.notifier).select(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final selected = state.selected;
    if (selected == null) return const SizedBox.shrink();
    final canSwitch = (state.context?.branches.length ?? 0) > 1;
    final label = compact ? selected.branch.vcName : selected.label;

    return Tooltip(
      message: canSwitch ? Strings.switchBranch : selected.label,
      child: ActionChip(
        avatar: const Icon(
          Icons.store_mall_directory_rounded,
          size: 18,
          color: AppColors.primaryDark,
        ),
        label: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 120 : 320),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        onPressed: canSwitch ? () => _switch(context, ref) : null,
      ),
    );
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final user = state.context?.user;
    if (user == null) return const SizedBox.shrink();
    final canSwitch = (state.context?.branches.length ?? 0) > 1;

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.primaryDark,
      child: Text(
        user.initials,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: user.vcName,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) async {
        final controller = ref.read(sessionControllerProvider.notifier);
        if (value == 'switch') {
          final session = state.context;
          if (session == null) return;
          final result = await BranchSelectionDialog.show(
            context,
            session: session,
            current: state.selected,
            allowCancel: true,
          );
          if (result != null) await controller.select(result);
        } else if (value == 'signout') {
          await controller.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.vcName,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (user.vcEmail != null)
                Text(
                  user.vcEmail!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (canSwitch)
          const PopupMenuItem<String>(
            value: 'switch',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.swap_horiz_rounded),
              title: Text(Strings.switchBranch),
            ),
          ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text(Strings.signOut),
          ),
        ),
      ],
      child: compact
          ? avatar
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: AppSpacing.sm),
                Text(
                  user.vcName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.expand_more_rounded, color: AppColors.muted),
              ],
            ),
    );
  }
}
