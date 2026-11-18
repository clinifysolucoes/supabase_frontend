import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../domain/agenda_models.dart';

/// Resultado de uma gravacao que passa pelos bloqueios do paciente.
typedef BlockRun = ({bool done, PatientBlock? block});

/// Erros que o administrador pode liberar confirmando (regra 3).
bool isBlockConfirm(String key) =>
    key.endsWith('_CONFIRM') &&
    (key.startsWith('APPOINTMENT_DEBT') ||
        key.startsWith('APPOINTMENT_OPEN') ||
        key.startsWith('APPOINTMENT_CONTRACT') ||
        key == 'CLINICAL_EVOLUTION_CONFIRM');

/// Roda [run]; se o paciente tem pendencia que o administrador libera,
/// pergunta e roda de novo com override. done = false quando ele desistiu.
Future<BlockRun> runWithBlockConfirm(
  BuildContext context,
  Future<PatientBlock?> Function({bool override}) run,
) async {
  try {
    return (done: true, block: await run());
  } on AppError catch (e) {
    if (!isBlockConfirm(e.key) || !context.mounted) rethrow;
    final kind = PatientBlock.kindFromError(e.key, e.parameters);
    final amount = Numbers.money(e.parameters['Amount'] as num?);
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.blockConfirmTitle(kind),
      message: Strings.blockConfirmMessage(kind, amount),
      confirmLabel: Strings.blockConfirmAction,
      destructive: false,
    );
    if (!ok) return (done: false, block: null);
    return (done: true, block: await run(override: true));
  }
}

/// Aviso (regra 2): a gravacao passou, mas o paciente tem pendencia.
void showBlockWarning(ScaffoldMessengerState messenger, PatientBlock block) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        Strings.blockWarning(block.kind, Numbers.money(block.amount)),
      ),
      backgroundColor: AppColors.warning,
    ),
  );
}
