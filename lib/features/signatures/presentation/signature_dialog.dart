import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/validators/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/signature_repository.dart';
import '../domain/signature_models.dart';
import 'signature_pad.dart';

/// Coleta de assinaturas na tela: lista as ja feitas e abre o quadro para uma
/// nova (quem assina, nome, CPF, aceite). Devolve true se gravou alguma.
class SignatureDialog extends ConsumerStatefulWidget {
  const SignatureDialog({
    super.key,
    required this.signatureKey,
    required this.title,
    this.patientName,
    this.patientCpf,
    this.canSign = true,
  });

  final SignatureKey signatureKey;
  final String title;
  final String? patientName;
  final String? patientCpf;
  final bool canSign;

  static Future<bool> show(
    BuildContext context, {
    required SignatureKey signatureKey,
    required String title,
    String? patientName,
    String? patientCpf,
    bool canSign = true,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SignatureDialog(
          signatureKey: signatureKey,
          title: title,
          patientName: patientName,
          patientCpf: patientCpf,
          canSign: canSign,
        ),
      ) ??
      false;

  @override
  ConsumerState<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends ConsumerState<SignatureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pad = SignaturePadController();
  late final _name = TextEditingController(text: widget.patientName ?? '');
  late final _cpf = TextEditingController(
    text: widget.patientCpf == null
        ? ''
        : Masks.format(MaskType.cpf, widget.patientCpf!),
  );
  SignerRole _role = SignerRole.patient;
  bool _consent = false;
  bool _saving = false;
  bool _signedAny = false;
  SignatureList? _list;
  static const _padSize = Size(560, 200);

  SignatureRepository get _repo => ref.read(signatureRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pad.dispose();
    _name.dispose();
    _cpf.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await _repo.list(widget.signatureKey);
      if (mounted) setState(() => _list = l);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    }
  }

  void _setRole(SignerRole r) => setState(() {
    _role = r;
    if (r == SignerRole.patient) {
      _name.text = widget.patientName ?? '';
      _cpf.text = widget.patientCpf == null
          ? ''
          : Masks.format(MaskType.cpf, widget.patientCpf!);
    } else {
      _name.clear();
      _cpf.clear();
    }
  });

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pad.isEmpty) {
      AppSnack.error(context, Strings.signatureEmpty);
      return;
    }
    if (!_consent) {
      AppSnack.error(context, Strings.signatureConsentRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final png = await _pad.toPng(_padSize);
      final cpf = Masks.unmask(_cpf.text);
      await _repo.save(
        widget.signatureKey,
        role: _role,
        name: _name.text.trim(),
        cpf: cpf.isEmpty ? null : cpf,
        image: Signature.dataUrl(png),
      );
      _signedAny = true;
      _pad.clear();
      _consent = false;
      if (mounted) AppSnack.success(context, Strings.signatureSaved);
      await _load();
      if (mounted) _setRole(SignerRole.professional);
    } catch (e) {
      if (mounted) AppSnack.error(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _list;
    return AlertDialog(
      title: Text('${Strings.signatures} · ${widget.title}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list == null)
                  const LinearProgressIndicator()
                else if (list.signatures.isEmpty)
                  const Text(
                    Strings.noSignatures,
                    style: TextStyle(color: AppColors.muted),
                  )
                else ...[
                  if (list.hasInvalid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        Strings.signatureChanged,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: theme.textTheme.bodySmall?.fontSize,
                        ),
                      ),
                    ),
                  for (final s in list.signatures)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 96,
                        height: 40,
                        child: s.imageBytes == null
                            ? const Icon(Icons.draw_outlined)
                            : Image.memory(s.imageBytes!, fit: BoxFit.contain),
                      ),
                      title: Text('${s.vcSignerName} · ${s.role.label}'),
                      subtitle: Text(
                        [
                          Dates.formatTime(s.dhSigned),
                          if (s.vcSignerCpf != null)
                            'CPF ${Masks.format(MaskType.cpf, s.vcSignerCpf!)}',
                          if (!s.idValid) Strings.signatureInvalidShort,
                        ].join(' · '),
                      ),
                      trailing: Icon(
                        s.idValid
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                        color: s.idValid ? AppColors.success : AppColors.danger,
                      ),
                    ),
                ],
                if (widget.canSign) ...[
                  const Divider(height: AppSpacing.lg),
                  Text(
                    Strings.newSignature,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final r in SignerRole.values)
                        ChoiceChip(
                          label: Text(r.label),
                          selected: _role == r,
                          onSelected: (_) => _setRole(r),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          label: Strings.signerName,
                          controller: _name,
                          maxLength: 120,
                          validator: Validators.compose([
                            Validators.required(),
                            Validators.minLength(3),
                          ]),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          label: Strings.cpfOptional,
                          controller: _cpf,
                          mask: MaskType.cpf,
                          validator: Validators.cpf(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Strings.signHere,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pad.clear,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(Strings.clear),
                      ),
                    ],
                  ),
                  Center(
                    child: SizedBox(
                      width: _padSize.width,
                      child: SignaturePad(
                        controller: _pad,
                        height: _padSize.height,
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    title: Text(
                      Strings.signatureConsent,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          expanded: false,
          label: Strings.close,
          variant: AppButtonVariant.text,
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(_signedAny),
        ),
        if (widget.canSign)
          AppButton(
            expanded: false,
            label: Strings.sign,
            icon: Icons.draw_rounded,
            loading: _saving,
            onPressed: _save,
          ),
      ],
    );
  }
}
