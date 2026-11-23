import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../application/credit_controllers.dart';
import '../domain/credit_models.dart';

/// Card "Consulta de credito" da ficha do paciente: a ultima consulta, o
/// botao para consultar (com a autorizacao do paciente) e o historico.
/// Some quando a consulta esta desligada na filial e nunca foi usada.
class CreditCheckCard extends ConsumerWidget {
  const CreditCheckCard({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(creditCheckListProvider(nrPatient)).valueOrNull;
    if (d == null || (!d.idEnabled && d.checks.isEmpty)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.creditTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (d.idEnabled && d.idCanCheck)
                  AppButton(
                    label: Strings.creditRun,
                    icon: Icons.manage_search_rounded,
                    variant: AppButtonVariant.text,
                    expanded: false,
                    onPressed: () => _CreditConsentDialog.show(
                      context,
                      nrPatient: nrPatient,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (d.checks.isEmpty)
              const Text(
                Strings.creditNone,
                style: TextStyle(color: AppColors.muted),
              ),
            for (final c in d.checks.take(5)) _CheckTile(check: c),
          ],
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});

  final CreditCheck check;

  @override
  Widget build(BuildContext context) {
    final c = check;
    final color = c.isError
        ? AppColors.muted
        : !c.isDone
        ? AppColors.warning
        : c.hasRestrictions
        ? AppColors.danger
        : const Color(0xFF2E9E6B);
    final icon = c.isError
        ? Icons.error_outline_rounded
        : !c.isDone
        ? Icons.hourglass_top_rounded
        : c.hasRestrictions
        ? Icons.report_gmailerrorred_rounded
        : Icons.verified_rounded;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        c.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          if (c.isDone && c.qtScore != null) Strings.creditScore(c.qtScore!),
          if (c.isDone && c.hasRestrictions)
            Strings.creditDebts(c.qtDebts ?? 0, Numbers.money(c.vlDebts)),
          [
            CreditProvider.label(c.itProvider),
            if (c.dhCreated != null) Dates.formatTime(c.dhCreated!),
            if (c.vcUser != null) c.vcUser!,
          ].join(' · '),
        ].join('\n'),
      ),
    );
  }
}

/// Confirma a autorizacao do paciente (LGPD) antes de consultar.
class _CreditConsentDialog extends ConsumerStatefulWidget {
  const _CreditConsentDialog({required this.nrPatient});

  final int nrPatient;

  static Future<void> show(BuildContext context, {required int nrPatient}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreditConsentDialog(nrPatient: nrPatient),
      );

  @override
  ConsumerState<_CreditConsentDialog> createState() =>
      _CreditConsentDialogState();
}

class _CreditConsentDialogState extends ConsumerState<_CreditConsentDialog> {
  bool _consent = false;
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final r = await ref.read(creditCheckRunProvider)(widget.nrPatient);
      if (!mounted) return;
      Navigator.of(context).pop();
      if ((r['it_status'] as num?)?.toInt() == 2) {
        AppSnack.success(context, Strings.creditDone);
      } else {
        AppSnack.error(
          context,
          Strings.errorMessage(
            r['Message'] as String? ?? '',
            const {},
            Strings.creditError,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _running = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.creditRun),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(Strings.creditConsentHint),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(Strings.creditConsent),
              value: _consent,
              onChanged: _running
                  ? null
                  : (v) => setState(() => _consent = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.creditRun,
          expanded: false,
          loading: _running,
          onPressed: _consent && !_running ? _run : null,
        ),
      ],
    );
  }
}
