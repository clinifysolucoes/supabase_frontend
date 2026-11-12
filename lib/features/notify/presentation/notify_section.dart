import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profiles/application/profiles_controller.dart';
import '../data/notify_repository.dart';
import '../domain/notify_models.dart';

/// Configuracoes > SMS e e-mail: canais, alertas, textos e historico.
class NotifySection extends ConsumerWidget {
  const NotifySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notifySettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NotifyForm(key: ValueKey(s.hashCode), settings: s),
          const SizedBox(height: AppSpacing.md),
          const NotifyHistory(),
        ],
      ),
    );
  }
}

class NotifyForm extends ConsumerStatefulWidget {
  const NotifyForm({super.key, required this.settings});

  final NotifySettings settings;

  @override
  ConsumerState<NotifyForm> createState() => _NotifyFormState();
}

class _NotifyFormState extends ConsumerState<NotifyForm> {
  late final s = widget.settings;
  late bool _email = s.idEmail;
  late bool _sms = s.idSms;
  late final _fromName = TextEditingController(text: s.vcEmailFromName ?? '');
  late final _replyTo = TextEditingController(text: s.vcEmailReplyTo ?? '');
  late bool _reminder = s.idReminder;
  late final _hours = TextEditingController(text: '${s.qtReminderHours}');
  late final _tplReminder = TextEditingController(text: s.vcTplReminder);
  late bool _booked = s.idBooked;
  late final _tplBooked = TextEditingController(text: s.vcTplBooked);
  late bool _return = s.idReturn;
  late final _tplReturn = TextEditingController(text: s.vcTplReturn);
  late final _sendHour = TextEditingController(text: '${s.qtSendHour}');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _fromName,
      _replyTo,
      _hours,
      _tplReminder,
      _tplBooked,
      _tplReturn,
      _sendHour,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final c = ref.read(currentCompanyProvider);
    final b = ref.read(currentBranchNumberProvider);
    if (c == null || b == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(notifyRepositoryProvider).save(c, b, {
        'id_email': _email,
        'id_sms': _sms,
        'vc_email_from_name': _fromName.text.trim(),
        'vc_email_reply_to': _replyTo.text.trim(),
        'id_reminder': _reminder,
        'qt_reminder_hours': int.tryParse(_hours.text.trim()),
        'vc_tpl_reminder': _tplReminder.text,
        'id_booked': _booked,
        'vc_tpl_booked': _tplBooked.text,
        'id_return': _return,
        'vc_tpl_return': _tplReturn.text,
        'qt_send_hour': int.tryParse(_sendHour.text.trim()),
      });
      ref.invalidate(notifySettingsProvider);
      if (mounted) AppSnack.success(context, Strings.savedSuccess);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
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
          if (value) ...[
            if (extra != null) ...[
              SizedBox(width: 220, child: extra),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppTextField(
              label: Strings.ntText,
              controller: template,
              enabled: can,
              maxLength: 500,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            Text(
              Strings.ntPreview(
                notifyPreview(template.text, clinic: s.vcClinic),
              ),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final can = s.canUpdate;
    TextStyle? h(BuildContext c) =>
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.settingsNotify,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              Strings.ntHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.email_outlined),
              title: const Text(Strings.ntEmailEnabled),
              subtitle: const Text(Strings.ntEmailHint),
              value: _email,
              onChanged: can ? (v) => setState(() => _email = v) : null,
            ),
            if (_email)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: Strings.ntFromName,
                      hint: s.vcClinic,
                      controller: _fromName,
                      enabled: can,
                      maxLength: 80,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: Strings.ntReplyTo,
                      helperText: Strings.ntReplyToHint,
                      controller: _replyTo,
                      enabled: can,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.sms_outlined),
              title: const Text(Strings.ntSmsEnabled),
              subtitle: const Text(Strings.ntSmsHint),
              value: _sms,
              onChanged: can ? (v) => setState(() => _sms = v) : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.waAlerts, style: h(context)),
            Text(
              Strings.ntFields(notifyFields.join('  ')),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            _alert(
              title: Strings.waReminder,
              hint: Strings.ntReminderHint,
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
              title: Strings.waReturn,
              hint: Strings.waReturnHint,
              value: _return,
              onChanged: (v) => setState(() => _return = v),
              template: _tplReturn,
              extra: AppTextField(
                label: Strings.waSendHour,
                controller: _sendHour,
                enabled: can,
                keyboardType: TextInputType.number,
              ),
            ),
            if (can)
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  expanded: false,
                  label: Strings.save,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            if (s.totals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final e in s.totals.entries)
                    Chip(
                      label: Text(
                        '${NotifyChannel.label(e.key.$1)} · '
                        '${NotifyStatus.label(e.key.$2)}: ${e.value}',
                      ),
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

class NotifyHistory extends ConsumerWidget {
  const NotifyHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final channel = ref.watch(notifyChannelFilterProvider);
    final status = ref.watch(notifyStatusFilterProvider);
    final async = ref.watch(notifyMessagesProvider);
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
                  onPressed: () => ref.invalidate(notifyMessagesProvider),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text(Strings.trashAll),
                  selected: channel == null,
                  onSelected: (_) =>
                      ref.read(notifyChannelFilterProvider.notifier).state =
                          null,
                ),
                for (final c in [NotifyChannel.email, NotifyChannel.sms])
                  ChoiceChip(
                    label: Text(NotifyChannel.label(c)),
                    selected: channel == c,
                    onSelected: (_) =>
                        ref.read(notifyChannelFilterProvider.notifier).state =
                            c,
                  ),
                const SizedBox(width: AppSpacing.sm),
                for (final st in NotifyStatus.all)
                  FilterChip(
                    label: Text(NotifyStatus.label(st)),
                    selected: status == st,
                    onSelected: (v) =>
                        ref.read(notifyStatusFilterProvider.notifier).state = v
                        ? st
                        : null,
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
                              m.itChannel == NotifyChannel.email
                                  ? Icons.email_outlined
                                  : Icons.sms_outlined,
                              color: m.itStatus == NotifyStatus.error
                                  ? AppColors.danger
                                  : AppColors.primary,
                            ),
                            title: Text(
                              '${NotifyKind.label(m.itKind)} · ${m.vcPatient}',
                            ),
                            subtitle: Text(
                              [
                                Dates.formatTime(m.dhCreated),
                                m.vcTo,
                                if (m.dhAppointment != null)
                                  '${Strings.waAppointment} ${Dates.formatTime(m.dhAppointment)}',
                                if (m.dhConfirmed != null)
                                  Strings.ntConfirmedAt(
                                    Dates.formatTime(m.dhConfirmed),
                                  ),
                                if (m.vcError != null) m.vcError!,
                              ].join(' · '),
                            ),
                            trailing: Text(NotifyStatus.label(m.itStatus)),
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
