import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_number_field.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/finance_controllers.dart';
import '../domain/finance_models.dart';
import 'finance_overview_tab.dart' show accountIcon;
import '../domain/receivable_models.dart';
import 'finance_widgets.dart';
import 'rate_form_dialog.dart';

enum RegisterType { account, category, supplier }

/// Cadastros do financeiro: contas, plano de contas e fornecedores.
class RegistersTab extends ConsumerWidget {
  const RegistersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeCatalogProvider);
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.finance));

    Future<void> open(RegisterType type, {Object? item, int? kind}) async {
      final saved = await RegisterFormDialog.show(
        context,
        type: type,
        item: item,
        kind: kind,
        readOnly: item != null && !canUpdate,
      );
      if (saved != null && context.mounted) {
        AppSnack.success(context, Strings.savedSuccess);
      }
    }

    Widget add(String label, RegisterType type, {int? kind}) => canCreate
        ? TextButton.icon(
            onPressed: () => open(type, kind: kind),
            icon: const Icon(Icons.add_rounded),
            label: Text(label),
          )
        : const SizedBox.shrink();

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState.error(
        message: describeError(e),
        onRetry: () => ref.invalidate(financeCatalogProvider),
      ),
      data: (c) {
        final accounts = _Section(
          title: Strings.finAccountsSection,
          action: add(Strings.finNewAccount, RegisterType.account),
          children: [
            for (final a in c.accounts)
              _Tile(
                icon: accountIcon(a.itType),
                title: a.vcName,
                subtitle:
                    '${AccountType.label(a.itType)} · ${Strings.finOpening} ${Numbers.money(a.vlOpening)}',
                trailing: Numbers.money(a.vlBalance),
                status: a.itStatus,
                onTap: () => open(RegisterType.account, item: a),
              ),
          ],
        );
        Widget categoryGroup(int kind) => _Section(
          title: kind == EntryKind.receivable
              ? '${Strings.finCategoriesSection} · ${Strings.finRevenues}'
              : '${Strings.finCategoriesSection} · ${Strings.finExpenses}',
          action: add(
            Strings.finNewCategory,
            RegisterType.category,
            kind: kind,
          ),
          children: [
            for (final x in c.categoriesOf(kind))
              _Tile(
                icon: kind == EntryKind.receivable
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                title: x.vcName,
                subtitle: [
                  if (x.itCostType != null) CostType.label(x.itCostType),
                  Strings.finUsedBy(x.qtEntries),
                ].join(' · '),
                status: x.itStatus,
                onTap: () => open(RegisterType.category, item: x),
              ),
          ],
        );
        final suppliers = _Section(
          title: Strings.finSuppliersSection,
          action: add(Strings.finNewSupplier, RegisterType.supplier),
          children: [
            for (final s in c.suppliers)
              _Tile(
                icon: Icons.storefront_outlined,
                title: s.vcName,
                subtitle: [
                  if (s.vcDocument != null)
                    Masks.format(MaskType.cpfCnpj, s.vcDocument!),
                  if (s.vcPhone != null)
                    Masks.format(MaskType.phone, s.vcPhone!),
                  ?s.vcEmail,
                ].join(' · '),
                status: s.itStatus,
                onTap: () => open(RegisterType.supplier, item: s),
              ),
          ],
        );
        Future<void> openRate([FinRate? r]) async {
          final saved = await RateFormDialog.show(
            context,
            accounts: c.payableAccounts,
            rate: r,
            readOnly: r != null && !canUpdate,
          );
          if (saved && context.mounted) {
            AppSnack.success(context, Strings.savedSuccess);
          }
        }

        final rates = _Section(
          title: Strings.ratesSection,
          action: canCreate
              ? TextButton.icon(
                  onPressed: openRate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(Strings.rateNew),
                )
              : null,
          children: [
            for (final r in c.rates)
              _Tile(
                icon: Icons.credit_card_rounded,
                title: r.vcName,
                subtitle: [
                  PaymentMethod.label(r.itPaymentMethod),
                  if (RateMethod.installments(r.itPaymentMethod))
                    Strings.rateRange(r.qtInstallmentsMin, r.qtInstallmentsMax),
                  Strings.rateSummary(
                    Numbers.percent(r.pcFee, decimals: 2),
                    r.vlFeeFixed > 0 ? Numbers.money(r.vlFeeFixed) : '',
                    r.qtDays,
                  ),
                ].join(' · '),
                status: r.itStatus,
                onTap: () => openRate(r),
              ),
          ],
        );
        final sections = [
          accounts,
          categoryGroup(EntryKind.receivable),
          categoryGroup(EntryKind.payable),
          suppliers,
          rates,
        ];
        if (context.isMobile) {
          return ListView(
            children: [
              for (final s in sections) ...[
                s,
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    accounts,
                    const SizedBox(height: AppSpacing.md),
                    rates,
                    const SizedBox(height: AppSpacing.md),
                    suppliers,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    sections[1],
                    const SizedBox(height: AppSpacing.md),
                    sections[2],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSectionTitle(title, trailing: action),
            if (children.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  Strings.finNoRegisters,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int status;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final active = status == 1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: active ? AppColors.primary : AppColors.muted),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? null : AppColors.muted,
        ),
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: !active
          ? AppStatusChip(status: status, compact: true)
          : (trailing == null
                ? null
                : Text(
                    trailing!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  )),
    );
  }
}

/// Cadastro/alteracao de conta, categoria ou fornecedor.
class RegisterFormDialog extends ConsumerStatefulWidget {
  const RegisterFormDialog({
    super.key,
    required this.type,
    this.item,
    this.readOnly = false,
    this.kind,
  });

  final RegisterType type;

  /// Categoria nova ja com receita/despesa escolhida.
  final int? kind;

  /// FinAccount, FinCategory ou FinSupplier (null cria).
  final Object? item;
  final bool readOnly;

  /// Devolve o numero gravado ou null (cancelou).
  static Future<int?> show(
    BuildContext context, {
    required RegisterType type,
    Object? item,
    int? kind,
    bool readOnly = false,
  }) => showDialog<int>(
    context: context,
    builder: (_) => RegisterFormDialog(
      type: type,
      item: item,
      kind: kind,
      readOnly: readOnly,
    ),
  );

  @override
  ConsumerState<RegisterFormDialog> createState() => _RegisterFormDialogState();
}

class _RegisterFormDialogState extends ConsumerState<RegisterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  int _accountType = AccountType.cash;
  int _kind = EntryKind.payable;
  int? _costType = CostType.fixed;
  bool _active = true;
  bool _saving = false;

  int? get _id => switch (widget.item) {
    final FinAccount a => a.nrAccount,
    final FinCategory c => c.nrCategory,
    final FinSupplier s => s.nrSupplier,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    if (widget.kind != null) {
      _kind = widget.kind!;
      if (_kind == EntryKind.receivable) _costType = null;
    }
    switch (widget.item) {
      case final FinAccount a:
        _name.text = a.vcName;
        _accountType = a.itType;
        _opening.text = Numbers.toField(a.vlOpening);
        _active = a.isActive;
      case final FinCategory c:
        _name.text = c.vcName;
        _kind = c.itKind;
        _costType = c.itCostType;
        _active = c.isActive;
      case final FinSupplier s:
        _name.text = s.vcName;
        _document.text = s.vcDocument == null
            ? ''
            : Masks.format(MaskType.cpfCnpj, s.vcDocument!);
        _phone.text = s.vcPhone == null
            ? ''
            : Masks.format(MaskType.phone, s.vcPhone!);
        _email.text = s.vcEmail ?? '';
        _notes.text = s.vcNotes ?? '';
        _active = s.isActive;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _opening, _document, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final isNew = _id == null;
    final fields = <String, dynamic>{
      'vc_name': _name.text.trim(),
      if (!isNew) 'it_status': _active ? 1 : 90,
      ...switch (widget.type) {
        RegisterType.account => {
          'it_type': _accountType,
          'vl_opening': Numbers.parse(_opening.text) ?? 0,
        },
        RegisterType.category => {
          if (isNew) 'it_kind': _kind,
          'it_cost_type': _kind == EntryKind.payable ? _costType : null,
        },
        RegisterType.supplier => {
          'vc_document': _text(_document),
          'vc_phone': _text(_phone),
          'vc_email': _text(_email),
          'vc_notes': _text(_notes),
        },
      },
    };
    final (rpc, key) = switch (widget.type) {
      RegisterType.account => ('fin_account_save', 'nr_account'),
      RegisterType.category => ('fin_category_save', 'nr_category'),
      RegisterType.supplier => ('fin_supplier_save', 'nr_supplier'),
    };
    try {
      final nr = await ref
          .read(financeActionsProvider)
          .saveRegister(rpc: rpc, key: key, id: _id, fields: fields);
      if (mounted) Navigator.of(context).pop(nr);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _id == null;
    final enabled = !widget.readOnly && !_saving;
    final title = switch (widget.type) {
      RegisterType.account => Strings.finNewAccount,
      RegisterType.category => Strings.finNewCategory,
      RegisterType.supplier => Strings.finNewSupplier,
    };
    final fields = <Widget>[
      AppTextField(
        label: '${Strings.name} *',
        controller: _name,
        enabled: enabled,
        autofocus: isNew,
        maxLength: widget.type == RegisterType.supplier ? 120 : 60,
        textCapitalization: TextCapitalization.words,
        validator: (v) => (v ?? '').trim().isEmpty ? Strings.required : null,
      ),
      ...switch (widget.type) {
        RegisterType.account => [
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: _accountType,
            decoration: const InputDecoration(
              labelText: Strings.finAccountType,
            ),
            items: [
              for (final t in AccountType.all)
                DropdownMenuItem(value: t, child: Text(AccountType.label(t))),
            ],
            onChanged: enabled
                ? (v) => setState(() => _accountType = v ?? _accountType)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppNumberField(
            label: Strings.finOpening,
            controller: _opening,
            prefixText: 'R\$ ',
            helper: Strings.finOpeningHelper,
            enabled: enabled,
          ),
        ],
        RegisterType.category => [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: EntryKind.payable,
                label: Text(Strings.finExpense),
              ),
              ButtonSegment(
                value: EntryKind.receivable,
                label: Text(Strings.finRevenue),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: enabled && isNew
                ? (s) => setState(() {
                    _kind = s.first;
                    _costType = _kind == EntryKind.payable
                        ? (_costType ?? CostType.fixed)
                        : null;
                  })
                : null,
          ),
          if (_kind == EntryKind.payable) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _costType,
              decoration: const InputDecoration(labelText: Strings.finCostType),
              items: [
                for (final t in CostType.all)
                  DropdownMenuItem(value: t, child: Text(CostType.label(t))),
              ],
              onChanged: enabled ? (v) => setState(() => _costType = v) : null,
            ),
          ],
        ],
        RegisterType.supplier => [
          AppTextField(
            label: Strings.finDocument,
            controller: _document,
            mask: MaskType.cpfCnpj,
            keyboardType: TextInputType.number,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: Strings.phone,
            controller: _phone,
            mask: MaskType.phone,
            keyboardType: TextInputType.phone,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: Strings.email,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: Strings.notes,
            controller: _notes,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            enabled: enabled,
          ),
        ],
      },
      if (!isNew)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_active ? Strings.statusActive : Strings.statusInactive),
          value: _active,
          onChanged: enabled ? (v) => setState(() => _active = v) : null,
        ),
    ];
    return AlertDialog(
      title: Text(isNew ? title : _name.text),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: fields,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(widget.readOnly ? Strings.close : Strings.cancel),
        ),
        if (!widget.readOnly)
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
