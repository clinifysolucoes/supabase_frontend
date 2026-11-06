import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/mfa_types.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../auth/presentation/mfa_page.dart';
import '../../profiles/application/profiles_controller.dart';
import '../application/settings_controller.dart';
import '../domain/settings_models.dart';

/// Configuracoes > Seguranca: 2FA obrigatoria da empresa (administrador) e o
/// app autenticador da propria conta.
class SecuritySection extends ConsumerStatefulWidget {
  const SecuritySection({super.key, required this.settings});

  final BranchSettings settings;

  @override
  ConsumerState<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<SecuritySection> {
  late int _policy = widget.settings.itMfaPolicy;
  MfaStatus? _mine;
  bool _saving = false;

  SupabaseGateway get _gateway => ref.read(supabaseGatewayProvider);

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    try {
      final s = await _gateway.mfaStatus();
      if (mounted) setState(() => _mine = s);
    } catch (_) {
      if (mounted) setState(() => _mine = const MfaStatus());
    }
  }

  Future<void> _savePolicy() async {
    final c = ref.read(currentCompanyProvider);
    if (c == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveMfaPolicy(nrCompany: c, policy: _policy);
      ref.invalidate(settingsProvider);
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Strings.mfaTitle),
        content: SizedBox(
          width: 400,
          child: MfaPanel(
            voluntary: true,
            onDone: () => Navigator.of(ctx).pop(true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Strings.cancel),
          ),
        ],
      ),
    );
    await _loadMine();
    if (ok == true && mounted) AppSnack.success(context, Strings.mfaEnabled);
  }

  Future<void> _disable(MfaFactor f) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.mfaDisable,
      message: Strings.mfaDisableConfirm,
      confirmLabel: Strings.mfaDisable,
    );
    if (!ok || !mounted) return;
    try {
      await _gateway.mfaUnenroll(f.id);
      await _loadMine();
      if (mounted) AppSnack.success(context, Strings.mfaRemoved);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  String _label(int p) => switch (p) {
    1 => Strings.mfaPolicyAdmins,
    2 => Strings.mfaPolicyAll,
    _ => Strings.mfaPolicyNone,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = widget.settings.canEditClinic;
    final mine = _mine;
    final factor = mine?.verifiedFactor;
    Widget title(String t) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        t,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settingsSecurity,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              Strings.settingsSecurityHint,
              style: TextStyle(color: AppColors.muted),
            ),
            title(Strings.mfaMine),
            if (mine == null)
              const LinearProgressIndicator()
            else ...[
              Row(
                children: [
                  Icon(
                    factor != null
                        ? Icons.verified_user_rounded
                        : Icons.gpp_maybe_outlined,
                    color: factor != null
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      factor != null ? Strings.mfaMineOn : Strings.mfaMineOff,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: factor != null
                    ? TextButton.icon(
                        onPressed: () => _disable(factor),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        icon: const Icon(Icons.remove_moderator_outlined),
                        label: const Text(Strings.mfaDisable),
                      )
                    : AppButton(
                        label: Strings.mfaEnable,
                        icon: Icons.qr_code_2_rounded,
                        expanded: false,
                        onPressed: _enable,
                      ),
              ),
            ],
            title(Strings.mfaPolicyTitle),
            const Text(
              Strings.mfaPolicyHint,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (!admin)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  Strings.mfaPolicyOnlyAdmin,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              )
            else if (mine != null && !mine.isVerifiedSession)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  Strings.mfaPolicyNeedsOwn,
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            RadioGroup<int>(
              groupValue: _policy,
              onChanged: (v) {
                if (admin && !_saving && v != null) setState(() => _policy = v);
              },
              child: Column(
                children: [
                  for (final p in const [0, 1, 2])
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: p,
                      enabled: admin && !_saving,
                      title: Text(_label(p)),
                    ),
                ],
              ),
            ),
            if (admin)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: Strings.save,
                  expanded: false,
                  loading: _saving,
                  onPressed: _policy == widget.settings.itMfaPolicy
                      ? null
                      : _savePolicy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
