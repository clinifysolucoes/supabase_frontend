import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../domain/company_user.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

/// Acao do menu do card.
enum UserCardAction { edit, password, toggleStatus, unlink }

/// Usuarios da empresa em cards: situacao, nome, perfis por filial, e-mail,
/// telefone e ultimo acesso; o menu (⋮) tem editar, redefinir senha,
/// inativar/ativar e remover da empresa.
class UserCardGrid extends StatelessWidget {
  const UserCardGrid({
    super.key,
    required this.users,
    required this.onAction,
    this.canUpdate = false,
  });

  final List<CompanyUser> users;
  final void Function(CompanyUser user, UserCardAction action) onAction;
  final bool canUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = (c.maxWidth / 300).floor().clamp(1, 4);
        final width = (c.maxWidth - (columns - 1) * AppSpacing.md) / columns;
        return SingleChildScrollView(
          child: SizedBox(
            width: c.maxWidth,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final u in users)
                  SizedBox(
                    width: width,
                    child: UserCard(
                      user: u,
                      canUpdate: canUpdate,
                      onAction: (a) => onAction(u, a),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    required this.onAction,
    this.canUpdate = false,
  });

  final CompanyUser user;
  final ValueChanged<UserCardAction> onAction;
  final bool canUpdate;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final profiles = {for (final b in u.branches) b.vcProfile}.join(', ');
    final phone = u.vcMobile ?? u.vcPhone;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: canUpdate ? () => onAction(UserCardAction.edit) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppStatusChip(status: u.itStatus, compact: true),
                  const Spacer(),
                  if (canUpdate)
                    PopupMenuButton<UserCardAction>(
                      tooltip: Strings.actions,
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: UserCardAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text(Strings.edit),
                          ),
                        ),
                        const PopupMenuItem(
                          value: UserCardAction.password,
                          child: ListTile(
                            leading: Icon(Icons.lock_reset_rounded),
                            title: Text(Strings.resetPassword),
                          ),
                        ),
                        PopupMenuItem(
                          value: UserCardAction.toggleStatus,
                          child: ListTile(
                            leading: Icon(
                              u.itStatus == 1
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline_rounded,
                            ),
                            title: Text(
                              u.itStatus == 1
                                  ? Strings.inactivateUser
                                  : Strings.activateUser,
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: UserCardAction.unlink,
                          child: ListTile(
                            leading: Icon(
                              Icons.person_remove_outlined,
                              color: AppColors.danger,
                            ),
                            title: Text(Strings.unlinkUser),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: u.idAdmin
                      ? AppColors.mint
                      : AppColors.surface,
                  foregroundColor: u.idAdmin
                      ? AppColors.primaryDark
                      : AppColors.muted,
                  child: Text(
                    u.initials,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                u.vcName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    line(
                      Icons.badge_outlined,
                      profiles.isEmpty ? Strings.userNoAccess : profiles,
                    ),
                    if (u.vcEmail != null) line(Icons.mail_outline, u.vcEmail!),
                    line(Icons.phone_outlined, phone ?? Strings.notInformed),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              line(
                Icons.schedule_rounded,
                '${Strings.lastLogin}: ${u.dhLastLogin == null ? Strings.never : _dateTime.format(u.dhLastLogin!.toLocal())}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
