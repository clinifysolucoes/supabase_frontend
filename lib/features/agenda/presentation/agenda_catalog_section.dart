import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../../settings/application/settings_controller.dart';
import '../application/agenda_controllers.dart';
import '../domain/agenda_models.dart';
import 'professional_form_dialog.dart';

/// Configuracoes > Agenda: categorias, marcadores e cadeiras.
class AgendaCatalogSection extends ConsumerWidget {
  const AgendaCatalogSection({super.key, required this.catalog});

  final AgendaCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in AgendaCatalogKind.values) ...[
          const SizedBox(height: AppSpacing.md),
          _CatalogCard(kind: k, items: catalog.of(k)),
        ],
      ],
    );
  }
}

String _title(AgendaCatalogKind k) => switch (k) {
  AgendaCatalogKind.category => Strings.agendaCategories,
  AgendaCatalogKind.marker => Strings.agendaMarkers,
  AgendaCatalogKind.chair => Strings.agendaChairs,
};

String _hint(AgendaCatalogKind k) => switch (k) {
  AgendaCatalogKind.category => Strings.agendaCategoriesHint,
  AgendaCatalogKind.marker => Strings.agendaMarkersHint,
  AgendaCatalogKind.chair => Strings.agendaChairsHint,
};

class _CatalogCard extends ConsumerWidget {
  const _CatalogCard({required this.kind, required this.items});

  final AgendaCatalogKind kind;
  final List<AgendaTag> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateProvider(ScreenCodes.settings));
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.settings));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title(kind),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canCreate)
                  AppButton(
                    label: Strings.addExpense,
                    icon: Icons.add_rounded,
                    expanded: false,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => AgendaTagDialog.show(context, kind: kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _hint(kind),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              const Text(
                Strings.agendaCatalogEmpty,
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in items)
                    ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: Color(AgendaColors.argb(t.vcColor)),
                        radius: 7,
                      ),
                      label: Text(
                        t.isActive
                            ? t.vcName
                            : '${t.vcName} (${Strings.statusInactive.toLowerCase()})',
                        style: TextStyle(
                          color: t.isActive ? null : AppColors.muted,
                        ),
                      ),
                      onPressed: canUpdate
                          ? () => AgendaTagDialog.show(
                              context,
                              kind: kind,
                              item: t,
                            )
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Cria ou altera uma categoria, um marcador ou uma cadeira.
class AgendaTagDialog extends ConsumerStatefulWidget {
  const AgendaTagDialog({super.key, required this.kind, this.item});

  final AgendaCatalogKind kind;
  final AgendaTag? item;

  static Future<void> show(
    BuildContext context, {
    required AgendaCatalogKind kind,
    AgendaTag? item,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AgendaTagDialog(kind: kind, item: item),
  );

  @override
  ConsumerState<AgendaTagDialog> createState() => _AgendaTagDialogState();
}

class _AgendaTagDialogState extends ConsumerState<AgendaTagDialog> {
  late final _name = TextEditingController(text: widget.item?.vcName ?? '');
  late String _color = widget.item?.vcColor ?? AgendaColors.palette.first;
  late bool _active = widget.item?.isActive ?? true;
  bool _saving = false;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppSnack.error(context, Strings.agendaCatalogNameRequired);
      return;
    }
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(supabaseGatewayProvider).rpc('agenda_catalog_save', {
        'vc_action': widget.item == null ? 'I' : 'U',
        'vc_entity': widget.kind.code,
        'nr_company': c,
        'nr_branch': b,
        if (widget.item != null) 'nr_item': widget.item!.nrItem,
        'vc_name': name,
        'vc_color': _color,
        'it_status': _active ? 1 : 90,
      });
      ref.invalidate(settingsProvider);
      ref.invalidate(appointmentsProvider);
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
      title: Text(switch (widget.kind) {
        AgendaCatalogKind.category => Strings.agendaCategory,
        AgendaCatalogKind.marker => Strings.agendaMarker,
        AgendaCatalogKind.chair => Strings.agendaChair,
      }),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: Strings.name,
              controller: _name,
              maxLength: 40,
              enabled: !_saving,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              Strings.agendaColor,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            AgendaColorPicker(
              value: _color,
              enabled: !_saving,
              onChanged: (v) => setState(() => _color = v),
            ),
            if (widget.item != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Strings.statusActive),
                value: _active,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),
          ],
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
