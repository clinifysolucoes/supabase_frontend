import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/online_booking_repository.dart';
import '../domain/online_booking_models.dart';

final onlineBookingSettingsProvider =
    FutureProvider.autoDispose<OnlineBookingSettings>((ref) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const OnlineBookingSettings();
      return ref.read(onlineBookingRepositoryProvider).settings(c, b);
    });

/// Configuracoes > Agendamento online.
class OnlineBookingSection extends ConsumerWidget {
  const OnlineBookingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onlineBookingSettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (s) => _OnlineBookingForm(key: ValueKey(s.hashCode), settings: s),
    );
  }
}

class _OnlineBookingForm extends ConsumerStatefulWidget {
  const _OnlineBookingForm({super.key, required this.settings});

  final OnlineBookingSettings settings;

  @override
  ConsumerState<_OnlineBookingForm> createState() => _OnlineBookingFormState();
}

class _OnlineBookingFormState extends ConsumerState<_OnlineBookingForm> {
  late bool _enabled = widget.settings.idEnabled;
  late final _slug = TextEditingController(text: widget.settings.vcSlug);
  late final _days = TextEditingController(
    text: '${widget.settings.qtDaysAhead}',
  );
  late final _hours = TextEditingController(
    text: '${widget.settings.qtMinHours}',
  );
  late final _message = TextEditingController(
    text: widget.settings.vcMessage ?? '',
  );
  late final Map<int, bool> _online = {
    for (final p in widget.settings.professionals) p.nrProfessional: p.idOnline,
  };
  bool _saving = false;

  @override
  void dispose() {
    _slug.dispose();
    _days.dispose();
    _hours.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _url =>
      OnlineBookingSettings.publicUrl(Uri.base.origin, _slug.text.trim());

  Future<void> _save() async {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(onlineBookingRepositoryProvider).saveSettings(c, b, {
        'id_enabled': _enabled,
        'vc_slug': _slug.text.trim(),
        'qt_days_ahead': int.tryParse(_days.text.trim()),
        'qt_min_hours': int.tryParse(_hours.text.trim()),
        'vc_message': _message.text.trim(),
        'professionals': [
          for (final e in _online.entries)
            {'nr_professional': e.key, 'id_online': e.value},
        ],
      });
      ref.invalidate(onlineBookingSettingsProvider);
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final theme = Theme.of(context);
    final can = s.canUpdate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settingsOnline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              Strings.onlineSettingsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.onlineEnabled),
              value: _enabled,
              onChanged: can ? (v) => setState(() => _enabled = v) : null,
            ),
            AppTextField(
              label: Strings.onlineSlug,
              controller: _slug,
              enabled: can,
              maxLength: 40,
              helperText: _url,
              onChanged: (_) => setState(() {}),
            ),
            if (s.idSaved && s.idEnabled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _url));
                    if (context.mounted) {
                      AppSnack.success(context, Strings.linkCopied);
                    }
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text(Strings.copyLink),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: Strings.onlineDaysAhead,
                    controller: _days,
                    enabled: can,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: Strings.onlineMinHours,
                    controller: _hours,
                    enabled: can,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: Strings.onlineMessage,
              controller: _message,
              enabled: can,
              maxLength: 500,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              Strings.onlineProfessionals,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (s.professionals.isEmpty)
              const Text(
                Strings.onlineNoProfessionals,
                style: TextStyle(color: AppColors.muted),
              ),
            for (final p in s.professionals)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(p.vcName),
                subtitle: Text(Strings.onlineDuration(p.qtSlotMinutes)),
                value: _online[p.nrProfessional] ?? false,
                onChanged: can
                    ? (v) =>
                          setState(() => _online[p.nrProfessional] = v ?? false)
                    : null,
              ),
            if (can) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  expanded: false,
                  label: Strings.save,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
