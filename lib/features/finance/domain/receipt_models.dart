/// Recibo (od.fin_receipt) e o emitente (dados da clinica) de ad.fin_receipt_get.
class Receipt {
  const Receipt({
    required this.nrReceipt,
    required this.vcNumber,
    required this.nrEntry,
    required this.vlAmount,
    required this.dtPaid,
    this.itPaymentMethod,
    this.vcPayerName = '',
    this.vcPayerDocument,
    this.vcDescription = '',
    this.itStatus = 1,
    this.vcCancelReason,
  });

  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
    nrReceipt: (j['nr_receipt'] as num).toInt(),
    vcNumber: '${j['vc_number']}',
    nrEntry: (j['nr_entry'] as num).toInt(),
    vlAmount: (j['vl_amount'] as num).toDouble(),
    dtPaid: DateTime.parse('${j['dt_paid']}'),
    itPaymentMethod: (j['it_payment_method'] as num?)?.toInt(),
    vcPayerName: j['vc_payer_name']?.toString() ?? '',
    vcPayerDocument: j['vc_payer_document']?.toString(),
    vcDescription: j['vc_description']?.toString() ?? '',
    itStatus: (j['it_status'] as num?)?.toInt() ?? 1,
    vcCancelReason: j['vc_cancel_reason']?.toString(),
  );

  final int nrReceipt;
  final String vcNumber;
  final int nrEntry;
  final double vlAmount;
  final DateTime dtPaid;
  final int? itPaymentMethod;
  final String vcPayerName;
  final String? vcPayerDocument;
  final String vcDescription;
  final int itStatus;
  final String? vcCancelReason;

  bool get isCancelled => itStatus == 90;
}

class ReceiptIssuer {
  const ReceiptIssuer({
    this.vcName = '',
    this.vcLegalName,
    this.vcCnpj,
    this.vcPhone,
    this.vcEmail,
    this.vcZipCode,
    this.vcAddress,
    this.vcAddressNumber,
    this.vcAddressExtra,
    this.vcDistrict,
    this.vcCity,
    this.vcState,
    this.vcTechnicalName,
    this.vcTechnicalCro,
    this.vcTechnicalCroState,
  });

  factory ReceiptIssuer.fromJson(Map<String, dynamic> j) {
    String? s(String k) {
      final v = j[k]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return ReceiptIssuer(
      vcName: s('vc_name') ?? '',
      vcLegalName: s('vc_legal_name'),
      vcCnpj: s('vc_cnpj'),
      vcPhone: s('vc_phone'),
      vcEmail: s('vc_email'),
      vcZipCode: s('vc_zip_code'),
      vcAddress: s('vc_address'),
      vcAddressNumber: s('vc_address_number'),
      vcAddressExtra: s('vc_address_extra'),
      vcDistrict: s('vc_district'),
      vcCity: s('vc_city'),
      vcState: s('vc_state'),
      vcTechnicalName: s('vc_technical_name'),
      vcTechnicalCro: s('vc_technical_cro'),
      vcTechnicalCroState: s('vc_technical_cro_state'),
    );
  }

  final String vcName;
  final String? vcLegalName;
  final String? vcCnpj;
  final String? vcPhone;
  final String? vcEmail;
  final String? vcZipCode;
  final String? vcAddress;
  final String? vcAddressNumber;
  final String? vcAddressExtra;
  final String? vcDistrict;
  final String? vcCity;
  final String? vcState;
  final String? vcTechnicalName;
  final String? vcTechnicalCro;
  final String? vcTechnicalCroState;

  /// `Rua A, 10 - sala 2 - Centro - Curitiba/PR`
  String? get addressLine {
    final street = [vcAddress, vcAddressNumber].whereType<String>().join(', ');
    final city = [vcCity, vcState].whereType<String>().join('/');
    final parts = [
      if (street.isNotEmpty) street,
      ?vcAddressExtra,
      ?vcDistrict,
      if (city.isNotEmpty) city,
    ];
    return parts.isEmpty ? null : parts.join(' - ');
  }
}

/// Recibo com o emitente, pronto para o PDF.
class ReceiptDoc {
  const ReceiptDoc({
    required this.receipt,
    required this.issuer,
    this.idExisting = false,
  });

  factory ReceiptDoc.fromJson(Map<String, dynamic> j) => ReceiptDoc(
    receipt: Receipt.fromJson((j['receipt'] as Map).cast<String, dynamic>()),
    issuer: ReceiptIssuer.fromJson(
      (j['issuer'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    idExisting: j['id_existing'] == true,
  );

  final Receipt receipt;
  final ReceiptIssuer issuer;
  final bool idExisting;
}
