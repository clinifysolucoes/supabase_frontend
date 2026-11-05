import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../data/finance_repository.dart';
import '../domain/cash_models.dart';
import '../domain/finance_models.dart';
import 'payment_details_fields.dart';

/// Fechamento financeiro da consulta: valor (da precificacao), parcelas,
/// receber agora no caixa e comissao do profissional. Se ja foi fechada,
/// mostra os lancamentos gerados. Devolve true quando fechou.
class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key, required this.nrAppointment});

  final int nrAppointment;

  static Future<bool> show(BuildContext context, int nrAppointment) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CheckoutDialog(nrAppointment: nrAppointment),
      ) ??
      false;

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _installments = TextEditingController(text: '1');
  final _pc = TextEditingController();
  final _card = TextEditingController(text: '1');
  final _details = PaymentDetailsController();
  CheckoutData? _data;
  String? _error;
  int? _category;
  int? _method;
  int? _account;
  bool _paid = true;
  bool _commission = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_refresh);
    _installments.addListener(_refresh);
    _pc.addListener(_refresh);
    _load();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _amount.dispose();
    _installments.dispose();
    _pc.dispose();
    _card.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    try {
      final d = await ref
          .read(financeRepositoryProvider)
          .checkoutGet(
            nrCompany: nrCompany,
            nrBranch: nrBranch,
            nrAppointment: widget.nrAppointment,
          );
      if (!mounted) return;
      setState(() {
        _data = d;
        _amount.text = Numbers.toField(d.vlPrice);
        _pc.text = Numbers.toField(d.pcCommission);
        _category = d.nrCategory;
        _commission = d.pcCommission > 0 && d.nrProfessional != null;
        // receber agora: o caixa aberto do usuario, senao a 1a conta caixa
        _account =
            d.nrSessionAccount ??
            (d.accounts.isEmpty ? null : d.accounts.first.nrAccount);
        _paid = _account != null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(financeActionsProvider)
          .checkout(
            CheckoutDraft(
              nrAppointment: widget.nrAppointment,
              vlAmount: Numbers.parse(_amount.text) ?? 0,
              nrCategory: _category,
              qtInstallments: int.tryParse(_installments.text) ?? 1,
              itPaymentMethod: _method,
              idPaid: _paid,
              nrAccount: _account,
              idCommission: _commission,
              pcCommission: Numbers.parse(_pc.text),
              qtCardInstallments: _method == 3
                  ? int.tryParse(_card.text) ?? 1
                  : 1,
              details: _details.value(_method),
            ),
          );
      if (!mounted) return;
      AppSnack.success(context, Strings.checkoutDone);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final pad = isMobile ? AppSpacing.md : AppSpacing.lg;
    final d = _data;
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final editable = d != null && !d.idDone && d.idConfigured && canCreate;

    Widget body;
    if (_error != null) {
      body = Text(_error!, style: const TextStyle(color: AppColors.danger));
    } else if (d == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(data: d),
          const SizedBox(height: AppSpacing.md),
          if (!d.idConfigured)
            const Text(
              Strings.checkoutNotConfigured,
              style: TextStyle(color: AppColors.warning),
            )
          else if (d.idDone || d.entries.isNotEmpty) ...[
            if (d.idDone)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  Strings.checkoutAlreadyDone,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            _EntriesList(entries: d.entries),
          ],
          if (editable) ..._form(d),
        ],
      );
    }

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        Strings.checkoutTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      body,
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  AppSpacing.md,
                  pad,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: editable ? Strings.cancel : Strings.close,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    if (editable) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: Strings.confirm,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(CheckoutData d) {
    final amount = Numbers.parse(_amount.text) ?? 0;
    final n = int.tryParse(_installments.text) ?? 1;
    final pc = Numbers.parse(_pc.text) ?? 0;
    final now = DateTime.now();
    final commissionDue = DateTime(now.year, now.month + 1, 10);
    final hasProfessional = d.nrProfessional != null;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: AppNumberField(
              label: '${Strings.checkoutAmount} *',
              controller: _amount,
              prefixText: 'R\$ ',
              required: true,
              positive: true,
              helper: d.vlPrice == null
                  ? Strings.checkoutNoPrice
                  : Strings.checkoutPriceHint,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppNumberField(
              label: Strings.finInstallments,
              controller: _installments,
              decimals: 0,
              required: true,
              validator: (v) {
                final x = int.tryParse(v ?? '') ?? 0;
                return x < 1 || x > 24 ? '1 – 24' : null;
              },
            ),
          ),
        ],
      ),
      if (n > 1 && amount > 0)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            Strings.finInstallmentsPreview(
              n,
              Numbers.money((amount / n * 100).floorToDouble() / 100),
            ),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(labelText: Strings.finCategory),
              items: [
                for (final c in d.categories)
                  DropdownMenuItem(value: c.nr, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: Strings.finPaymentMethod,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (final m in PaymentMethod.all)
                  DropdownMenuItem(
                    value: m,
                    child: Text(PaymentMethod.label(m)),
                  ),
              ],
              onChanged: (v) => setState(() => _method = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(Strings.checkoutReceiveNow),
        value: _paid,
        onChanged: d.accounts.isEmpty
            ? null
            : (v) => setState(() => _paid = v ?? false),
      ),
      if (_paid)
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: _account,
          decoration: const InputDecoration(
            labelText: '${Strings.finAccount} *',
          ),
          items: [
            for (final a in d.accounts)
              if (a.itType != AccountType.receivables)
                DropdownMenuItem(value: a.nrAccount, child: Text(a.vcName)),
          ],
          validator: (v) =>
              _paid && v == null ? Strings.finChooseAccount : null,
          onChanged: (v) => setState(() => _account = v),
        ),
      if (_paid && _method == 3) ...[
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 200,
          child: AppNumberField(
            label: Strings.cardInstallments,
            controller: _card,
            decimals: 0,
            helper: Strings.cardRateHint,
            validator: (v) {
              final x = int.tryParse(v ?? '') ?? 0;
              return x < 1 || x > 24 ? '1 – 24' : null;
            },
          ),
        ),
      ],
      if (_paid) PaymentDetailsFields(controller: _details, method: _method),
      if (hasProfessional) ...[
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(Strings.checkoutCommission),
          subtitle: _commission && pc > 0 && amount > 0
              ? Text(
                  Strings.checkoutCommissionPreview(
                    Numbers.money((amount * pc).round() / 100),
                    Dates.format(commissionDue),
                  ),
                )
              : null,
          value: _commission,
          onChanged: (v) => setState(() => _commission = v),
        ),
        if (_commission)
          SizedBox(
            width: 160,
            child: AppNumberField(
              label: Strings.checkoutCommissionPc,
              controller: _pc,
              suffixText: '%',
              validator: (v) {
                final x = Numbers.parse(v) ?? 0;
                return x < 0 || x > 100 ? '0 – 100' : null;
              },
            ),
          ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final CheckoutData data;

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String? text) => text == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.muted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text)),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(Icons.person_outline_rounded, data.vcPatient),
        line(Icons.badge_outlined, data.vcProfessional),
        line(Icons.medical_services_outlined, data.vcProcedure),
      ],
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({required this.entries});

  final List<CheckoutEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Text(
                Strings.checkoutEntries,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final e in entries)
              ListTile(
                dense: true,
                leading: Icon(
                  e.itKind == EntryKind.receivable
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: e.itKind == EntryKind.receivable
                      ? AppColors.success
                      : AppColors.danger,
                ),
                title: Text(e.vcDescription),
                subtitle: Text(
                  '${Dates.format(e.dtDue)} · '
                  '${EntryStatus.label(e.itStatus)}',
                ),
                trailing: Text(
                  Numbers.money(e.vlAmount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
