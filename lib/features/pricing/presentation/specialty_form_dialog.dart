import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/pricing_controllers.dart';
import '../data/pricing_repository.dart';
import '../domain/pricing_models.dart';

/// Nova especialidade (specialty = null) ou edicao: nome e lucro desejado
/// (vazio = lucro padrao da filial). Devolve true quando salvou.
class SpecialtyFormDialog extends ConsumerStatefulWidget {
  const SpecialtyFormDialog({
    super.key,
    this.specialty,
    required this.branchProfit,
    this.readOnly = false,
  });

  final Specialty? specialty;

  /// Lucro padrao da filial (mostrado como dica).
  final double branchProfit;
  final bool readOnly;

  static Future<bool> show(
    BuildContext context, {
    Specialty? specialty,
    required double branchProfit,
    bool readOnly = false,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SpecialtyFormDialog(
        specialty: specialty,
        branchProfit: branchProfit,
        readOnly: readOnly,
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<SpecialtyFormDialog> createState() =>
      _SpecialtyFormDialogState();
}

class _SpecialtyFormDialogState extends ConsumerState<SpecialtyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _s?.vcName ?? '');
  late final _profit = TextEditingController(
    text: Numbers.toField(_s?.pcProfit),
  );
  late bool _active = _s?.isActive ?? true;
  bool _saving = false;

  Specialty? get _s => widget.specialty;
  bool get _isEdit => _s != null;
  bool get _canEdit => !widget.readOnly && !_saving;

  @override
  void dispose() {
    _name.dispose();
    _profit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final draft = SpecialtyDraft(
        vcName: _name.text.trim(),
        pcProfit: _profit.text.trim().isEmpty
            ? null
            : Numbers.parse(_profit.text),
        itStatus: _isEdit ? (_active ? 1 : 90) : null,
      );
      final controller = ref.read(specialtiesProvider.notifier);
      if (_isEdit) {
        await controller.updateSpecialty(_s!.nrSpecialty, draft);
      } else {
        await controller.create(draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final title = widget.readOnly
        ? Strings.specialty
        : (_isEdit ? Strings.editSpecialty : Strings.newSpecialty);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: Strings.specialtyName,
                  hint: Strings.specialtyNameHint,
                  controller: _name,
                  maxLength: 40,
                  autofocus: !_isEdit,
                  enabled: _canEdit,
                  prefixIcon: Icons.category_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.required(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppNumberField(
                  label: Strings.specialtyProfit,
                  controller: _profit,
                  suffixText: '%',
                  helper: Strings.defaultValue(
                    Numbers.percent(widget.branchProfit, decimals: 2),
                  ),
                  enabled: _canEdit,
                ),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(Strings.specialtyActive),
                    value: _active,
                    onChanged: _canEdit
                        ? (v) => setState(() => _active = v)
                        : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: widget.readOnly ? Strings.close : Strings.cancel,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: Strings.save,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
