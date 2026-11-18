import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';

/// O que vai ser feito (it_kind de ad.access_request).
enum AccessKind {
  print(1),
  export(2);

  const AccessKind(this.code);

  final int code;
}

/// Abre o pedido de liberacao (ad.access_request); trocado nos testes.
final accessRequestProvider =
    Provider<Future<Map<String, dynamic>> Function(Map<String, dynamic>)>(
      (ref) =>
          (json) =>
              ref.read(supabaseGatewayProvider).rpc('access_request', json),
    );

/// Liberacao concedida: [uuRequest] null quando a empresa nao exige.
typedef AccessGrant = ({String? uuRequest});

/// Antes de imprimir ou exportar: se a empresa exige um administrador, pede o
/// e-mail e a senha dele e libera. Null = o usuario desistiu (nao continuar).
Future<AccessGrant?> ensureAccess(
  BuildContext context,
  WidgetRef ref, {
  required AccessKind kind,
  required String target,
}) async {
  final c = ref.read(currentCompanyProvider);
  final b = ref.read(currentBranchNumberProvider);
  if (c == null || b == null) return (uuRequest: null);
  final req = await ref.read(accessRequestProvider)({
    'nr_company': c,
    'nr_branch': b,
    'it_kind': kind.code,
    'vc_target': target,
  });
  if (req['id_required'] != true) return (uuRequest: null);
  final uu = req['uu_request'] as String;
  if (!context.mounted) return null;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminAuthDialog(kind: kind, uuRequest: uu, target: target),
  );
  return ok == true ? (uuRequest: uu) : null;
}

/// Pede o login de um administrador da empresa (sessao separada).
class AdminAuthDialog extends ConsumerStatefulWidget {
  const AdminAuthDialog({
    super.key,
    required this.kind,
    required this.uuRequest,
    required this.target,
  });

  final AccessKind kind;
  final String uuRequest;
  final String target;

  @override
  ConsumerState<AdminAuthDialog> createState() => _AdminAuthDialogState();
}

class _AdminAuthDialogState extends ConsumerState<AdminAuthDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      AppSnack.error(context, Strings.accessAuthFill);
      return;
    }
    setState(() => _saving = true);
    try {
      final admin = await ref
          .read(supabaseGatewayProvider)
          .authorizeAsAdmin(
            email: _email.text.trim(),
            password: _password.text,
            uuRequest: widget.uuRequest,
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.accessAuthDone(admin ?? ''));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.kind == AccessKind.print
            ? Strings.accessAuthPrintTitle
            : Strings.accessAuthExportTitle,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.accessAuthHint(widget.target)),
            const SizedBox(height: 12),
            AppTextField(
              label: Strings.accessAuthEmail,
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.admin_panel_settings_outlined,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: Strings.accessAuthPassword,
              controller: _password,
              enabled: !_saving,
              obscureText: _hide,
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.accessAuthConfirm,
          expanded: false,
          loading: _saving,
          onPressed: _saving ? null : _confirm,
        ),
      ],
    );
  }
}
