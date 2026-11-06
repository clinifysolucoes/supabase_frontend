import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../application/clinical_record_controllers.dart';
import '../domain/clinical_record_models.dart';

/// Carrega o prontuario do paciente e entrega ao [builder].
class RecordLoader extends ConsumerWidget {
  const RecordLoader({
    super.key,
    required this.nrPatient,
    required this.builder,
  });

  final int nrPatient;
  final Widget Function(BuildContext context, PatientClinicalRecord record)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clinicalRecordProvider(nrPatient));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(clinicalRecordProvider(nrPatient)),
      ),
      data: (r) => builder(context, r),
    );
  }
}

/// Faixa vermelha com os alertas da anamnese mais recente.
class RecordAlerts extends StatelessWidget {
  const RecordAlerts({super.key, required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.recordAlerts,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                for (final a in alerts) Text('• $a'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Executa uma escrita mostrando sucesso/erro.
Future<bool> runRecordAction(
  BuildContext context,
  Future<void> Function() action,
  String success,
) async {
  try {
    await action();
    if (context.mounted) AppSnack.success(context, success);
    return true;
  } catch (e) {
    if (context.mounted) AppSnack.error(context, describeError(e));
    return false;
  }
}

/// Titulo de secao com acao opcional a direita.
class RecordSectionTitle extends StatelessWidget {
  const RecordSectionTitle({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}
