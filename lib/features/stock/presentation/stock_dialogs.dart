import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/formatters/numbers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/stock_controllers.dart';
import '../domain/stock_models.dart';

String? _positive(String? v) {
  final n = Numbers.parse(v);
  return n == null || n <= 0 ? Strings.stockQtyInvalid : null;
}

/// Controle de estoque do material e estoque minimo.
class StockItemDialog extends ConsumerStatefulWidget {
  const StockItemDialog({super.key, required this.item});

  final StockItem item;

  static Future<bool?> show(BuildContext context, StockItem item) =>
      showDialog<bool>(
        context: context,
        builder: (_) => StockItemDialog(item: item),
      );

  @override
  ConsumerState<StockItemDialog> createState() => _StockItemDialogState();
}

class _StockItemDialogState extends ConsumerState<StockItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _control = widget.item.idControl || widget.item.qtStock == null;
  late final _min = TextEditingController(
    text: widget.item.qtMin == null
        ? ''
        : Numbers.toField(widget.item.qtMin, decimals: 3),
  );
  bool _saving = false;

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(stockActionsProvider).saveItem(widget.item.nrMaterial, {
        'id_control': _control,
        'qt_min': Numbers.parse(_min.text),
      });
      if (!mounted) return;
      AppSnack.success(context, Strings.stockItemSaved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item.vcName),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.stockControl),
              subtitle: const Text(Strings.stockControlHint),
              value: _control,
              onChanged: (v) => setState(() => _control = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: Strings.stockMin(widget.item.vcUnit ?? ''),
              helperText: Strings.stockMinHint,
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = Numbers.parse(v);
                return n == null || n < 0 ? Strings.stockQtyInvalid : null;
              },
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

/// Entrada (compra), saida manual ou ajuste de inventario de um material.
class StockMoveDialog extends ConsumerStatefulWidget {
  const StockMoveDialog({
    super.key,
    required this.item,
    required this.type,
    required this.suppliers,
  });

  final StockItem item;
  final int type;
  final List<({int id, String name})> suppliers;

  static Future<bool?> show(
    BuildContext context, {
    required StockItem item,
    required int type,
    required List<({int id, String name})> suppliers,
  }) => showDialog<bool>(
    context: context,
    builder: (_) =>
        StockMoveDialog(item: item, type: type, suppliers: suppliers),
  );

  @override
  ConsumerState<StockMoveDialog> createState() => _StockMoveDialogState();
}

class _StockMoveDialogState extends ConsumerState<StockMoveDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _byPackage =
      widget.item.hasPackages && widget.type == StockMoveType.entry;
  final _qty = TextEditingController();
  final _total = TextEditingController();
  final _doc = TextEditingController();
  final _date = TextEditingController(text: Dates.toField(DateTime.now()));
  final _due = TextEditingController();
  final _notes = TextEditingController();
  int? _supplier;
  bool _payable = false;
  bool _updatePrice = false;
  bool _saving = false;

  StockItem get _item => widget.item;
  bool get _entry => widget.type == StockMoveType.entry;
  bool get _adjust => widget.type == StockMoveType.adjust;

  @override
  void dispose() {
    for (final c in [_qty, _total, _doc, _date, _due, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Quantidade digitada em unidades de uso.
  double? get _units {
    final q = Numbers.parse(_qty.text);
    if (q == null) return null;
    return _byPackage ? q * (_item.qtYield ?? 0) : q;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final q = Numbers.parse(_qty.text);
    final due = Dates.parseField(_due.text);
    final fields = <String, dynamic>{
      'it_type': widget.type,
      'dt_movement': Dates.toIso(
        Dates.parseField(_date.text) ?? DateTime.now(),
      ),
      if (_adjust)
        'qt_counted': q
      else if (_byPackage)
        'qt_packages': q
      else
        'qt_quantity': q,
      if (_entry) ...{
        'vl_total': Numbers.parse(_total.text),
        'nr_supplier': _supplier,
        if (_doc.text.trim().isNotEmpty) 'vc_document': _doc.text.trim(),
        'id_payable': _payable,
        if (_payable && due != null) 'dt_due': Dates.toIso(due),
        'id_update_price': _updatePrice && _byPackage,
      },
      if (_notes.text.trim().isNotEmpty) 'vc_notes': _notes.text.trim(),
    };
    try {
      final r = await ref
          .read(stockActionsProvider)
          .move(_item.nrMaterial, fields);
      if (!mounted) return;
      final balance = '${Numbers.qty(r.stock)} ${_item.vcUnit ?? ''}'.trim();
      AppSnack.success(
        context,
        !r.changed
            ? Strings.stockNoChange
            : r.payable
            ? Strings.stockMovedPayable(balance)
            : Strings.stockMoved(balance),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, describeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canFinance = ref.watch(canCreateProvider(ScreenCodes.finance));
    final canPricing = ref.watch(canUpdateProvider(ScreenCodes.pricing));
    final unit = _item.vcUnit ?? Strings.stockUnits;
    final units = _units;
    return AlertDialog(
      title: Text('${StockMoveType.label(widget.type)}: ${_item.vcName}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Strings.stockCurrent(
                    '${Numbers.qty(_item.qtStock ?? 0)} $unit',
                  ),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_adjust && _item.hasPackages) ...[
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(_item.vcPackage ?? Strings.stockPackages),
                      ),
                      ButtonSegment(value: false, label: Text(unit)),
                    ],
                    selected: {_byPackage},
                    onSelectionChanged: (s) => setState(() {
                      _byPackage = s.first;
                      if (!_byPackage) _updatePrice = false;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  label: _adjust
                      ? Strings.stockCounted(unit)
                      : _byPackage
                      ? Strings.stockQtyPackages
                      : Strings.stockQtyUnits(unit),
                  controller: _qty,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helperText: _byPackage && units != null
                      ? Strings.stockEquals('${Numbers.qty(units)} $unit')
                      : null,
                  onChanged: (_) => setState(() {}),
                  validator: _adjust
                      ? (v) {
                          final n = Numbers.parse(v);
                          return n == null || n < 0
                              ? Strings.stockQtyInvalid
                              : null;
                        }
                      : _positive,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
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
                if (_entry) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.stockTotal,
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return _payable || _updatePrice
                            ? Strings.stockTotalRequired
                            : null;
                      }
                      final n = Numbers.parse(v);
                      return n == null || n < 0
                          ? Strings.stockQtyInvalid
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _supplier,
                    decoration: const InputDecoration(
                      labelText: Strings.stockSupplier,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(Strings.notInformed),
                      ),
                      for (final s in widget.suppliers)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _supplier = v),
                    validator: (v) => _payable && v == null
                        ? Strings.stockSupplierRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.stockDocument,
                    controller: _doc,
                    maxLength: 60,
                  ),
                  if (canFinance)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(Strings.stockPayable),
                      subtitle: const Text(Strings.stockPayableHint),
                      value: _payable,
                      onChanged: (v) => setState(() => _payable = v ?? false),
                    ),
                  if (_payable)
                    AppTextField(
                      label: Strings.prosDue,
                      hint: Strings.stockDueHint,
                      controller: _due,
                      mask: MaskType.date,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ||
                              Dates.parseField(v) != null
                          ? null
                          : Strings.invalidDate,
                    ),
                  if (canPricing && _byPackage)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(Strings.stockUpdatePrice),
                      subtitle: Text(
                        Strings.stockUpdatePriceHint(
                          Numbers.money(_item.vlPackagePrice ?? 0),
                        ),
                      ),
                      value: _updatePrice,
                      onChanged: (v) =>
                          setState(() => _updatePrice = v ?? false),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: _entry ? Strings.notes : Strings.stockReason,
                  controller: _notes,
                  maxLength: 500,
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
