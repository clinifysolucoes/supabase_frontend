import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../application/finance_controllers.dart';

/// Planilha (CSV) dos recebimentos de pacientes num mes ou ano, para a
/// Receita Saude.
class HealthExportDialog extends ConsumerStatefulWidget {
  const HealthExportDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const HealthExportDialog(),
  );

  @override
  ConsumerState<HealthExportDialog> createState() => _HealthExportDialogState();
}

class _HealthExportDialogState extends ConsumerState<HealthExportDialog> {
  late int _year = DateTime.now().year;

  /// 0 = ano inteiro.
  late int _month = DateTime.now().month;
  bool _busy = false;
  String? _info;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _info = null;
    });
    final from = _month == 0 ? DateTime(_year) : DateTime(_year, _month);
    final to = _month == 0
        ? DateTime(_year, 12, 31)
        : DateTime(_year, _month + 1, 0);
    try {
      final x = await ref.read(financeActionsProvider).healthExport(from, to);
      if (x.rows.isEmpty) {
        if (mounted) setState(() => _info = Strings.healthEmpty);
        return;
      }
      final name =
          'receita_saude_$_year${_month == 0 ? '' : _month.toString().padLeft(2, '0')}';
      await FileDownload.saveCsv(name: name, bytes: x.toCsv());
      if (!mounted) return;
      AppSnack.success(
        context,
        Strings.healthDone(x.rows.length, Numbers.money(x.vlTotal)),
      );
      setState(
        () => _info = x.qtMissingCpf > 0
            ? Strings.healthMissingCpf(x.qtMissingCpf)
            : null,
      );
      if (x.qtMissingCpf == 0) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    return AlertDialog(
      title: const Text(Strings.healthTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.healthHint,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: Strings.healthYear,
                    ),
                    items: [
                      for (var y = now; y >= now - 5; y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? _year),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _month,
                    decoration: const InputDecoration(
                      labelText: Strings.healthMonth,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text(Strings.healthWholeYear),
                      ),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(Strings.monthName(m)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _month = v ?? _month),
                  ),
                ),
              ],
            ),
            if (_info != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_info!, style: const TextStyle(color: AppColors.warning)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.close),
        ),
        AppButton(
          label: Strings.healthGenerate,
          icon: Icons.download_rounded,
          expanded: false,
          loading: _busy,
          onPressed: _generate,
        ),
      ],
    );
  }
}
