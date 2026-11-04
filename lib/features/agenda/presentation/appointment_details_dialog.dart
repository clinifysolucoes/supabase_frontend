import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../finance/presentation/checkout_dialog.dart';
import '../../session/application/permissions.dart';
import '../../session/domain/screen_codes.dart';
import '../application/agenda_controllers.dart';
import '../domain/agenda_models.dart';
import 'appointment_form_dialog.dart';

/// Detalhe de uma consulta ou compromisso: quem, quando, com quem, situacao
/// (troca na hora), editar, cancelar e abrir a ficha do paciente.
class AppointmentDetailsDialog extends ConsumerStatefulWidget {
  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
    required this.professionals,
  });

  final Appointment appointment;
  final List<Professional> professionals;

  static Future<void> show(
    BuildContext context, {
    required Appointment appointment,
    required List<Professional> professionals,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AppointmentDetailsDialog(
        appointment: appointment,
        professionals: professionals,
      ),
    );
    if (action == 'checkout' && context.mounted) {
      await CheckoutDialog.show(context, appointment.nrAppointment);
      return;
    }
    // editar abre o formulario com o contexto de quem chamou (o detalhe ja fechou)
    if (action != 'edit' || !context.mounted) return;
    final saved = await AppointmentFormDialog.show(
      context,
      appointment: appointment,
      professionals: professionals,
    );
    if (saved && context.mounted) {
      AppSnack.success(context, Strings.savedSuccess);
    }
  }

  @override
  ConsumerState<AppointmentDetailsDialog> createState() =>
      _AppointmentDetailsDialogState();
}

class _AppointmentDetailsDialogState
    extends ConsumerState<AppointmentDetailsDialog> {
  late int _status = widget.appointment.itStatus;
  bool _busy = false;

  Appointment get _a => widget.appointment;

  Future<void> _setStatus(int status) async {
    if (_busy || status == _status) return;
    setState(() => _busy = true);
    try {
      await ref.read(appointmentsProvider.notifier).change(_a.nrAppointment, {
        'it_status': status,
      });
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await AppConfirmDialog.show(
      context,
      title: Strings.cancelAppointment,
      message: Strings.cancelAppointmentConfirm,
      confirmLabel: Strings.cancelAppointment,
    );
    if (!ok || !mounted) return;
    await _setStatus(AppointmentStatus.cancelled);
    if (mounted) Navigator.of(context).pop();
  }

  void _edit() => Navigator.of(context).pop('edit');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUpdate = ref.watch(canUpdateProvider(ScreenCodes.agenda));
    final canPatients = ref.watch(canReadProvider(ScreenCodes.patients));
    final canFinance = ref.watch(canReadProvider(ScreenCodes.finance));
    final seal = _a.itFinStatus;
    final showCheckout =
        canFinance &&
        _a.isConsultation &&
        _status != AppointmentStatus.cancelled &&
        _status != AppointmentStatus.noShow;
    final color = _a.vcProfessionalColor == null
        ? AppColors.muted
        : Color(AgendaColors.argb(_a.vcProfessionalColor!));
    final when = _a.idAllDay
        ? '${Dates.format(_a.dhStart)} · ${Strings.allDay}'
        : '${Dates.format(_a.dhStart)} · '
              '${DayMinutes.range(_a.startMinute, _a.endMinute)}';

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _a.headline,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _a.isConsultation
                              ? Strings.consultation
                              : Strings.commitment,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              line(Icons.event_rounded, when),
              line(
                Icons.badge_outlined,
                _a.isClinicWide
                    ? Strings.forWholeClinic
                    : (_a.vcProfessionalName ?? '-'),
              ),
              if (_a.vcPatientMobile != null)
                line(
                  Icons.phone_iphone_rounded,
                  Masks.format(MaskType.phone, _a.vcPatientMobile!),
                ),
              if (_a.isConsultation && (_a.vcTitle ?? '').isNotEmpty)
                line(Icons.short_text_rounded, _a.vcTitle!),
              if (_a.vcProcedureName != null)
                line(Icons.medical_services_outlined, _a.vcProcedureName!),
              if ((_a.vcNotes ?? '').isNotEmpty)
                line(Icons.notes_rounded, _a.vcNotes!),
              if (_a.idFitIn) line(Icons.call_split_rounded, Strings.fitIn),
              if (_a.isConsultation) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  Strings.appointmentStatus,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final s in AppointmentStatus.all)
                      if (s != AppointmentStatus.cancelled)
                        ChoiceChip(
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(AppointmentStatus.color(s)),
                          ),
                          label: Text(AppointmentStatus.label(s)),
                          selected: _status == s,
                          onSelected: canUpdate && !_busy
                              ? (_) => _setStatus(s)
                              : null,
                        ),
                  ],
                ),
              ],
              if (seal != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money_rounded,
                      size: 18,
                      color: Color(FinSeal.color(seal)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      FinSeal.label(seal),
                      style: TextStyle(
                        color: Color(FinSeal.color(seal)),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              if (_a.vcCreatedBy != null && _a.dhCreated != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  Strings.scheduledBy(
                    _a.vcCreatedBy!,
                    Dates.formatTime(_a.dhCreated),
                  ),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (showCheckout)
                    AppButton(
                      label: seal == FinSeal.open || seal == FinSeal.paid
                          ? Strings.checkoutView
                          : Strings.checkoutAction,
                      icon: Icons.point_of_sale_rounded,
                      expanded: false,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop('checkout'),
                    ),
                  if (_a.nrPatient != null && canPatients)
                    AppButton(
                      label: Strings.openPatientRecord,
                      icon: Icons.contact_page_outlined,
                      variant: AppButtonVariant.secondary,
                      expanded: false,
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(AppRoutes.patient(_a.nrPatient!));
                      },
                    ),
                  if (canUpdate)
                    AppButton(
                      label: Strings.edit,
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.secondary,
                      expanded: false,
                      onPressed: _busy ? null : _edit,
                    ),
                  if (canUpdate && !_a.isCancelled)
                    AppButton(
                      label: Strings.cancelAppointment,
                      icon: Icons.event_busy_rounded,
                      variant: AppButtonVariant.text,
                      expanded: false,
                      onPressed: _busy ? null : _cancel,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
