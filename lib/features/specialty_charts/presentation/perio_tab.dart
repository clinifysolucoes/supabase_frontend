import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../data/chart_repository.dart';
import '../domain/chart_models.dart';

/// Cor da profundidade de sondagem: ate 3 normal, 4-5 alerta, 6+ perigo.
Color perioColor(int? mm) => mm == null
    ? AppColors.muted
    : mm >= 6
    ? AppColors.danger
    : mm >= 4
    ? AppColors.warning
    : AppColors.ink;

/// Prontuario > Periograma: exames do paciente, grafico e resumo.
class PerioTab extends ConsumerStatefulWidget {
  const PerioTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  ConsumerState<PerioTab> createState() => _PerioTabState();
}

class _PerioTabState extends ConsumerState<PerioTab> {
  int? _selected;

  Future<void> _delete(PerioExam e) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.perioDeleteTitle,
      message: Strings.perioDeleteMessage(Dates.format(e.dtExam)),
      confirmLabel: Strings.delete,
    );
    if (!ok) return;
    try {
      await ref.read(chartRepositoryProvider).savePerio(widget.nrPatient, 'D', {
        'nr_exam': e.nrExam,
      });
      if (mounted) {
        setState(() => _selected = null);
        AppSnack.success(context, Strings.perioDeleted);
      }
    } catch (err) {
      if (mounted) AppSnack.error(context, describeError(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(perioExamsProvider(widget.nrPatient));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(perioExamsProvider(widget.nrPatient)),
      ),
      data: (d) {
        final exam = d.exams.isEmpty
            ? null
            : d.exams.where((e) => e.nrExam == _selected).firstOrNull ??
                  d.exams.first;
        return ListView(
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (d.canCreate)
                  AppButton(
                    label: Strings.perioNew,
                    icon: Icons.add_rounded,
                    expanded: false,
                    onPressed: () => PerioExamDialog.show(
                      context,
                      nrPatient: widget.nrPatient,
                      base: d.exams.firstOrNull,
                    ),
                  ),
                for (final e in d.exams)
                  ChoiceChip(
                    label: Text(Dates.format(e.dtExam)),
                    selected: exam?.nrExam == e.nrExam,
                    onSelected: (_) => setState(() => _selected = e.nrExam),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (exam == null)
              const AppEmptyState(
                icon: Icons.stacked_bar_chart_rounded,
                title: Strings.perioEmpty,
                subtitle: Strings.perioEmptyHint,
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        Dates.format(exam.dtExam),
                        if ((exam.vcProfessional ?? '').isNotEmpty)
                          exam.vcProfessional!,
                      ].join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (d.canUpdate) ...[
                    IconButton(
                      tooltip: Strings.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => PerioExamDialog.show(
                        context,
                        nrPatient: widget.nrPatient,
                        exam: exam,
                      ),
                    ),
                    IconButton(
                      tooltip: Strings.delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _delete(exam),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              PerioSummaryView(summary: exam.summary),
              const SizedBox(height: AppSpacing.md),
              PerioChartView(teeth: exam.teeth),
              if ((exam.vcNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(exam.vcNotes!),
              ],
            ],
          ],
        );
      },
    );
  }
}

class PerioSummaryView extends StatelessWidget {
  const PerioSummaryView({super.key, required this.summary});

  final PerioSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    String pc(double? v) => v == null ? '-' : Numbers.percent(v);
    String mm(double? v) =>
        v == null ? '-' : '${v.toStringAsFixed(1).replaceAll('.', ',')} mm';
    Widget kpi(String label, String value, {Color? color}) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color ?? AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        kpi(Strings.perioTeeth, '${s.qtTeeth}'),
        kpi(
          Strings.perioBleeding,
          pc(s.pcBleeding),
          color: (s.pcBleeding ?? 0) > 10 ? AppColors.danger : null,
        ),
        kpi(Strings.perioPlaque, pc(s.pcPlaque)),
        kpi(Strings.perioProbingMean, mm(s.vlProbingMean)),
        kpi(
          Strings.perioSites45,
          '${s.qtSites45}',
          color: s.qtSites45 > 0 ? AppColors.warning : null,
        ),
        kpi(
          Strings.perioSites6,
          '${s.qtSites6}',
          color: s.qtSites6 > 0 ? AppColors.danger : null,
        ),
        kpi(Strings.perioAttachmentMean, mm(s.vlAttachmentMean)),
      ],
    );
  }
}

/// Grafico do periograma: arcada superior e inferior, 3 pontos vestibulares
/// e 3 linguais por dente, com a cor da profundidade e o sangramento.
class PerioChartView extends StatelessWidget {
  const PerioChartView({super.key, required this.teeth, this.onTooth});

  final List<PerioTooth> teeth;
  final ValueChanged<String>? onTooth;

  PerioTooth? _of(String t) => teeth.where((x) => x.vcTooth == t).firstOrNull;

  Widget _site(int? v, bool? bleeding) => SizedBox(
    width: 15,
    child: Column(
      children: [
        Text(
          v == null ? '·' : '$v',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: perioColor(v),
          ),
        ),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bleeding == true ? AppColors.danger : Colors.transparent,
          ),
        ),
      ],
    ),
  );

  Widget _tooth(String t) {
    final x = _of(t);
    final missing = x?.idMissing ?? false;
    Widget row(int from) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = from; i < from + 3; i++)
          _site(
            missing ? null : x?.probing[i],
            missing ? null : x?.bleeding[i],
          ),
      ],
    );
    final extra = [
      if ((x?.itMobility ?? 0) > 0) 'M${x!.itMobility}',
      if ((x?.itFurcation ?? 0) > 0) 'F${x!.itFurcation}',
    ].join(' ');
    return InkWell(
      onTap: onTooth == null ? null : () => onTooth!(t),
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: missing ? AppColors.line.withValues(alpha: 0.5) : null,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            row(0),
            Text(
              missing ? '$t ✕' : t,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: missing ? AppColors.muted : AppColors.primaryDark,
              ),
            ),
            row(3),
            SizedBox(
              height: 12,
              child: Text(
                extra,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.perioUpper,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Row(children: [for (final t in perioUpper) _tooth(t)]),
            const SizedBox(height: AppSpacing.sm),
            Text(
              Strings.perioLower,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            Row(children: [for (final t in perioLower) _tooth(t)]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Strings.perioLegend,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Novo exame (opcionalmente partindo do ultimo) ou edicao.
class PerioExamDialog extends ConsumerStatefulWidget {
  const PerioExamDialog({
    super.key,
    required this.nrPatient,
    this.exam,
    this.base,
  });

  final int nrPatient;
  final PerioExam? exam;

  /// Exame anterior: os dentes ausentes vem marcados.
  final PerioExam? base;

  static Future<void> show(
    BuildContext context, {
    required int nrPatient,
    PerioExam? exam,
    PerioExam? base,
  }) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PerioExamDialog(nrPatient: nrPatient, exam: exam, base: base),
  );

  @override
  ConsumerState<PerioExamDialog> createState() => _PerioExamDialogState();
}

class _PerioExamDialogState extends ConsumerState<PerioExamDialog> {
  late final _date = TextEditingController(
    text: Dates.toField(widget.exam?.dtExam ?? DateTime.now()),
  );
  late final _notes = TextEditingController(text: widget.exam?.vcNotes ?? '');
  late int? _professional = widget.exam?.nrProfessional;
  late final Map<String, PerioTooth> _teeth = {
    for (final t in [...perioUpper, ...perioLower])
      t: widget.exam?.tooth(t) != null
          ? PerioTooth.fromJson(
              widget.exam!.tooth(t)!.toJson()..['vc_tooth'] = t,
            )
          : PerioTooth(
              vcTooth: t,
              idMissing: widget.base?.tooth(t)?.idMissing ?? false,
            ),
  };
  bool _saving = false;

  @override
  void dispose() {
    _date.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _editTooth(String t) async {
    final r = await PerioToothDialog.show(context, _teeth[t]!);
    if (r != null) setState(() => _teeth[t] = r);
  }

  Future<void> _save() async {
    final d = Dates.parseField(_date.text);
    if (d == null || d.isAfter(DateTime.now())) {
      AppSnack.error(context, Strings.invalidDate);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(chartRepositoryProvider).savePerio(
        widget.nrPatient,
        widget.exam == null ? 'I' : 'U',
        {
          if (widget.exam != null) 'nr_exam': widget.exam!.nrExam,
          'dt_exam': Dates.toIso(d),
          'nr_professional': _professional,
          'vc_notes': _notes.text.trim(),
          'teeth': [
            for (final t in _teeth.values)
              if (t.hasData) t.toJson(),
          ],
        },
      );
      if (!mounted) return;
      AppSnack.success(context, Strings.perioSaved);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final professionals = ref.watch(agendaProfessionalsProvider).valueOrNull;
    return AlertDialog(
      insetPadding: EdgeInsets.all(
        context.isMobile ? AppSpacing.sm : AppSpacing.lg,
      ),
      title: Text(widget.exam == null ? Strings.perioNew : Strings.perioEdit),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: 170,
                    child: AppTextField(
                      label: Strings.stockDate,
                      controller: _date,
                      mask: MaskType.date,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _professional,
                      decoration: const InputDecoration(
                        labelText: Strings.professional,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(Strings.notInformed),
                        ),
                        for (final p in professionals ?? const [])
                          DropdownMenuItem(
                            value: p.nrProfessional,
                            child: Text(
                              p.vcName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _professional = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                Strings.perioTapTooth,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xs),
              PerioChartView(
                teeth: _teeth.values.toList(),
                onTooth: _editTooth,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.notes,
                controller: _notes,
                maxLength: 2000,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(
          label: Strings.save,
          expanded: false,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Um dente: ausente, mobilidade, furca e os 6 pontos.
class PerioToothDialog extends StatefulWidget {
  const PerioToothDialog({super.key, required this.tooth});

  final PerioTooth tooth;

  static Future<PerioTooth?> show(BuildContext context, PerioTooth t) =>
      showDialog<PerioTooth>(
        context: context,
        builder: (_) => PerioToothDialog(tooth: t),
      );

  @override
  State<PerioToothDialog> createState() => _PerioToothDialogState();
}

class _PerioToothDialogState extends State<PerioToothDialog> {
  late final t = widget.tooth;
  late bool _missing = t.idMissing;
  late int? _mobility = t.itMobility;
  late int? _furcation = t.itFurcation;
  late final _probing = [
    for (final v in t.probing) TextEditingController(text: v?.toString() ?? ''),
  ];
  late final _recession = [
    for (final v in t.recession)
      TextEditingController(text: v?.toString() ?? ''),
  ];
  late final _bleeding = [for (final v in t.bleeding) v ?? false];
  late final _plaque = [for (final v in t.plaque) v ?? false];

  @override
  void dispose() {
    for (final c in [..._probing, ..._recession]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final probing = [for (final c in _probing) n(c)];
    final recession = [for (final c in _recession) n(c)];
    if (probing.any((v) => v != null && (v < 0 || v > 15)) ||
        recession.any((v) => v != null && (v < -5 || v > 15))) {
      AppSnack.error(context, Strings.perioValueInvalid);
      return;
    }
    Navigator.of(context).pop(
      PerioTooth(
        vcTooth: t.vcTooth,
        idMissing: _missing,
        itMobility: _mobility,
        itFurcation: _furcation,
        probing: probing,
        recession: recession,
        bleeding: [for (final b in _bleeding) b],
        plaque: [for (final b in _plaque) b],
      ),
    );
  }

  Widget _grid(String title, int from) {
    Widget cell(Widget w) => SizedBox(width: 58, child: w);
    Widget input(TextEditingController c) => Padding(
      padding: const EdgeInsets.all(2),
      child: TextField(
        controller: c,
        enabled: !_missing,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(isDense: true),
      ),
    );
    Widget toggle(List<bool> l, int i, Color color) => IconButton(
      onPressed: _missing ? null : () => setState(() => l[i] = !l[i]),
      icon: Icon(
        l[i] ? Icons.circle : Icons.circle_outlined,
        size: 16,
        color: l[i] ? color : AppColors.muted,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Row(
          children: [
            cell(const SizedBox()),
            for (final s in Strings.perioSiteNames.sublist(from, from + 3))
              cell(
                Text(
                  s,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
        Row(
          children: [
            cell(
              const Text(Strings.perioProbing, style: TextStyle(fontSize: 12)),
            ),
            for (var i = from; i < from + 3; i++) cell(input(_probing[i])),
          ],
        ),
        Row(
          children: [
            cell(
              const Text(
                Strings.perioRecession,
                style: TextStyle(fontSize: 12),
              ),
            ),
            for (var i = from; i < from + 3; i++) cell(input(_recession[i])),
          ],
        ),
        Row(
          children: [
            cell(
              const Text(
                Strings.perioBleedingShort,
                style: TextStyle(fontSize: 12),
              ),
            ),
            for (var i = from; i < from + 3; i++)
              cell(toggle(_bleeding, i, AppColors.danger)),
          ],
        ),
        Row(
          children: [
            cell(
              const Text(
                Strings.perioPlaqueShort,
                style: TextStyle(fontSize: 12),
              ),
            ),
            for (var i = from; i < from + 3; i++)
              cell(toggle(_plaque, i, AppColors.warning)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget grade(String label, int? value, ValueChanged<int?> on) => SizedBox(
      width: 150,
      child: DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem(value: null, child: Text('-')),
          for (var g = 0; g <= 3; g++)
            DropdownMenuItem(value: g, child: Text('$g')),
        ],
        onChanged: _missing ? null : on,
      ),
    );
    return AlertDialog(
      title: Text('${Strings.prosTooth} ${t.vcTooth}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.perioMissing),
              value: _missing,
              onChanged: (v) => setState(() => _missing = v),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                grade(
                  Strings.perioMobility,
                  _mobility,
                  (v) => setState(() => _mobility = v),
                ),
                grade(
                  Strings.perioFurcation,
                  _furcation,
                  (v) => setState(() => _furcation = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _grid(Strings.perioBuccal, 0),
            const SizedBox(height: AppSpacing.sm),
            _grid(Strings.perioLingual, 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        AppButton(label: Strings.perioToothOk, expanded: false, onPressed: _ok),
      ],
    );
  }
}
