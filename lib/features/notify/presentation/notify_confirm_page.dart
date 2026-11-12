import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../data/notify_repository.dart';
import '../domain/notify_models.dart';

/// Pagina publica do link do lembrete por e-mail/SMS (`/confirmar/<token>`),
/// sem login: confirma a consulta e mostra o resultado.
class NotifyConfirmPage extends ConsumerStatefulWidget {
  const NotifyConfirmPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<NotifyConfirmPage> createState() => _NotifyConfirmPageState();
}

class _NotifyConfirmPageState extends ConsumerState<NotifyConfirmPage> {
  NotifyConfirmResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final r = await ref.read(notifyRepositoryProvider).confirm(widget.token);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: NotifyConfirmView(
                  result: _result,
                  error: _error,
                  onRetry: _run,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Conteudo da confirmacao (separado para testar sem rede).
class NotifyConfirmView extends StatelessWidget {
  const NotifyConfirmView({super.key, this.result, this.error, this.onRetry});

  final NotifyConfirmResult? result;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: AppSpacing.md),
          Text(error!, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
      );
    }
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final (icon, color, title) = switch (r.itResult) {
      1 => (
        Icons.check_circle_rounded,
        AppColors.success,
        Strings.ntConfirmDone,
      ),
      2 => (
        Icons.check_circle_outline_rounded,
        AppColors.success,
        Strings.ntConfirmAlready,
      ),
      3 => (
        Icons.event_busy_rounded,
        AppColors.warning,
        Strings.ntConfirmUnavailable,
      ),
      _ => (Icons.link_off_rounded, AppColors.danger, Strings.ntConfirmInvalid),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (r.itResult != 0 && r.vcDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.ntConfirmDetail(
              r.vcPatient ?? '',
              r.vcDate!,
              r.vcTime ?? '',
              r.vcProfessional,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (r.itResult == 3)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              Strings.ntConfirmContact,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if ((r.vcClinic ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            r.vcClinic!,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
