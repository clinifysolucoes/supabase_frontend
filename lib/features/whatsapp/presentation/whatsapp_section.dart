import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/whatsapp_repository.dart';
import '../domain/whatsapp_models.dart';

final whatsappSettingsProvider = FutureProvider.autoDispose<WhatsappSettings>((
  ref,
) async {
  final c = ref.watch(currentCompanyProvider);
  final b = ref.watch(currentBranchNumberProvider);
  if (c == null || b == null) return const WhatsappSettings();
  return ref.read(whatsappRepositoryProvider).settings(c, b);
});

final whatsappStatusFilterProvider = StateProvider.autoDispose<int?>(
  (_) => null,
);

final whatsappMessagesProvider =
    FutureProvider.autoDispose<WhatsappMessagePage>((ref) async {
      final c = ref.watch(currentCompanyProvider);
      final b = ref.watch(currentBranchNumberProvider);
      if (c == null || b == null) return const WhatsappMessagePage();
      return ref
          .read(whatsappRepositoryProvider)
          .messages(c, b, status: ref.watch(whatsappStatusFilterProvider));
    });

/// Configuracoes > WhatsApp: conexao com a Meta, alertas e historico.
class WhatsappSection extends ConsumerWidget {
  const WhatsappSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(whatsappSettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WhatsappForm(key: ValueKey(s.hashCode), settings: s),
          const SizedBox(height: AppSpacing.md),
          const _MessageHistory(),
        ],
      ),
    );
  }
}

class _WhatsappForm extends ConsumerStatefulWidget {
  const _WhatsappForm({super.key, required this.settings});

  final WhatsappSettings settings;

  @override
  ConsumerState<_WhatsappForm> createState() => _WhatsappFormState();
}

class _WhatsappFormState extends ConsumerState<_WhatsappForm> {
  late final s = widget.settings;
  late bool _enabled = s.idEnabled;
  late final _phoneId = TextEditingController(text: s.vcPhoneNumberId ?? '');
  late final _wabaId = TextEditingController(text: s.vcWabaId ?? '');
  late final _display = TextEditingController(
    text: s.vcDisplayPhone == null
        ? ''
        : Masks.format(MaskType.phone, s.vcDisplayPhone!),
  );
  final _token = TextEditingController();
  late bool _reminder = s.idReminder;
  late final _hours = TextEditingController(text: '${s.qtReminderHours}');
  late final _tplReminder = TextEditingController(text: s.vcTplReminder);
  late bool _booked = s.idBooked;
  late final _tplBooked = TextEditingController(text: s.vcTplBooked);
  late bool _birthday = s.idBirthday;
  late final _tplBirthday = TextEditingController(text: s.vcTplBirthday);
  late bool _return = s.idReturn;
  late final _tplReturn = TextEditingController(text: s.vcTplReturn);
  late final _sendHour = TextEditingController(text: '${s.qtSendHour}');
  final _testTo = TextEditingController();
  bool _saving = false;
  bool _testing = false;

  @override
  void dispose() {
    for (final c in [
      _phoneId,
      _wabaId,
      _display,
      _token,
      _hours,
      _tplReminder,
      _tplBooked,
      _tplBirthday,
      _tplReturn,
      _sendHour,
      _testTo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ({int c, int b})? get _branch {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    return c == null || b == null ? null : (c: c, b: b);
  }

  Future<void> _save() async {
    final x = _branch;
    if (x == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(whatsappRepositoryProvider).save(x.c, x.b, {
        'id_enabled': _enabled,
        'vc_phone_number_id': _phoneId.text.trim(),
        'vc_waba_id': _wabaId.text.trim(),
        'vc_display_phone': Masks.unmask(_display.text),
        if (_token.text.trim().isNotEmpty) 'vc_token': _token.text.trim(),
        'id_reminder': _reminder,
        'qt_reminder_hours': int.tryParse(_hours.text.trim()),
        'vc_tpl_reminder': _tplReminder.text.trim(),
        'id_booked': _booked,
        'vc_tpl_booked': _tplBooked.text.trim(),
        'id_birthday': _birthday,
        'vc_tpl_birthday': _tplBirthday.text.trim(),
        'id_return': _return,
        'vc_tpl_return': _tplReturn.text.trim(),
        'qt_send_hour': int.tryParse(_sendHour.text.trim()),
      });
      _token.clear();
      ref.invalidate(whatsappSettingsProvider);
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final x = _branch;
    if (x == null || Masks.unmask(_testTo.text).length < 10) {
      AppSnack.error(context, Strings.invalidPhone);
      return;
    }
    setState(() => _testing = true);
    try {
      await ref
          .read(whatsappRepositoryProvider)
          .test(x.c, x.b, Masks.unmask(_testTo.text));
      if (mounted) AppSnack.success(context, Strings.waTestSent);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _alert({
    required String title,
    required String hint,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TextEditingController template,
    Widget? extra,
  }) {
    final can = s.canUpdate;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(hint),
            value: value,
            onChanged: can ? onChanged : null,
          ),
          if (value)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: Strings.waTemplate,
                    controller: template,
                    enabled: can,
                    maxLength: 80,
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: extra),
                ],
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final can = s.canUpdate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settingsWhatsapp,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              Strings.waHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(Strings.waEnabled),
              value: _enabled,
              onChanged: can ? (v) => setState(() => _enabled = v) : null,
            ),
            Text(
              Strings.waConnection,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: Strings.waPhoneNumberId,
                    controller: _phoneId,
                    enabled: can,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: Strings.waWabaId,
                    controller: _wabaId,
                    enabled: can,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: Strings.waDisplayPhone,
                    controller: _display,
                    enabled: can,
                    mask: MaskType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: Strings.waToken,
              controller: _token,
              enabled: can,
              obscureText: true,
              helperText: s.idToken
                  ? Strings.waTokenSaved(Dates.formatTime(s.dhTokenSaved))
                  : Strings.waTokenMissing,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              Strings.waAlerts,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            _alert(
              title: Strings.waReminder,
              hint: Strings.waReminderHint,
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
              template: _tplReminder,
              extra: AppTextField(
                label: Strings.waReminderHours,
                controller: _hours,
                enabled: can,
                keyboardType: TextInputType.number,
              ),
            ),
            _alert(
              title: Strings.waBooked,
              hint: Strings.waBookedHint,
              value: _booked,
              onChanged: (v) => setState(() => _booked = v),
              template: _tplBooked,
            ),
            _alert(
              title: Strings.waBirthday,
              hint: Strings.waBirthdayHint,
              value: _birthday,
              onChanged: (v) => setState(() => _birthday = v),
              template: _tplBirthday,
            ),
            _alert(
              title: Strings.waReturn,
              hint: Strings.waReturnHint,
              value: _return,
              onChanged: (v) => setState(() => _return = v),
              template: _tplReturn,
            ),
            if (_birthday || _return)
              SizedBox(
                width: 220,
                child: AppTextField(
                  label: Strings.waSendHour,
                  controller: _sendHour,
                  enabled: can,
                  keyboardType: TextInputType.number,
                ),
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
            if (can && s.idToken) ...[
              const Divider(height: AppSpacing.xl),
              Text(
                Strings.waTest,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(Strings.waTestHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: Strings.mobile,
                      controller: _testTo,
                      mask: MaskType.phone,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    expanded: false,
                    label: Strings.waSendTest,
                    icon: Icons.send_rounded,
                    variant: AppButtonVariant.secondary,
                    loading: _testing,
                    onPressed: _test,
                  ),
                ],
              ),
            ],
            if (s.totals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final st in WaStatus.all)
                    if ((s.totals[st] ?? 0) > 0)
                      Chip(
                        label: Text('${WaStatus.label(st)}: ${s.totals[st]}'),
                      ),
                ],
              ),
              Text(Strings.waLast30, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageHistory extends ConsumerWidget {
  const _MessageHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(whatsappStatusFilterProvider);
    final async = ref.watch(whatsappMessagesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.waHistory,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: Strings.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(whatsappMessagesProvider),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text(Strings.trashAll),
                  selected: filter == null,
                  onSelected: (_) =>
                      ref.read(whatsappStatusFilterProvider.notifier).state =
                          null,
                ),
                for (final st in WaStatus.all)
                  ChoiceChip(
                    label: Text(WaStatus.label(st)),
                    selected: filter == st,
                    onSelected: (_) =>
                        ref.read(whatsappStatusFilterProvider.notifier).state =
                            st,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            async.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(describeError(e)),
              data: (p) => p.messages.isEmpty
                  ? const Text(
                      Strings.waNoMessages,
                      style: TextStyle(color: AppColors.muted),
                    )
                  : Column(
                      children: [
                        for (final m in p.messages)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              m.itStatus == WaStatus.error
                                  ? Icons.error_outline
                                  : m.itStatus == WaStatus.read
                                  ? Icons.done_all_rounded
                                  : Icons.chat_outlined,
                              color: m.itStatus == WaStatus.error
                                  ? AppColors.danger
                                  : AppColors.primary,
                            ),
                            title: Text(
                              '${WaKind.label(m.itKind)} · ${m.vcPatient}',
                            ),
                            subtitle: Text(
                              [
                                Dates.formatTime(m.dhCreated),
                                if (m.dhAppointment != null)
                                  '${Strings.waAppointment} ${Dates.formatTime(m.dhAppointment)}',
                                ?m.replyLabel,
                                if (m.vcError != null) m.vcError!,
                              ].join(' · '),
                            ),
                            trailing: Text(WaStatus.label(m.itStatus)),
                          ),
                        if (p.qtTotal > p.messages.length)
                          Text(
                            Strings.waShowing(p.messages.length, p.qtTotal),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
