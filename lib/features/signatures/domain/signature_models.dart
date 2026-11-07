import 'dart:convert';
import 'dart:typed_data';

/// Assinatura eletronica simples (ad.signature_save / ad.signature_list).

/// O que foi assinado.
enum SignatureTarget {
  document(1),
  budget(2);

  const SignatureTarget(this.code);
  final int code;
}

/// Quem assina.
enum SignerRole {
  patient(1, 'Paciente'),
  guardian(2, 'Responsável legal'),
  professional(3, 'Profissional'),
  witness(4, 'Testemunha');

  const SignerRole(this.code, this.label);
  final int code;
  final String label;

  static SignerRole of(int? code) =>
      values.firstWhere((r) => r.code == code, orElse: () => patient);
}

class Signature {
  const Signature({
    required this.nrSignature,
    required this.role,
    required this.vcSignerName,
    this.vcSignerCpf,
    required this.txImage,
    required this.vcHash,
    required this.uuCode,
    this.dhSigned,
    this.vcIp,
    this.vcUser,
    this.idValid = true,
  });

  factory Signature.fromJson(Map<String, dynamic> j) => Signature(
    nrSignature: (j['nr_signature'] as num).toInt(),
    role: SignerRole.of((j['it_signer'] as num?)?.toInt()),
    vcSignerName: j['vc_signer_name'] as String? ?? '',
    vcSignerCpf: j['vc_signer_cpf'] as String?,
    txImage: j['tx_image'] as String? ?? '',
    vcHash: j['vc_hash'] as String? ?? '',
    uuCode: j['uu_code'] as String? ?? '',
    dhSigned: DateTime.tryParse(j['dh_signed'] as String? ?? '')?.toLocal(),
    vcIp: j['vc_ip'] as String?,
    vcUser: j['vc_user'] as String?,
    idValid: j['id_valid'] as bool? ?? false,
  );

  final int nrSignature;
  final SignerRole role;
  final String vcSignerName;
  final String? vcSignerCpf;

  /// `data:image/png;base64,...`
  final String txImage;
  final String vcHash;
  final String uuCode;
  final DateTime? dhSigned;
  final String? vcIp;
  final String? vcUser;

  /// O conteudo atual tem o mesmo hash da assinatura.
  final bool idValid;

  Uint8List? get imageBytes {
    final i = txImage.indexOf(',');
    if (i < 0) return null;
    try {
      return base64Decode(txImage.substring(i + 1));
    } on FormatException {
      return null;
    }
  }

  /// Data URL do PNG para gravar.
  static String dataUrl(Uint8List png) =>
      'data:image/png;base64,${base64Encode(png)}';
}

class SignatureList {
  const SignatureList({this.signatures = const [], this.vcHashCurrent});

  factory SignatureList.fromJson(Map<String, dynamic> j) => SignatureList(
    signatures: ((j['signatures'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Signature.fromJson)
        .toList(),
    vcHashCurrent: j['vc_hash_current'] as String?,
  );

  final List<Signature> signatures;
  final String? vcHashCurrent;

  bool get hasInvalid => signatures.any((s) => !s.idValid);
}
