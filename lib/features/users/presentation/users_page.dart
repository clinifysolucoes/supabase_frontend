import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_pagination.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/choice.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../profiles/domain/access_profile.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/users_controller.dart';
import '../data/user_repository.dart';
import '../domain/company_user.dart';
import 'user_card_grid.dart';
import 'user_form_dialog.dart';

/// Usuarios da empresa atual: cadastrar, editar acesso por filial, bloquear,
/// remover. A lista exige ler USERS (o backend exige administrador para
/// listar); cadastrar exige criar; editar/remover exigem alterar.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setFilters(UserFilters f) =>
      ref.read(userFiltersProvider.notifier).state = f;

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _setFilters(
        ref.read(userFiltersProvider).copyWith(search: value, page: 1),
      );
    });
  }

  Future<void> _openForm([CompanyUser? user]) async {
    final saved = await UserFormDialog.show(context, user: user);
    if (saved && mounted) {
      AppSnack.success(
        context,
        user == null ? Strings.userCreated : Strings.savedSuccess,
      );
    }
  }

  Future<void> _unlink(CompanyUser user) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.unlinkUser,
      message: Strings.unlinkConfirm(user.vcName),
      confirmLabel: Strings.remove,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(usersProvider.notifier).unlink(nrUser: user.nrUser);
      if (mounted) AppSnack.success(context, Strings.removedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _resetPassword(CompanyUser user) async {
    final password = await _ResetPasswordDialog.show(context, user);
    if (password == null || !mounted) return;
    try {
      await ref
          .read(usersProvider.notifier)
          .resetPassword(nrUser: user.nrUser, password: password);
      if (mounted) AppSnack.success(context, Strings.passwordResetDone);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _toggleStatus(CompanyUser user) async {
    final activate = user.itStatus != UserStatus.active;
    if (!activate &&
        (!await AppConfirmDialog.show(
              context,
              title: Strings.inactivateUser,
              message: Strings.inactivateUserConfirm(user.vcName),
            ) ||
            !mounted)) {
      return;
    }
    try {
      await ref
          .read(usersProvider.notifier)
          .updateUser(
            nrUser: user.nrUser,
            itStatus: activate ? UserStatus.active : UserStatus.inactive,
          );
      if (mounted) {
        AppSnack.success(
          context,
          activate ? Strings.userActivated : Strings.userInactivated,
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  void _onAction(CompanyUser user, UserCardAction action) {
    switch (action) {
      case UserCardAction.edit:
        _openForm(user);
      case UserCardAction.password:
        _resetPassword(user);
      case UserCardAction.toggleStatus:
        _toggleStatus(user);
      case UserCardAction.unlink:
        _unlink(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRead = ref.watch(canReadProvider(ScreenCodes.users));
    if (!canRead) {
      return const AppShell(
        section: AppSection.users,
        child: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: Strings.noPermissionTitle,
          subtitle: Strings.noPermissionSubtitle,
        ),
      );
    }
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.users));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.users));

    final filters = ref.watch(userFiltersProvider);
    final async = ref.watch(usersProvider);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const [];

    final branchChoices = [
      const Choice<int>(value: null, label: Strings.allBranches),
      for (final b in branches)
        Choice<int>(
          value: b.nrBranch,
          label: b.vcName,
          subtitle: b.idMain ? Strings.mainBranch : null,
        ),
    ];
    final isMobile = context.isMobile;

    return AppShell(
      section: AppSection.users,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: Strings.usersTitle,
              subtitle: Strings.usersSubtitle,
              actions: [
                if (canCreate)
                  AppButton(
                    label: Strings.newUser,
                    icon: Icons.person_add_alt_1_rounded,
                    expanded: false,
                    onPressed: () => _openForm(),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: AppTextField(
                    label: Strings.search,
                    hint: Strings.searchUsersHint,
                    controller: _search,
                    prefixIcon: Icons.search_rounded,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 300,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(Strings.showOnlyActive),
                    value: filters.itStatus == UserStatus.active,
                    onChanged: (v) => _setFilters(
                      v ?? false
                          ? filters.copyWith(
                              itStatus: UserStatus.active,
                              page: 1,
                            )
                          : filters.copyWith(clearStatus: true, page: 1),
                    ),
                  ),
                ),
                if (branches.length > 1)
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: SearchableDropdown<Choice<int>>(
                      label: Strings.branch,
                      items: branchChoices,
                      value: branchChoices.firstWhere(
                        (c) => c.value == filters.nrBranch,
                        orElse: () => branchChoices.first,
                      ),
                      itemLabel: (c) => c.label,
                      itemSubtitle: (c) => c.subtitle,
                      onChanged: (c) => _setFilters(
                        c.value == null
                            ? filters.copyWith(clearBranch: true, page: 1)
                            : filters.copyWith(nrBranch: c.value, page: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppEmptyState.error(
                  message: describeError(e),
                  onRetry: () => ref.invalidate(usersProvider),
                ),
                data: (page) {
                  if (page.users.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: Strings.noUsers,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: UserCardGrid(
                          users: page.users,
                          canUpdate: canUpdate,
                          onAction: _onAction,
                        ),
                      ),
                      AppPagination(
                        page: page.page,
                        pageCount: page.pageCount,
                        total: page.total,
                        onPage: (p) => _setFilters(filters.copyWith(page: p)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Senha nova (duas vezes); devolve a senha ou null.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.user});

  final CompanyUser user;

  static Future<String?> show(BuildContext context, CompanyUser user) =>
      showDialog<String>(
        context: context,
        builder: (_) => _ResetPasswordDialog(user: user),
      );

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.resetPassword),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.resetPasswordHint(widget.user.vcName),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.newPassword,
                controller: _password,
                obscureText: true,
                validator: (v) =>
                    (v ?? '').length < 8 ? Strings.passwordMin : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: Strings.confirmPassword,
                controller: _confirm,
                obscureText: true,
                validator: (v) =>
                    v != _password.text ? Strings.passwordsDiffer : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.resetPassword,
          expanded: false,
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_password.text);
            }
          },
        ),
      ],
    );
  }
}
