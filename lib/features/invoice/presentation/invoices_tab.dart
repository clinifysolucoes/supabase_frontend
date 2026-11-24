import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../agenda/presentation/patient_picker_dialog.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/invoice_controllers.dart';
import '../domain/invoice_models.dart';

Color _statusColor(InvoiceStatus s) => switch (s) {
  InvoiceStatus.draft => AppColors.primary,
  InvoiceStatus.processing => AppColors.warning,
  InvoiceStatus.issued => const Color(0xFF2E9E6B),
  InvoiceStatus.error => AppColors.danger,
  InvoiceStatus.cancelled => AppColors.muted,
};

/// Aba Notas fiscais do Financeiro: rascunhos, emissao e cancelamento de
/// NFS-e pela Edge Function invoice-issue, com totais por situacao.
class InvoicesTab extends ConsumerWidget {
  const InvoicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));
    final status = ref.watch(invoiceStatusFilterProvider);
    final async = ref.watch(invoiceListProvider);
    final d = async.valueOrNull;
    return ListView(
      children: [
        if (d != null && !d.isReady) _SetupBanner(data: d),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text(Strings.alignerAll),
              selected: status == null,
              onSelected: (_) =>
                  ref.read(invoiceStatusFilterProvider.notifier).state = null,
            ),
            for (final s in InvoiceStatus.values)
              if (s != InvoiceStatus.cancelled)
                ChoiceChip(
                  avatar: CircleAvatar(
                    radius: 9,
                    backgroundColor: _statusColor(s),
                    child: Text(
                      '${d?.totals[s] ?? 0}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  label: Text(s.plural),
                  selected: status == s,
                  onSelected: (_) =>
                      ref.read(invoiceStatusFilterProvider.notifier).state = s,
                ),
            ChoiceChip(
              label: const Text(Strings.nfCancelledMany),
              selected: status == InvoiceStatus.cancelled,
              onSelected: (_) =>
                  ref.read(invoiceStatusFilterProvider.notifier).state =
                      InvoiceStatus.cancelled,
            ),
            if (d != null)
              Text(
                Strings.nfIssuedValue(Numbers.money(d.vlIssued)),
                style: const TextStyle(color: AppColors.muted),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: Strings.nfSearch,
                prefixIcon: Icons.search_rounded,
                onChanged: (v) =>
                    ref.read(invoiceSearchProvider.notifier).state = v.trim(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (canCreate)
              AppButton(
                label: Strings.nfNew,
                icon: Icons.add_rounded,
                expanded: false,
                onPressed: () => InvoiceFormDialog.show(context),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppEmptyState.error(
            message: describeError(e),
            onRetry: () => ref.invalidate(invoiceListProvider),
          ),
          data: (data) => data.invoices.isEmpty
              ? const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: Strings.nfEmpty,
                )
              : Column(
                  children: [
                    for (final i in data.invoices)
                      _InvoiceCard(
                        item: i,
                        canCreate: canCreate,
                        canUpdate: canUpdate,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.data});

  final InvoiceListData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (!data.idEnabled) Strings.nfDisabled,
      for (final m in data.missing) invoiceMissingLabel(m),
    ];
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    Strings.nfSetupTitle,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  for (final t in items) Text('• $t'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({
    required this.item,
    required this.canCreate,
    required this.canUpdate,
  });

  final Invoice item;
  final bool canCreate;
  final bool canUpdate;

  Future<void> _issue(BuildContext context, WidgetRef ref) async {
    try {
      final r = await ref.read(invoiceIssueProvider)(item.nrInvoice, 'ISSUE');
      if (!context.mounted) return;
      if ((r['it_status'] as num?)?.toInt() == 3) {
        AppSnack.success(context, Strings.nfIssuedNow);
      } else {
        AppSnack.error(
          context,
          Strings.errorMessage(
            r['Message'] as String? ?? '',
            const {},
            Strings.nfSendError,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason == null || !context.mounted) return;
    try {
      final r = await ref.read(invoiceIssueProvider)(
        item.nrInvoice,
        'CANCEL',
        reason: reason,
      );
      if (!context.mounted) return;
      if ((r['it_status'] as num?)?.toInt() == 90) {
        AppSnack.success(context, Strings.nfCancelledNow);
      } else {
        AppSnack.error(
          context,
          Strings.errorMessage(
            r['Message'] as String? ?? '',
            const {},
            Strings.nfSendError,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.nfDiscard,
      message: Strings.nfDiscardConfirm,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(invoiceSaveProvider)('D', item.nrInvoice, const {});
      if (context.mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (context.mounted) AppSnack.error(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = item;
    final color = _statusColor(i.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (i.vcNumber != null)
                        '${Strings.nfNumber} ${i.vcNumber}',
                      i.vcTakerName,
                    ].join(' · '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  Numbers.money(i.vlService),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: AppSpacing.sm),
                Chip(
                  label: Text(
                    i.status.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: color.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              [
                Masks.format(MaskType.cpfCnpj, i.vcTakerDocument),
                if (i.vcTakerName != i.vcPatient)
                  '${Strings.patient}: ${i.vcPatient}',
                Strings.nfCompetence(Dates.format(i.dtCompetence)),
                Strings.nfIss(Numbers.money(i.vlIss)),
              ].join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(i.vcDescription, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (i.status == InvoiceStatus.error && i.vcError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  Strings.errorMessage(i.vcError!, const {}, i.vcError),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            if (i.status == InvoiceStatus.cancelled && i.vcCancelReason != null)
              Text(
                i.vcCancelReason!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (i.status.isOpen && canCreate)
                  TextButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      i.status == InvoiceStatus.error
                          ? Strings.nfResend
                          : Strings.nfIssue,
                    ),
                    onPressed: () => _issue(context, ref),
                  ),
                if (i.status.isOpen && canUpdate) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(Strings.edit),
                    onPressed: () => InvoiceFormDialog.show(context, item: i),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(Strings.nfDiscard),
                    onPressed: () => _discard(context, ref),
                  ),
                ],
                if (i.status == InvoiceStatus.issued && i.vcPdfUrl != null)
                  TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text(Strings.nfOpenPdf),
                    onPressed: () async {
                      final uri = Uri.tryParse(i.vcPdfUrl!);
                      final ok =
                          uri != null &&
                          uri.scheme == 'https' &&
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                      if (!ok && context.mounted) {
                        AppSnack.error(context, Strings.nfOpenPdfError);
                      }
                    },
                  ),
                if (i.status == InvoiceStatus.issued && i.vcPdfUrl != null)
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(Strings.nfCopyPdf),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: i.vcPdfUrl!));
                      if (context.mounted) {
                        AppSnack.success(context, Strings.rxLinkCopied);
                      }
                    },
                  ),
                if (i.status == InvoiceStatus.issued && canUpdate)
                  TextButton.icon(
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text(Strings.nfCancel),
                    onPressed: () => _cancel(context, ref),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _reason.text.trim().length >= 15;
    return AlertDialog(
      title: const Text(Strings.nfCancel),
      content: SizedBox(
        width: 460,
        child: AppTextField(
          label: Strings.nfCancelReason,
          helperText: Strings.nfCancelReasonHint,
          controller: _reason,
          maxLength: 255,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.close),
        ),
        AppButton(
          label: Strings.nfCancel,
          expanded: false,
          onPressed: ok
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
        ),
      ],
    );
  }
}

/// Rascunho da nota: paciente, valor, competencia, descricao e tomador.
/// Campos em branco no rascunho novo ficam com os padroes do banco.
class InvoiceFormDialog extends ConsumerStatefulWidget {
  const InvoiceFormDialog({super.key, this.item});

  final Invoice? item;

  static Future<void> show(BuildContext context, {Invoice? item}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InvoiceFormDialog(item: item),
      );

  @override
  ConsumerState<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends ConsumerState<InvoiceFormDialog> {
  Invoice? get _i => widget.item;
  late int? _nrPatient = _i?.nrPatient;
  late String? _vcPatient = _i?.vcPatient;
  late final _value = TextEditingController(
    text: _i == null ? '' : Numbers.toField(_i!.vlService),
  );
  late final _date = TextEditingController(
    text: _i?.dtCompetence == null ? '' : Dates.toField(_i!.dtCompetence!),
  );
  late final _description = TextEditingController(
    text: _i?.vcDescription ?? '',
  );
  late final _takerName = TextEditingController(text: _i?.vcTakerName ?? '');
  late final _takerDoc = TextEditingController(
    text: _i == null ? '' : Masks.format(MaskType.cpfCnpj, _i!.vcTakerDocument),
  );
  late final _takerEmail = TextEditingController(text: _i?.vcTakerEmail ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _value,
      _date,
      _description,
      _takerName,
      _takerDoc,
      _takerEmail,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final p = await PatientPickerDialog.show(context);
    if (p != null) {
      setState(() {
        _nrPatient = p.nrPatient;
        _vcPatient = p.vcName;
      });
    }
  }

  Future<void> _save() async {
    if (_nrPatient == null) {
      AppSnack.error(context, Strings.choosePatient);
      return;
    }
    final value = Numbers.parse(_value.text);
    if (value == null || value <= 0) {
      AppSnack.error(context, Strings.nfValueRequired);
      return;
    }
    final date = _date.text.trim().isEmpty
        ? null
        : Dates.parseField(_date.text);
    if (_date.text.trim().isNotEmpty && date == null) {
      AppSnack.error(context, Strings.rxDateInvalid);
      return;
    }
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final fields = <String, dynamic>{
      if (_i == null) 'nr_patient': _nrPatient,
      'vl_service': value,
      if (date != null) 'dt_competence': Dates.toIso(date),
      'vc_description': ?text(_description),
      'vc_taker_name': ?text(_takerName),
      if (text(_takerDoc) != null)
        'vc_taker_document': Masks.unmask(_takerDoc.text),
      if (_i != null || text(_takerEmail) != null)
        'vc_taker_email': text(_takerEmail),
    };
    setState(() => _saving = true);
    try {
      await ref.read(invoiceSaveProvider)(
        _i == null ? 'I' : 'U',
        _i?.nrInvoice,
        fields,
      );
      if (mounted) {
        Navigator.of(context).pop();
        AppSnack.success(context, Strings.savedSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_i == null ? Strings.nfNew : Strings.nfEdit),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_search_rounded),
                title: Text(_vcPatient ?? Strings.choosePatient),
                subtitle: const Text(Strings.patient),
                onTap: _saving || _i != null ? null : _pickPatient,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppNumberField(
                      label: Strings.nfValue,
                      controller: _value,
                      prefixText: 'R\$ ',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.nfCompetenceLabel,
                      controller: _date,
                      enabled: !_saving,
                      hint: Strings.nfTodayHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.nfDescription,
                helperText: _i == null ? Strings.nfDescriptionHint : null,
                controller: _description,
                enabled: !_saving,
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
              ),
              Text(
                Strings.nfTaker,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_i == null)
                const Text(
                  Strings.nfTakerHint,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: Strings.nfTakerName,
                controller: _takerName,
                enabled: !_saving,
                maxLength: 150,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: Strings.nfTakerDocument,
                      controller: _takerDoc,
                      enabled: !_saving,
                      mask: MaskType.cpfCnpj,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: Strings.email,
                      controller: _takerEmail,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
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
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
