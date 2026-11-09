import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/files/file_download.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/application/agenda_controllers.dart';
import '../application/document_controllers.dart';
import '../data/document_pdf.dart';
import '../domain/document_models.dart';
import '../../signatures/data/signature_repository.dart';
import '../../signatures/domain/signature_models.dart';
import '../../signatures/presentation/signature_dialog.dart';

IconData documentIcon(DocumentKind k) => switch (k) {
  DocumentKind.certificate => Icons.medical_information_outlined,
  DocumentKind.prescription => Icons.medication_outlined,
  DocumentKind.contract => Icons.handshake_outlined,
  DocumentKind.attendance => Icons.event_available_outlined,
  DocumentKind.other => Icons.description_outlined,
};

/// Aba Documentos: documentos emitidos (PDF) e emissao a partir dos modelos.
class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.nrPatient});

  final int nrPatient;

  SignatureKey _sigKey(PatientDocument d) => (
    target: SignatureTarget.document,
    nrPatient: nrPatient,
    key: d.nrDocument,
  );

  Future<void> _sign(
    BuildContext context,
    WidgetRef ref,
    PatientDocumentList list,
    PatientDocument d,
  ) async {
    final signed = await SignatureDialog.show(
      context,
      signatureKey: _sigKey(d),
      title: d.vcTitle,
      patientName: list.patient.vcName,
      patientCpf: list.patient.vcCpf,
      canSign: list.canCreate,
    );
    if (signed) ref.invalidate(patientDocumentsProvider(nrPatient));
  }

  Future<void> _pdf(
    BuildContext context,
    WidgetRef ref,
    PatientDocumentList list,
    PatientDocument d,
  ) async {
    try {
      final sigs = d.qtSignatures == 0
          ? const <Signature>[]
          : (await ref.read(signatureRepositoryProvider).list(_sigKey(d)))
                .signatures;
      await FileDownload.savePdf(
        name: DocumentPdf.fileName(d),
        bytes: await DocumentPdf.build(
          d,
          patient: list.patient,
          issuer: list.issuer,
          signatures: sigs,
        ),
      );
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patientDocumentsProvider(nrPatient));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(patientDocumentsProvider(nrPatient)),
      ),
      data: (list) => ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Strings.tabDocuments,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (list.canCreate)
                AppButton(
                  expanded: false,
                  label: Strings.emitDocument,
                  icon: Icons.note_add_outlined,
                  onPressed: () => DocumentEmitDialog.show(context, nrPatient),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (list.documents.isEmpty)
            const AppEmptyState(
              icon: Icons.description_outlined,
              title: Strings.noDocuments,
              subtitle: Strings.noDocumentsHint,
            ),
          for (final d in list.documents)
            Card(
              child: ListTile(
                leading: Icon(documentIcon(d.kind), color: AppColors.primary),
                title: Text(
                  d.vcTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    Dates.format(d.dtDocument),
                    d.kind.label,
                    if (d.vcProfessional != null) d.vcProfessional!,
                    if (d.items.isNotEmpty)
                      Strings.medicationCount(d.items.length),
                  ].join(' · '),
                ),
                onTap: () => _pdf(context, ref, list, d),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.qtSignatures > 0 || list.canCreate)
                      TextButton.icon(
                        onPressed: () => _sign(context, ref, list, d),
                        icon: Icon(
                          d.qtSignatures > 0
                              ? Icons.verified_outlined
                              : Icons.draw_outlined,
                          size: 18,
                        ),
                        label: Text(
                          d.qtSignatures > 0
                              ? Strings.signedCount(d.qtSignatures)
                              : Strings.collectSignature,
                        ),
                      ),
                    IconButton(
                      tooltip: Strings.downloadPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => _pdf(context, ref, list, d),
                    ),
                    if (list.canUpdate)
                      IconButton(
                        tooltip: Strings.remove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          final ok = await AppConfirmDialog.show(
                            context,
                            title: Strings.deleteDocument,
                            message: Strings.deleteDocumentConfirm,
                            confirmLabel: Strings.remove,
                          );
                          if (!ok || !context.mounted) return;
                          try {
                            await ref
                                .read(documentActionsProvider)
                                .delete(nrPatient, d.nrDocument);
                            if (context.mounted) {
                              AppSnack.success(
                                context,
                                Strings.documentDeleted,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppSnack.error(context, describeError(e));
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Emissao de documento: modelo, profissional, extras do modelo, texto
/// preenchido (editavel) e, no receituario, os medicamentos.
class DocumentEmitDialog extends ConsumerStatefulWidget {
  const DocumentEmitDialog({super.key, required this.nrPatient});

  final int nrPatient;

  static Future<void> show(BuildContext context, int nrPatient) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => DocumentEmitDialog(nrPatient: nrPatient),
  );

  @override
  ConsumerState<DocumentEmitDialog> createState() => _DocumentEmitDialogState();
}

class _MedRow {
  _MedRow(this.med)
    : dosage = TextEditingController(text: med.vcDosage ?? ''),
      quantity = TextEditingController(text: med.vcQuantity ?? '');

  final Medication med;
  final TextEditingController dosage;
  final TextEditingController quantity;
  late MedicationUse use = med.use;

  Map<String, dynamic> toJson() => med
      .copyWith(
        vcDosage: dosage.text.trim(),
        vcQuantity: quantity.text.trim(),
        use: use,
      )
      .toItemJson();
}

class _DocumentEmitDialogState extends ConsumerState<DocumentEmitDialog> {
  DocumentTemplate? _template;
  int? _nrProfessional;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final Map<String, TextEditingController> _extra = {};
  final List<_MedRow> _meds = [];
  bool _busy = false;
  TextEditingController? _medSearch;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final c in _extra.values) {
      c.dispose();
    }
    for (final m in _meds) {
      m.dosage.dispose();
      m.quantity.dispose();
    }
    super.dispose();
  }

  bool get _isPrescription => _template?.kind == DocumentKind.prescription;

  TextEditingController _ext(String k) =>
      _extra.putIfAbsent(k, TextEditingController.new);

  Map<String, String> get _extras => {
    for (final e in _extra.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
  };

  void _pick(DocumentTemplate t) {
    setState(() {
      _template = t;
      _title.text = t.vcName;
      _body.clear();
    });
    _fill();
  }

  Future<void> _fill() async {
    final t = _template;
    if (t == null) return;
    setState(() => _busy = true);
    try {
      final text = await ref
          .read(documentActionsProvider)
          .render(
            widget.nrPatient,
            nrTemplate: t.nrTemplate,
            nrProfessional: _nrProfessional,
            extra: _extras,
          );
      if (mounted) _body.text = text;
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final t = _template;
    if (t == null) return;
    if (_isPrescription && _meds.isEmpty) {
      AppSnack.error(context, Strings.medicationsRequired);
      return;
    }
    if (!_isPrescription && _body.text.trim().isEmpty) {
      AppSnack.error(context, Strings.documentBodyRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(documentActionsProvider).emit(widget.nrPatient, {
        'it_kind': t.kind.code,
        'nr_template': t.nrTemplate,
        'vc_title': _title.text.trim().isEmpty ? t.vcName : _title.text.trim(),
        'vc_body': _body.text.trim(),
        'nr_professional': ?_nrProfessional,
        'dt_document': Dates.toIso(DateTime.now()),
        if (_isPrescription) 'items': [for (final m in _meds) m.toJson()],
      });
      if (!mounted) return;
      AppSnack.success(context, Strings.documentSaved);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(documentTemplatesProvider(false));
    final professionals = ref
        .watch(professionalsProvider)
        .valueOrNull
        ?.professionals
        .where((p) => p.isActive)
        .toList();
    final meds =
        ref.watch(medicationsProvider(false)).valueOrNull?.medications ??
        const <Medication>[];
    final t = _template;
    return AlertDialog(
      title: const Text(Strings.emitDocument),
      content: SizedBox(
        width: 720,
        child: templates.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(describeError(e)),
          data: (list) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final x in list.templates)
                      ChoiceChip(
                        avatar: Icon(documentIcon(x.kind), size: 18),
                        label: Text(x.vcName),
                        selected: t?.nrTemplate == x.nrTemplate,
                        onSelected: _busy ? null : (_) => _pick(x),
                      ),
                  ],
                ),
                if (t != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: Strings.documentTitle,
                          controller: _title,
                          maxLength: 120,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _nrProfessional,
                          isExpanded: true,
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
                                child: Text(p.vcName),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() => _nrProfessional = v);
                            _fill();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (t.extras.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final e in t.extras)
                          SizedBox(
                            width: e == 'texto' ? 680 : 160,
                            child: AppTextField(
                              label: Strings.documentExtra(e),
                              controller: _ext(e),
                              onFieldSubmitted: (_) => _fill(),
                            ),
                          ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _fill,
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text(Strings.fillDocument),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: _isPrescription
                        ? Strings.prescriptionHeader
                        : Strings.documentText,
                    controller: _body,
                    minLines: _isPrescription ? 2 : 8,
                    maxLines: 18,
                    maxLength: 20000,
                  ),
                  if (_isPrescription) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Autocomplete<Medication>(
                      displayStringForOption: (m) => m.isTyped
                          ? Strings.medicationTyped(m.vcName)
                          : m.title,
                      optionsBuilder: (v) {
                        final typed = v.text.trim();
                        final q = typed.toLowerCase();
                        if (q.isEmpty) {
                          return const Iterable<Medication>.empty();
                        }
                        return [
                          ...meds
                              .where((m) => m.title.toLowerCase().contains(q))
                              .take(12),
                          // sempre da para usar o que foi digitado
                          if (typed.length >= 3)
                            Medication(
                              vcName: typed.substring(
                                0,
                                typed.length > 120 ? 120 : typed.length,
                              ),
                            ),
                        ];
                      },
                      onSelected: (m) {
                        setState(() => _meds.add(_MedRow(m)));
                        // limpa a busca para o proximo medicamento
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _medSearch?.clear(),
                        );
                      },
                      fieldViewBuilder: (context, ctl, focus, submit) {
                        _medSearch = ctl;
                        return TextField(
                          controller: ctl,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            labelText: Strings.addMedication,
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onSubmitted: (_) => submit(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final (i, m) in _meds.indexed)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.med.isTyped
                                          ? '${i + 1}. ${m.med.title}'
                                          : '${i + 1}. ${m.med.title} · ${m.med.use.label}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (m.med.isTyped)
                                    DropdownButton<MedicationUse>(
                                      value: m.use,
                                      underline: const SizedBox.shrink(),
                                      items: [
                                        for (final u in MedicationUse.values)
                                          DropdownMenuItem(
                                            value: u,
                                            child: Text(u.label),
                                          ),
                                      ],
                                      onChanged: (u) =>
                                          setState(() => m.use = u ?? m.use),
                                    ),
                                  if (m.med.idControlled)
                                    const Tooltip(
                                      message: Strings.controlledMedication,
                                      child: Icon(
                                        Icons.policy_outlined,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: Strings.remove,
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () =>
                                        setState(() => _meds.removeAt(i)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: AppTextField(
                                      label: Strings.dosage,
                                      controller: m.dosage,
                                      maxLength: 300,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: AppTextField(
                                      label: Strings.quantity,
                                      controller: m.quantity,
                                      maxLength: 60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          expanded: false,
          label: Strings.cancel,
          variant: AppButtonVariant.text,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        AppButton(
          expanded: false,
          label: Strings.emitDocument,
          loading: _busy,
          onPressed: t == null ? null : _save,
        ),
      ],
    );
  }
}
