import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/invoice_controllers.dart';
import '../domain/invoice_models.dart';

/// Configuracoes > Nota fiscal: dados fiscais da NFS-e da filial e o que
/// ainda falta (dados da clinica e desta configuracao) para emitir.
class InvoiceSettingsSection extends ConsumerWidget {
  const InvoiceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(invoiceSettingsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppEmptyState.error(
            message: describeError(e),
            onRetry: () => ref.invalidate(invoiceSettingsProvider),
          ),
          data: (s) =>
              InvoiceSettingsForm(key: ValueKey(s.hashCode), settings: s),
        );
  }
}

class InvoiceSettingsForm extends ConsumerStatefulWidget {
  const InvoiceSettingsForm({super.key, required this.settings});

  final InvoiceSettings settings;

  @override
  ConsumerState<InvoiceSettingsForm> createState() =>
      _InvoiceSettingsFormState();
}

class _InvoiceSettingsFormState extends ConsumerState<InvoiceSettingsForm> {
  late final s = widget.settings;
  late bool _enabled = s.idEnabled;
  late bool _withheld = s.idIssWithheld;
  late final _ibge = TextEditingController(text: s.vcCityIbge ?? '');
  late final _service = TextEditingController(text: s.vcServiceCode);
  late final _cityService = TextEditingController(
    text: s.vcCityServiceCode ?? '',
  );
  late final _cnae = TextEditingController(text: s.vcCnae);
  late final _iss = TextEditingController(text: Numbers.toField(s.pcIss));
  late final _series = TextEditingController(text: s.vcRpsSeries);
  late final _tpl = TextEditingController(text: s.vcTplDescription);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _ibge,
      _service,
      _cityService,
      _cnae,
      _iss,
      _series,
      _tpl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(invoiceSettingsSaveProvider)({
        'id_enabled': _enabled,
        'id_iss_withheld': _withheld,
        'vc_city_ibge': _ibge.text.trim(),
        'vc_service_code': _service.text.trim(),
        'vc_city_service_code': _cityService.text.trim(),
        'vc_cnae': _cnae.text.trim(),
        'pc_iss': Numbers.parse(_iss.text),
        'vc_rps_series': _series.text.trim(),
        'vc_tpl_description': _tpl.text.trim(),
      });
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? helper,
    int? max,
    double width = 240,
  }) => SizedBox(
    width: width,
    child: AppTextField(
      label: label,
      helperText: helper,
      controller: c,
      enabled: s.canUpdate && !_saving,
      maxLength: max,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final can = s.canUpdate && !_saving;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settingsInvoice,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              Strings.nfSettingsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            if (s.missing.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                color: AppColors.warning.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        Strings.nfSetupTitle,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      for (final m in s.missing)
                        Text('• ${invoiceMissingLabel(m)}'),
                    ],
                  ),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.nfEnabled),
              subtitle: const Text(Strings.nfEnabledHint),
              value: _enabled,
              onChanged: can ? (v) => setState(() => _enabled = v) : null,
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _field(
                  Strings.nfIbge,
                  _ibge,
                  helper: Strings.nfIbgeHint,
                  max: 7,
                ),
                _field(
                  Strings.nfServiceCode,
                  _service,
                  helper: Strings.nfServiceCodeHint,
                  max: 10,
                ),
                _field(Strings.nfCityServiceCode, _cityService, max: 20),
                _field(Strings.nfCnae, _cnae, max: 10),
                SizedBox(
                  width: 160,
                  child: AppNumberField(
                    label: Strings.nfIssRate,
                    controller: _iss,
                    suffixText: '%',
                    enabled: can,
                  ),
                ),
                _field(Strings.nfRpsSeries, _series, max: 5, width: 160),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.nfIssWithheld),
              value: _withheld,
              onChanged: can ? (v) => setState(() => _withheld = v) : null,
            ),
            AppTextField(
              label: Strings.nfDescriptionTemplate,
              helperText: Strings.nfDescriptionTemplateHint,
              controller: _tpl,
              enabled: can,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
            ),
            if (s.canUpdate)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: Strings.save,
                  expanded: false,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
