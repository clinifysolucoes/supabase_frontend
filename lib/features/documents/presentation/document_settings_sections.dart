import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/document_controllers.dart';
import '../domain/document_models.dart';
import 'documents_tab.dart';

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.title,
    required this.hint,
    required this.children,
    this.action,
  });

  final String title;
  final String hint;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Configuracoes > Prontuario: modelos de documento.
class DocumentTemplatesSection extends ConsumerWidget {
  const DocumentTemplatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentTemplatesProvider(true));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (list) => _SectionFrame(
        title: Strings.documentTemplates,
        hint: Strings.documentTemplatesHint,
        action: list.canUpdate
            ? AppButton(
                label: Strings.newModel,
                icon: Icons.add_rounded,
                onPressed: () =>
                    DocumentTemplateDialog.show(context, fields: list.fields),
              )
            : null,
        children: [
          for (final t in list.templates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                documentIcon(t.kind),
                color: t.isActive ? AppColors.primary : AppColors.muted,
              ),
              title: Text(t.vcName),
              subtitle: Text(
                [
                  t.kind.label,
                  if (!t.isActive) Strings.statusInactive,
                ].join(' · '),
              ),
              trailing: list.canUpdate ? const Icon(Icons.edit_outlined) : null,
              onTap: list.canUpdate
                  ? () => DocumentTemplateDialog.show(
                      context,
                      template: t,
                      fields: list.fields,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class DocumentTemplateDialog extends ConsumerStatefulWidget {
  const DocumentTemplateDialog({
    super.key,
    this.template,
    this.fields = const [],
  });

  final DocumentTemplate? template;
  final List<String> fields;

  static Future<void> show(
    BuildContext context, {
    DocumentTemplate? template,
    List<String> fields = const [],
  }) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => DocumentTemplateDialog(template: template, fields: fields),
  );

  @override
  ConsumerState<DocumentTemplateDialog> createState() =>
      _DocumentTemplateDialogState();
}

class _DocumentTemplateDialogState
    extends ConsumerState<DocumentTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.template?.vcName ?? '');
  late final _body = TextEditingController(text: widget.template?.vcBody ?? '');
  late DocumentKind _kind = widget.template?.kind ?? DocumentKind.other;
  late bool _active = widget.template?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  void _insert(String field) {
    final tag = '{{$field}}';
    final sel = _body.selection;
    final text = _body.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, tag),
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(documentActionsProvider)
          .saveTemplate(
            nrTemplate: widget.template?.nrTemplate,
            fields: {
              'it_kind': _kind.code,
              'vc_name': _name.text.trim(),
              'vc_body': _body.text,
              'it_status': _active ? 1 : 90,
            },
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.savedSuccess);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.template == null ? Strings.newModel : Strings.editModel),
    content: SizedBox(
      width: 720,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: Strings.modelName,
                      controller: _name,
                      maxLength: 80,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? Strings.required
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<DocumentKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: Strings.documentKind,
                      ),
                      items: [
                        for (final k in DocumentKind.values)
                          DropdownMenuItem(value: k, child: Text(k.label)),
                      ],
                      onChanged: (v) => setState(() => _kind = v!),
                    ),
                  ),
                ],
              ),
              if (widget.template != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(Strings.statusActive),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.documentFieldsHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final f in widget.fields)
                    ActionChip(
                      label: Text('{{$f}}'),
                      onPressed: () => _insert(f),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.documentText,
                controller: _body,
                minLines: 10,
                maxLines: 22,
                maxLength: 20000,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? Strings.required : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      AppButton(
        label: Strings.cancel,
        variant: AppButtonVariant.text,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      AppButton(label: Strings.save, loading: _saving, onPressed: _save),
    ],
  );
}

/// Configuracoes > Prontuario: catalogo de medicamentos.
class MedicationsSection extends ConsumerStatefulWidget {
  const MedicationsSection({super.key});

  @override
  ConsumerState<MedicationsSection> createState() => _MedicationsSectionState();
}

class _MedicationsSectionState extends ConsumerState<MedicationsSection> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(medicationsProvider(true));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (list) {
        final q = _search.trim().toLowerCase();
        final meds = q.isEmpty
            ? list.medications
            : list.medications
                  .where((m) => m.title.toLowerCase().contains(q))
                  .toList();
        return _SectionFrame(
          title: Strings.medications,
          hint: Strings.medicationsHint,
          action: list.canUpdate
              ? AppButton(
                  label: Strings.newMedication,
                  icon: Icons.add_rounded,
                  onPressed: () => MedicationDialog.show(context),
                )
              : null,
          children: [
            AppTextField(
              label: Strings.search,
              prefixIcon: Icons.search_rounded,
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final m in meds)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  m.idControlled
                      ? Icons.policy_outlined
                      : Icons.medication_outlined,
                  color: m.isActive ? AppColors.primary : AppColors.muted,
                ),
                title: Text(m.title),
                subtitle: Text(
                  [
                    m.use.label,
                    ?m.vcDosage,
                    if (!m.isActive) Strings.statusInactive,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: list.canUpdate
                    ? const Icon(Icons.edit_outlined)
                    : null,
                onTap: list.canUpdate
                    ? () => MedicationDialog.show(context, medication: m)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class MedicationDialog extends ConsumerStatefulWidget {
  const MedicationDialog({super.key, this.medication});

  final Medication? medication;

  static Future<void> show(BuildContext context, {Medication? medication}) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => MedicationDialog(medication: medication),
      );

  @override
  ConsumerState<MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends ConsumerState<MedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.medication?.vcName ?? '',
  );
  late final _pres = TextEditingController(
    text: widget.medication?.vcPresentation ?? '',
  );
  late final _dosage = TextEditingController(
    text: widget.medication?.vcDosage ?? '',
  );
  late final _qty = TextEditingController(
    text: widget.medication?.vcQuantity ?? '',
  );
  late MedicationUse _use = widget.medication?.use ?? MedicationUse.internal;
  late bool _controlled = widget.medication?.idControlled ?? false;
  late bool _active = widget.medication?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _pres.dispose();
    _dosage.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(documentActionsProvider)
          .saveMedication(
            nrMedication: widget.medication?.nrMedication,
            fields: {
              'vc_name': _name.text.trim(),
              'vc_presentation': _pres.text.trim(),
              'vc_dosage': _dosage.text.trim(),
              'vc_quantity': _qty.text.trim(),
              'it_use': _use.code,
              'id_controlled': _controlled,
              'it_status': _active ? 1 : 90,
            },
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.savedSuccess);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.medication == null
          ? Strings.newMedication
          : Strings.editMedication,
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: Strings.medicationName,
                controller: _name,
                maxLength: 120,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? Strings.required : null,
              ),
              AppTextField(
                label: Strings.presentation,
                controller: _pres,
                maxLength: 120,
              ),
              AppTextField(
                label: Strings.dosage,
                controller: _dosage,
                maxLength: 300,
                maxLines: 3,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: Strings.quantity,
                      controller: _qty,
                      maxLength: 60,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<MedicationUse>(
                      initialValue: _use,
                      decoration: const InputDecoration(
                        labelText: Strings.medicationUse,
                      ),
                      items: [
                        for (final u in MedicationUse.values)
                          DropdownMenuItem(value: u, child: Text(u.label)),
                      ],
                      onChanged: (v) => setState(() => _use = v!),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Strings.controlledMedication),
                value: _controlled,
                onChanged: (v) => setState(() => _controlled = v),
              ),
              if (widget.medication != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(Strings.statusActive),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      AppButton(
        label: Strings.cancel,
        variant: AppButtonVariant.text,
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      AppButton(label: Strings.save, loading: _saving, onPressed: _save),
    ],
  );
}
