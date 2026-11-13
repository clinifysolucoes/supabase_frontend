import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../data/chart_repository.dart';
import '../domain/chart_models.dart';

/// Prontuario > Fichas: fichas por especialidade do paciente.
class SpecialtyChartsTab extends ConsumerStatefulWidget {
  const SpecialtyChartsTab({super.key, required this.nrPatient});

  final int nrPatient;

  @override
  ConsumerState<SpecialtyChartsTab> createState() => _SpecialtyChartsTabState();
}

class _SpecialtyChartsTabState extends ConsumerState<SpecialtyChartsTab> {
  /// Filtro por nome do modelo (null = todas).
  String? _filter;

  Future<void> _new(List<ChartModel> models) async {
    final m = await showDialog<ChartModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(Strings.chartChoose),
        children: [
          for (final x in models)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(x),
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(x.vcName),
                subtitle: x.idPerTooth
                    ? const Text(Strings.chartPerTooth)
                    : null,
              ),
            ),
        ],
      ),
    );
    if (m != null && mounted) {
      await PatientChartDialog.show(
        context,
        nrPatient: widget.nrPatient,
        model: m,
      );
    }
  }

  Future<void> _delete(PatientChart c) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.chartDeleteTitle,
      message: Strings.chartDeleteMessage(c.vcModel),
      confirmLabel: Strings.delete,
    );
    if (!ok) return;
    try {
      await ref.read(chartRepositoryProvider).saveChart(widget.nrPatient, 'D', {
        'nr_chart': c.nrChart,
      });
      if (mounted) AppSnack.success(context, Strings.chartDeleted);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final charts = ref.watch(patientChartsProvider(widget.nrPatient));
    final models = ref.watch(chartModelsProvider(false)).valueOrNull?.models;
    return charts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(patientChartsProvider(widget.nrPatient)),
      ),
      data: (d) {
        final names = {for (final c in d.charts) c.vcModel}.toList()..sort();
        final shown = [
          for (final c in d.charts)
            if (_filter == null || c.vcModel == _filter) c,
        ];
        return ListView(
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (d.canCreate && (models?.isNotEmpty ?? false))
                  AppButton(
                    label: Strings.chartNew,
                    icon: Icons.add_rounded,
                    expanded: false,
                    onPressed: () => _new(models!),
                  ),
                if (names.length > 1) ...[
                  ChoiceChip(
                    label: const Text(Strings.trashAll),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final n in names)
                    ChoiceChip(
                      label: Text(n),
                      selected: _filter == n,
                      onSelected: (_) => setState(() => _filter = n),
                    ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (shown.isEmpty)
              const AppEmptyState(
                icon: Icons.fact_check_outlined,
                title: Strings.chartEmpty,
                subtitle: Strings.chartEmptyHint,
              )
            else
              for (final c in shown)
                PatientChartCard(
                  chart: c,
                  canUpdate: d.canUpdate,
                  onEdit: () {
                    final m = models
                        ?.where((x) => x.nrModel == c.nrModel)
                        .firstOrNull;
                    PatientChartDialog.show(
                      context,
                      nrPatient: widget.nrPatient,
                      model: m,
                      chart: c,
                    );
                  },
                  onDelete: () => _delete(c),
                ),
          ],
        );
      },
    );
  }
}

/// Cartao de uma ficha preenchida.
class PatientChartCard extends StatelessWidget {
  const PatientChartCard({
    super.key,
    required this.chart,
    this.canUpdate = false,
    this.onEdit,
    this.onDelete,
  });

  final PatientChart chart;
  final bool canUpdate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = chart;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(
            Icons.fact_check_outlined,
            color: AppColors.primary,
          ),
          title: Text(
            [
              c.vcModel,
              if ((c.vcTooth ?? '').isNotEmpty)
                '${Strings.prosTooth} ${c.vcTooth}',
            ].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              Dates.format(c.dtChart),
              if ((c.vcProfessional ?? '').isNotEmpty) c.vcProfessional!,
              Strings.chartFilledCount(c.filled.length),
            ].join(' · '),
          ),
          trailing: canUpdate
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: Strings.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: Strings.delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: onDelete,
                    ),
                  ],
                )
              : null,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            for (final v in c.values)
              if (v.type == ChartFieldType.section)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    v.vcLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                )
              else if ((v.vcValue ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${v.vcLabel}: ',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        TextSpan(text: v.display),
                      ],
                    ),
                  ),
                ),
            if ((c.vcNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(c.vcNotes!),
            ],
            if ((c.vcUser ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  Strings.chartBy(c.vcUser!),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Preenche (ou altera) uma ficha. Na alteracao usa a copia dos campos.
class PatientChartDialog extends ConsumerStatefulWidget {
  const PatientChartDialog({
    super.key,
    required this.nrPatient,
    this.model,
    this.chart,
  });

  final int nrPatient;
  final ChartModel? model;
  final PatientChart? chart;

  static Future<void> show(
    BuildContext context, {
    required int nrPatient,
    ChartModel? model,
    PatientChart? chart,
  }) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PatientChartDialog(nrPatient: nrPatient, model: model, chart: chart),
  );

  @override
  ConsumerState<PatientChartDialog> createState() => _PatientChartDialogState();
}

class _PatientChartDialogState extends ConsumerState<PatientChartDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _date = TextEditingController(
    text: Dates.toField(widget.chart?.dtChart ?? DateTime.now()),
  );
  late final _tooth = TextEditingController(text: widget.chart?.vcTooth ?? '');
  late final _notes = TextEditingController(text: widget.chart?.vcNotes ?? '');
  late int? _professional = widget.chart?.nrProfessional;
  final Map<int, TextEditingController> _text = {};
  final Map<int, String?> _pick = {};
  bool _saving = false;

  /// Campos: os da copia (alteracao) ou os do modelo (nova ficha).
  late final List<
    ({
      int nr,
      String label,
      ChartFieldType type,
      List<String> options,
      String? unit,
      bool required,
    })
  >
  _fields = widget.chart != null
      ? [
          for (final v in widget.chart!.values)
            (
              nr: v.nrField,
              label: v.vcLabel,
              type: v.type,
              options:
                  widget.model?.fields
                      .where(
                        (f) => f.nrField == v.nrField && f.vcLabel == v.vcLabel,
                      )
                      .firstOrNull
                      ?.options ??
                  const <String>[],
              unit: v.vcUnit,
              required: false,
            ),
        ]
      : [
          for (final f in widget.model?.fields ?? const <ChartField>[])
            (
              nr: f.nrField,
              label: f.vcLabel,
              type: f.type,
              options: f.options,
              unit: f.vcUnit,
              required: f.idRequired,
            ),
        ];

  bool get _perTooth =>
      widget.model?.idPerTooth ?? (widget.chart?.vcTooth != null);

  @override
  void initState() {
    super.initState();
    final existing = {
      for (final v in widget.chart?.values ?? const <ChartValue>[])
        v.nrField: v,
    };
    for (final f in _fields) {
      final v = existing[f.nr]?.vcValue;
      switch (f.type) {
        case ChartFieldType.yesNo || ChartFieldType.choice:
          _pick[f.nr] = v;
        case ChartFieldType.date:
          _text[f.nr] = TextEditingController(
            text: v == null ? '' : Dates.toField(DateTime.tryParse(v)),
          );
        case ChartFieldType.number:
          _text[f.nr] = TextEditingController(
            text: v?.replaceAll('.', ',') ?? '',
          );
        case ChartFieldType.section:
          break;
        default:
          _text[f.nr] = TextEditingController(text: v ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_date, _tooth, _notes, ..._text.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _valueOf(int nr, ChartFieldType type) {
    if (type == ChartFieldType.yesNo || type == ChartFieldType.choice) {
      return _pick[nr];
    }
    final t = _text[nr]?.text.trim() ?? '';
    if (t.isEmpty) return null;
    if (type == ChartFieldType.date) {
      final d = Dates.parseField(t);
      return d == null ? t : Dates.toIso(d);
    }
    return t;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final values = [
      for (final f in _fields)
        if (f.type != ChartFieldType.section)
          {'nr_field': f.nr, 'vc_value': _valueOf(f.nr, f.type)},
    ];
    final date = Dates.parseField(_date.text) ?? DateTime.now();
    try {
      await ref
          .read(chartRepositoryProvider)
          .saveChart(widget.nrPatient, widget.chart == null ? 'I' : 'U', {
            if (widget.chart == null) 'nr_model': widget.model!.nrModel,
            if (widget.chart != null) 'nr_chart': widget.chart!.nrChart,
            'dt_chart': Dates.toIso(date),
            'vc_tooth': _tooth.text.trim(),
            'nr_professional': _professional,
            'vc_notes': _notes.text.trim(),
            'values': values,
          });
      if (!mounted) return;
      AppSnack.success(context, Strings.chartSaved);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  Widget _field(
    ({
      int nr,
      String label,
      ChartFieldType type,
      List<String> options,
      String? unit,
      bool required,
    })
    f,
  ) {
    final label = f.required ? '${f.label} *' : f.label;
    String? req(String? v) =>
        f.required && (v ?? '').trim().isEmpty ? Strings.chartRequired : null;
    switch (f.type) {
      case ChartFieldType.section:
        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            f.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        );
      case ChartFieldType.yesNo:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              for (final o in const [('S', Strings.yes), ('N', Strings.no)])
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(o.$2),
                    selected: _pick[f.nr] == o.$1,
                    onSelected: (s) =>
                        setState(() => _pick[f.nr] = s ? o.$1 : null),
                  ),
                ),
            ],
          ),
        );
      case ChartFieldType.choice:
        final opts = {...f.options, ?_pick[f.nr]}.toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: _pick[f.nr],
            decoration: InputDecoration(labelText: label),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text(Strings.notInformed),
              ),
              for (final o in opts)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (v) => req(v),
            onChanged: (v) => setState(() => _pick[f.nr] = v),
          ),
        );
      case ChartFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppTextField(
            label: (f.unit ?? '').isEmpty ? label : '$label (${f.unit})',
            controller: _text[f.nr],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final r = req(v);
              if (r != null) return r;
              final t = (v ?? '').trim();
              return t.isEmpty || num.tryParse(t.replaceAll(',', '.')) != null
                  ? null
                  : Strings.chartNumberInvalid;
            },
          ),
        );
      case ChartFieldType.date:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppTextField(
            label: label,
            controller: _text[f.nr],
            mask: MaskType.date,
            keyboardType: TextInputType.number,
            validator: (v) {
              final r = req(v);
              if (r != null) return r;
              return (v ?? '').trim().isEmpty || Dates.parseField(v) != null
                  ? null
                  : Strings.invalidDate;
            },
          ),
        );
      default:
        final long = f.type == ChartFieldType.longText;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppTextField(
            label: label,
            controller: _text[f.nr],
            maxLength: long ? 2000 : 200,
            maxLines: long ? 3 : 1,
            validator: req,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final professionals = ref.watch(agendaProfessionalsProvider).valueOrNull;
    final title = widget.chart?.vcModel ?? widget.model?.vcName ?? '';
    return AlertDialog(
      insetPadding: EdgeInsets.all(
        context.isMobile ? AppSpacing.sm : AppSpacing.xl,
      ),
      title: Text(title),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
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
                        validator: (v) {
                          final d = Dates.parseField(v);
                          if (d == null) return Strings.invalidDate;
                          return d.isAfter(DateTime.now())
                              ? Strings.prosFutureDate
                              : null;
                        },
                      ),
                    ),
                    if (_perTooth || _tooth.text.isNotEmpty)
                      SizedBox(
                        width: 170,
                        child: AppTextField(
                          label: _perTooth
                              ? '${Strings.prosTooth} *'
                              : Strings.prosTooth,
                          hint: Strings.chartToothHint,
                          controller: _tooth,
                          validator: (v) =>
                              _perTooth && (v ?? '').trim().isEmpty
                              ? Strings.chartRequired
                              : null,
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
                          if (_professional != null &&
                              !(professionals ?? const []).any(
                                (p) => p.nrProfessional == _professional,
                              ))
                            DropdownMenuItem(
                              value: _professional,
                              child: Text(widget.chart?.vcProfessional ?? '-'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _professional = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final f in _fields) _field(f),
                AppTextField(
                  label: Strings.notes,
                  controller: _notes,
                  maxLength: 2000,
                  maxLines: 3,
                ),
              ],
            ),
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
