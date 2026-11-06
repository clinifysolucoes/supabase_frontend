import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/mfa_types.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/session_controller.dart';

/// Login com 2FA: cadastra o app autenticador (QR code) ou pede o codigo de
/// 6 digitos; depois recarrega a sessao com o segundo fator confirmado.
class MfaPage extends ConsumerWidget {
  const MfaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppLogo(size: 32),
                      const SizedBox(height: AppSpacing.lg),
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 44,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        Strings.mfaTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MfaPanel(
                        onDone: () => ref
                            .read(sessionControllerProvider.notifier)
                            .afterMfa(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => ref
                            .read(sessionControllerProvider.notifier)
                            .signOut(),
                        child: const Text(Strings.mfaUseOtherAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conteudo do 2FA: com fator verificado pede o codigo; sem, mostra o QR
/// code do cadastro e confirma o primeiro codigo. [voluntary] = ativado pelo
/// proprio usuario (Configuracoes), nao exigido pela clinica.
class MfaPanel extends ConsumerStatefulWidget {
  const MfaPanel({super.key, required this.onDone, this.voluntary = false});

  final VoidCallback onDone;
  final bool voluntary;

  @override
  ConsumerState<MfaPanel> createState() => _MfaPanelState();
}

class _MfaPanelState extends ConsumerState<MfaPanel> {
  final _code = TextEditingController();
  String? _factorId;
  MfaEnrollment? _enrollment;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  SupabaseGateway get _gateway => ref.read(supabaseGatewayProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final status = await _gateway.mfaStatus();
      final verified = status.verifiedFactor;
      if (verified != null) {
        _factorId = verified.id;
      } else {
        final e = await _gateway.mfaEnroll(issuer: 'Clinify');
        _enrollment = e;
        _factorId = e.factorId;
      }
    } catch (e) {
      _error = describeError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    final id = _factorId;
    if (code.length != 6 || id == null) {
      setState(() => _error = Strings.mfaCodeInvalidLocal);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _gateway.mfaVerify(factorId: id, code: code);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final e = _enrollment;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          e == null
              ? Strings.mfaVerifyHint
              : (widget.voluntary
                    ? Strings.mfaEnrollHintVoluntary
                    : Strings.mfaEnrollHint),
          style: const TextStyle(color: AppColors.muted),
        ),
        if (e != null) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: SvgPicture.string(e.qrSvg, width: 180, height: 180),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            Strings.mfaSecretLabel,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          SelectableText(
            e.secret,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: Strings.mfaCode,
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          enabled: !_saving,
          onFieldSubmitted: (_) => _confirm(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: Strings.mfaConfirm,
          icon: Icons.lock_open_rounded,
          loading: _saving,
          onPressed: _factorId == null ? null : _confirm,
        ),
      ],
    );
  }
}
