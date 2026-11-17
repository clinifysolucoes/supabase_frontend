import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';

/// Reenvio do lembrete quando o paciente nao confirma: quantas vezes (0 a 3)
/// e a cada quantas horas. Usado nos alertas de e-mail/SMS e do WhatsApp.
class ResendFields extends StatelessWidget {
  const ResendFields({
    super.key,
    required this.resend,
    required this.hours,
    required this.enabled,
    required this.onResend,
    required this.onHours,
  });

  final int resend;
  final int hours;
  final bool enabled;
  final ValueChanged<int> onResend;
  final ValueChanged<int> onHours;

  static const hourOptions = [1, 2, 3, 4, 6, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          Strings.resendTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const Text(
          Strings.resendHint,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final n in const [0, 1, 2, 3])
              ChoiceChip(
                label: Text(
                  n == 0 ? Strings.resendOff : Strings.resendTimes(n),
                ),
                selected: resend == n,
                onSelected: enabled ? (_) => onResend(n) : null,
              ),
            if (resend > 0)
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: hourOptions.contains(hours) ? hours : 4,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: Strings.resendEvery,
                  ),
                  items: [
                    for (final h in hourOptions)
                      DropdownMenuItem(
                        value: h,
                        child: Text(Strings.resendHours(h)),
                      ),
                  ],
                  onChanged: enabled ? (v) => onHours(v ?? hours) : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
