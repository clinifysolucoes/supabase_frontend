import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../application/finance_controllers.dart';
import '../domain/receivable_models.dart';

/// Planilha (CSV) dos recebimentos de pacientes num mes ou ano, para a
/// Receita Saude: lista o periodo, mostra o que ja foi exportado, deixa
/// escolher as linhas e, ao gerar, marca as escolhidas como exportadas.
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
  bool _onlyPending = true;
  bool _busy = false;
  String? _info;
  HealthExport? _list;
  final Set<int> _selected = {};

  DateTime get _from => _month == 0 ? DateTime(_year) : DateTime(_year, _month);
  DateTime get _to =>
      _month == 0 ? DateTime(_year, 12, 31) : DateTime(_year, _month + 1, 0);

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final x = await ref
          .read(financeActionsProvider)
          .healthExport(_from, _to, onlyPending: _onlyPending);
      if (!mounted) return;
      setState(() {
        _list = x;
        _selected
          ..clear()
          ..addAll([
            for (final r in x.rows)
              if (r.dhExported == null) r.nrEntry,
          ]);
        if (x.rows.isEmpty) _info = Strings.healthEmpty;
      });
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    if (_selected.isEmpty) {
      AppSnack.error(context, Strings.healthNoneSelected);
      return;
    }
    setState(() => _busy = true);
    try {
      final x = await ref
          .read(financeActionsProvider)
          .healthExport(_from, _to, entries: _selected.toList(), mark: true);
      final name =
          'receita_saude_$_year${_month == 0 ? '' : _month.toString().padLeft(2, '0')}';
      await FileDownload.saveCsv(name: name, bytes: x.toCsv());
      if (!mounted) return;
      AppSnack.success(
        context,
        Strings.healthDone(x.rows.length, Numbers.money(x.vlTotal)),
      );
      if (x.qtMissingCpf > 0) {
        setState(() => _info = Strings.healthMissingCpf(x.qtMissingCpf));
        await _load();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final rows = _list?.rows ?? const <HealthRow>[];
    final total = rows
        .where((r) => _selected.contains(r.nrEntry))
        .fold<double>(0, (s, r) => s + r.vlPaid);
    return AlertDialog(
      title: const Text(Strings.healthTitle),
      content: SizedBox(
        width: 560,
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
                    onChanged: (v) => setState(() {
                      _year = v ?? _year;
                      _list = null;
                    }),
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
                    onChanged: (v) => setState(() {
                      _month = v ?? _month;
                      _list = null;
                    }),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(Strings.healthOnlyPending),
              value: _onlyPending,
              onChanged: (v) => setState(() {
                _onlyPending = v ?? true;
                _list = null;
              }),
            ),
            if (rows.isNotEmpty) ...[
              Text(
                Strings.healthSelected(_selected.length, Numbers.money(total)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in rows)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selected.contains(r.nrEntry),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected.add(r.nrEntry);
                          } else {
                            _selected.remove(r.nrEntry);
                          }
                        }),
                        title: Text(
                          '${Dates.format(r.dtPaid)} · ${r.vcPatient}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            Numbers.money(r.vlPaid),
                            if ((r.vcPayerCpf ?? r.vcCpf) == null)
                              Strings.healthMissingCpf(1),
                            if (r.dhExported != null)
                              Strings.healthExportedOn(
                                Dates.format(r.dhExported),
                              ),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
        if (_list == null)
          AppButton(
            label: Strings.healthList,
            icon: Icons.search_rounded,
            expanded: false,
            loading: _busy,
            onPressed: _load,
          )
        else
          AppButton(
            label: Strings.healthGenerate,
            icon: Icons.download_rounded,
            expanded: false,
            loading: _busy,
            onPressed: rows.isEmpty ? null : _generate,
          ),
      ],
    );
  }
}
