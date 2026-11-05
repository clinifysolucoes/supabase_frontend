import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../shared/formatters/masks.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/finance_models.dart';
import '../domain/phase4_models.dart';

/// Campos dos dados do pagamento (vao para os recebiveis): cartao de
/// credito/debito (bandeira, 4 ultimos digitos, autorizacao, titular e CPF)
/// ou cheque (banco, numero, emitente e CPF). Quem usa guarda o controller e
/// le [PaymentDetailsController.value] ao confirmar.
class PaymentDetailsController {
  final brand = TextEditingController();
  final last4 = TextEditingController();
  final authorization = TextEditingController();
  final holder = TextEditingController();
  final document = TextEditingController();
  final bank = TextEditingController();
  final checkNumber = TextEditingController();

  /// Dados para a forma [method] (so os campos dela).
  PaymentDetails value(int? method) => switch (method) {
    PaymentMethod.credit || PaymentMethod.debit => PaymentDetails(
      vcCardBrand: brand.text,
      vcCardLast4: last4.text,
      vcAuthorization: authorization.text,
      vcHolderName: holder.text,
      vcHolderDocument: Masks.unmask(document.text),
    ),
    PaymentMethod.check => PaymentDetails(
      vcBankName: bank.text,
      vcCheckNumber: checkNumber.text,
      vcHolderName: holder.text,
      vcHolderDocument: Masks.unmask(document.text),
    ),
    _ => const PaymentDetails(),
  };

  void dispose() {
    for (final c in [
      brand,
      last4,
      authorization,
      holder,
      document,
      bank,
      checkNumber,
    ]) {
      c.dispose();
    }
  }
}

/// Bloco recolhivel com os campos da forma de pagamento (nada para as outras).
class PaymentDetailsFields extends StatelessWidget {
  const PaymentDetailsFields({
    super.key,
    required this.controller,
    required this.method,
  });

  final PaymentDetailsController controller;
  final int? method;

  static bool appliesTo(int? method) =>
      method == PaymentMethod.credit ||
      method == PaymentMethod.debit ||
      method == PaymentMethod.check;

  @override
  Widget build(BuildContext context) {
    if (!appliesTo(method)) return const SizedBox.shrink();
    final c = controller;
    final card = method != PaymentMethod.check;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: b),
      ],
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          Strings.payDetails,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        children: [
          if (card)
            pair(
              AppTextField(
                label: Strings.cardBrand,
                controller: c.brand,
                maxLength: 20,
              ),
              AppTextField(
                label: Strings.cardLast4,
                controller: c.last4,
                maxLength: 4,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final s = (v ?? '').trim();
                  return s.isEmpty || RegExp(r'^[0-9]{4}$').hasMatch(s)
                      ? null
                      : '0000';
                },
              ),
            )
          else
            pair(
              AppTextField(
                label: Strings.checkBank,
                controller: c.bank,
                maxLength: 60,
              ),
              AppTextField(
                label: Strings.checkNumber,
                controller: c.checkNumber,
                maxLength: 20,
              ),
            ),
          if (card)
            AppTextField(
              label: Strings.cardAuth,
              controller: c.authorization,
              maxLength: 30,
            ),
          pair(
            AppTextField(
              label: card ? Strings.holderName : Strings.holderNameCheck,
              controller: c.holder,
              maxLength: 120,
            ),
            AppTextField(
              label: Strings.holderDocument,
              controller: c.document,
              mask: MaskType.cpfCnpj,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }
}
