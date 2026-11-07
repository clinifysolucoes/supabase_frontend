import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/online_booking_repository.dart';
import '../domain/online_booking_models.dart';

/// Pagina publica de agendamento (`/agendar/<slug>`), sem login: profissional,
/// dia, horario livre e dados do paciente.
class OnlineBookingPage extends ConsumerStatefulWidget {
  const OnlineBookingPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<OnlineBookingPage> createState() => _OnlineBookingPageState();
}

class _OnlineBookingPageState extends ConsumerState<OnlineBookingPage> {
  OnlineClinic? _clinic;
  String? _loadError;
  OnlineProfessional? _prof;
  DateTime? _day;
  List<String>? _slots;
  bool _loadingSlots = false;
  String? _slot;
  OnlineBookingResult? _done;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _birth = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final _website = TextEditingController();

  OnlineBookingRepository get _repo =>
      ref.read(onlineBookingRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _cpf, _birth, _mobile, _email, _notes, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final c = await _repo.info(widget.slug);
      if (!mounted) return;
      setState(() {
        _clinic = c;
        if (c.professionals.length == 1) _prof = c.professionals.single;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = describeError(e));
    }
  }

  Future<void> _pickDay(DateTime d) async {
    final p = _prof;
    if (p == null) return;
    setState(() {
      _day = d;
      _slot = null;
      _slots = null;
      _loadingSlots = true;
    });
    try {
      final s = await _repo.slots(widget.slug, p.nrProfessional, d);
      if (mounted && _day == d) setState(() => _slots = s);
    } catch (e) {
      if (mounted) _error(describeError(e));
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _error(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
  );

  Future<void> _book() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final p = _prof;
    final d = _day;
    final s = _slot;
    if (p == null || d == null || s == null) return;
    setState(() => _saving = true);
    try {
      final r = await _repo.book(widget.slug, {
        'nr_professional': p.nrProfessional,
        'dh_start': '${Dates.toIso(d)} $s',
        'vc_name': _name.text.trim(),
        'vc_cpf': Masks.unmask(_cpf.text),
        'dt_birth': Dates.toIso(Dates.parseField(_birth.text)!),
        'vc_mobile': Masks.unmask(_mobile.text),
        if (_email.text.trim().isNotEmpty) 'vc_email': _email.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'vc_notes': _notes.text.trim(),
        'website': _website.text,
      });
      if (mounted) setState(() => _done = r);
    } catch (e) {
      if (!mounted) return;
      _error(describeError(e));
      // horario pode ter sido ocupado: recarrega
      if (_day != null) await _pickDay(_day!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _clinic;
    Widget body;
    if (_loadError != null) {
      body = _Message(
        icon: Icons.event_busy_rounded,
        title: Strings.onlineUnavailable,
        text: _loadError!,
        action: TextButton(onPressed: _load, child: const Text(Strings.retry)),
      );
    } else if (c == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_done != null) {
      final r = _done!;
      final when = DateTime.tryParse(r.dhStart.replaceFirst(' ', 'T'));
      body = _Message(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        title: Strings.onlineBooked,
        text: Strings.onlineBookedText(
          when == null ? r.dhStart : Dates.formatTime(when),
          r.vcProfessional,
          r.vcClinic,
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.vcMessage != null && c.vcMessage!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(c.vcMessage!),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _Step(number: 1, title: Strings.onlineChooseProfessional),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in c.professionals)
                ChoiceChip(
                  label: Text(
                    p.vcCouncil == null
                        ? p.vcName
                        : '${p.vcName} · ${p.vcCouncil}',
                  ),
                  selected: _prof?.nrProfessional == p.nrProfessional,
                  onSelected: (_) {
                    setState(() {
                      _prof = p;
                      _slots = null;
                      _slot = null;
                    });
                    if (_day != null) _pickDay(_day!);
                  },
                ),
            ],
          ),
          if (_prof != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Step(number: 2, title: Strings.onlineChooseDay),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in c.days)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Strings.weekdayShort(d.weekday),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        selected: _day == d,
                        onSelected: (_) => _pickDay(d),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_day != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Step(number: 3, title: Strings.onlineChooseTime),
            if (_loadingSlots)
              const LinearProgressIndicator()
            else if ((_slots ?? const []).isEmpty)
              const Text(
                Strings.onlineNoSlots,
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final s in _slots!)
                    ChoiceChip(
                      label: Text(s),
                      selected: _slot == s,
                      onSelected: (_) => setState(() => _slot = s),
                    ),
                ],
              ),
          ],
          if (_slot != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Step(number: 4, title: Strings.onlineYourData),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: Strings.fullName,
                    controller: _name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.compose([
                      Validators.required(),
                      Validators.minLength(3),
                    ]),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: Strings.cpf,
                          controller: _cpf,
                          mask: MaskType.cpf,
                          keyboardType: TextInputType.number,
                          validator: Validators.compose([
                            Validators.required(),
                            Validators.cpf(),
                          ]),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: Strings.birthDate,
                          controller: _birth,
                          mask: MaskType.date,
                          keyboardType: TextInputType.number,
                          validator: Validators.compose([
                            Validators.required(),
                            Validators.date(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: Strings.mobile,
                          controller: _mobile,
                          mask: MaskType.phone,
                          keyboardType: TextInputType.phone,
                          validator: Validators.compose([
                            Validators.required(),
                            Validators.phone(),
                          ]),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: Strings.emailOptional,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: Strings.onlineReason,
                    controller: _notes,
                    maxLength: 500,
                    maxLines: 3,
                  ),
                  // campo isca: invisivel para pessoas, robos preenchem
                  Offstage(child: TextField(controller: _website)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Strings.onlinePrivacy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: Strings.onlineConfirm(
                      '${_day!.day.toString().padLeft(2, '0')}/${_day!.month.toString().padLeft(2, '0')} $_slot',
                    ),
                    icon: Icons.event_available_rounded,
                    loading: _saving,
                    expanded: true,
                    onPressed: _book,
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        c?.vcName ?? Strings.onlineTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (c != null)
                        Text(
                          [
                            if (c.vcAddress != null) c.vcAddress!,
                            if (c.vcCity != null)
                              [
                                c.vcCity,
                                c.vcState,
                              ].whereType<String>().join('/'),
                            if (c.vcPhone != null)
                              Masks.format(MaskType.phone, c.vcPhone!),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        Strings.onlineTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(height: AppSpacing.lg),
                      body,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.primary,
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    this.color = AppColors.muted,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Column(
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(text, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
