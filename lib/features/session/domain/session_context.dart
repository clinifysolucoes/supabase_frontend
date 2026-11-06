import '../../../l10n/strings.dart';
import 'screen_codes.dart';

/// Resposta de `ad.session_context`: usuario, empresas -> filiais -> perfis
/// acessiveis AGORA (com as permissoes por tela), e vinculos sem acesso.
class SessionContext {
  const SessionContext({
    required this.user,
    required this.companies,
    required this.blocked,
  });

  factory SessionContext.fromJson(Map<String, dynamic> json) {
    return SessionContext(
      user: SessionUser.fromJson(_map(json['user'])),
      companies: [
        for (final c in _list(json['companies']))
          CompanyAccess.fromJson(_map(c)),
      ],
      blocked: [
        for (final b in _list(json['blocked']))
          BlockedCompany.fromJson(_map(b)),
      ],
    );
  }

  final SessionUser user;
  final List<CompanyAccess> companies;
  final List<BlockedCompany> blocked;

  bool get hasAccess => companies.isNotEmpty;

  /// Sem empresa e sem bloqueio: primeiro acesso, o app oferece criar empresa.
  bool get isFirstAccess => companies.isEmpty && blocked.isEmpty;

  /// Alguma empresa so libera com 2FA confirmado na sessao.
  bool get requiresMfa =>
      blocked.any((b) => b.vcReasonKey == 'SESSION_MFA_REQUIRED');

  /// Todas as filiais acessiveis, em ordem de empresa e filial.
  List<BranchRef> get branches => [
    for (final c in companies)
      for (final b in c.branches) BranchRef(company: c, branch: b),
  ];

  /// Mais de uma filial acessivel: o app pergunta qual abrir.
  bool get needsSelection => branches.length > 1;

  BranchRef? find(int nrCompany, int nrBranch) {
    for (final ref in branches) {
      if (ref.company.nrCompany == nrCompany &&
          ref.branch.nrBranch == nrBranch) {
        return ref;
      }
    }
    return null;
  }
}

class SessionUser {
  const SessionUser({
    required this.nrUser,
    required this.vcName,
    required this.itLevel,
    this.vcEmail,
    this.vcAvatarUrl,
    this.dhLastLogin,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    nrUser: _int(json['nr_user']),
    vcName: _str(json['vc_name']) ?? '',
    vcEmail: _str(json['vc_email']),
    vcAvatarUrl: _str(json['vc_avatar_url']),
    itLevel: _int(json['it_level'] ?? 0),
    dhLastLogin: DateTime.tryParse(_str(json['dh_last_login']) ?? ''),
  );

  final int nrUser;
  final String vcName;
  final String? vcEmail;
  final String? vcAvatarUrl;
  final int itLevel;
  final DateTime? dhLastLogin;

  /// `it_level` 100 = administrador da plataforma.
  bool get isPlatformAdmin => itLevel >= 100;

  String get initials {
    final parts = vcName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

class CompanyAccess {
  const CompanyAccess({
    required this.nrCompany,
    required this.vcName,
    required this.nrCompanyUser,
    required this.idAdmin,
    required this.branches,
    this.vcCnpj,
  });

  factory CompanyAccess.fromJson(Map<String, dynamic> json) => CompanyAccess(
    nrCompany: _int(json['nr_company']),
    vcName: _str(json['vc_name']) ?? '',
    vcCnpj: _str(json['vc_cnpj']),
    nrCompanyUser: _int(json['nr_company_user']),
    idAdmin: json['id_admin'] == true,
    branches: [
      for (final b in _list(json['branches'])) BranchAccess.fromJson(_map(b)),
    ],
  );

  final int nrCompany;
  final String vcName;
  final String? vcCnpj;
  final int nrCompanyUser;

  /// Administrador da empresa (perfil nivel 100 em alguma filial acessivel).
  final bool idAdmin;
  final List<BranchAccess> branches;

  BranchAccess? get mainBranch {
    for (final b in branches) {
      if (b.idMain) return b;
    }
    return branches.isEmpty ? null : branches.first;
  }
}

/// Permissao efetiva do usuario numa tela, nesta filial.
class ScreenPermission {
  const ScreenPermission({
    required this.uuScreen,
    required this.vcCode,
    required this.vcName,
    required this.idRead,
    required this.idCreate,
    required this.idUpdate,
  });

  factory ScreenPermission.fromJson(Map<String, dynamic> json) =>
      ScreenPermission(
        uuScreen: _str(json['uu_screen']) ?? '',
        vcCode: _str(json['vc_code']) ?? '',
        vcName: _str(json['vc_name']) ?? '',
        idRead: json['id_read'] != false,
        idCreate: json['id_create'] == true,
        idUpdate: json['id_update'] == true,
      );

  final String uuScreen;
  final String vcCode;
  final String vcName;
  final bool idRead;
  final bool idCreate;
  final bool idUpdate;
}

class BranchAccess {
  const BranchAccess({
    required this.nrBranch,
    required this.vcName,
    required this.idMain,
    required this.itLevel,
    required this.profiles,
    this.permissions = const [],
    this.vcCnpj,
    this.vcTimezone,
  });

  factory BranchAccess.fromJson(Map<String, dynamic> json) => BranchAccess(
    nrBranch: _int(json['nr_branch']),
    vcName: _str(json['vc_name']) ?? '',
    vcCnpj: _str(json['vc_cnpj']),
    vcTimezone: _str(json['vc_timezone']),
    idMain: json['id_main'] == true,
    itLevel: _int(json['it_level'] ?? 0),
    profiles: [
      for (final p in _list(json['profiles'])) ProfileAccess.fromJson(_map(p)),
    ],
    permissions: [
      for (final p in _list(json['permissions']))
        ScreenPermission.fromJson(_map(p)),
    ],
  );

  final int nrBranch;
  final String vcName;
  final String? vcCnpj;
  final String? vcTimezone;
  final bool idMain;

  /// Maior nivel entre os perfis do usuario nesta filial.
  final int itLevel;
  final List<ProfileAccess> profiles;

  /// Telas que o usuario pode usar nesta filial (uniao dos perfis).
  /// Administrador (nivel 100) recebe todas do backend; aqui tambem e
  /// tratado como "tudo" por seguranca.
  final List<ScreenPermission> permissions;

  bool get isAdmin => itLevel >= 100;

  ScreenPermission? permission(String code) {
    for (final p in permissions) {
      if (p.vcCode == code) return p;
    }
    return null;
  }

  bool canRead(String code) =>
      isAdmin ||
      code == ScreenCodes.dashboard ||
      (permission(code)?.idRead ?? false);

  bool canCreate(String code) =>
      isAdmin || (permission(code)?.idCreate ?? false);

  bool canUpdate(String code) =>
      isAdmin || (permission(code)?.idUpdate ?? false);
}

class ProfileAccess {
  const ProfileAccess({
    required this.nrProfile,
    required this.vcName,
    required this.itLevel,
  });

  factory ProfileAccess.fromJson(Map<String, dynamic> json) => ProfileAccess(
    nrProfile: _int(json['nr_profile']),
    vcName: _str(json['vc_name']) ?? '',
    itLevel: _int(json['it_level'] ?? 0),
  );

  final int nrProfile;
  final String vcName;
  final int itLevel;
}

class BlockedCompany {
  const BlockedCompany({
    required this.nrCompany,
    required this.vcName,
    required this.vcReasonKey,
    this.vcReason,
  });

  factory BlockedCompany.fromJson(Map<String, dynamic> json) => BlockedCompany(
    nrCompany: _int(json['nr_company']),
    vcName: _str(json['vc_name']) ?? '',
    vcReasonKey: _str(json['vc_reason_key']) ?? 'UNKNOWN',
    vcReason: _str(json['vc_reason']),
  );

  final int nrCompany;
  final String vcName;
  final String vcReasonKey;
  final String? vcReason;

  String get message =>
      Strings.errorMessage(vcReasonKey, {'Reason': vcReason ?? ''});
}

/// Par empresa + filial escolhido para trabalhar.
class BranchRef {
  const BranchRef({required this.company, required this.branch});

  final CompanyAccess company;
  final BranchAccess branch;

  int get nrCompany => company.nrCompany;
  int get nrBranch => branch.nrBranch;
  bool get isAdmin => branch.isAdmin;
  String get label => '${company.vcName} · ${branch.vcName}';

  bool canRead(String code) => branch.canRead(code);
  bool canCreate(String code) => branch.canCreate(code);
  bool canUpdate(String code) => branch.canUpdate(code);

  @override
  bool operator ==(Object other) =>
      other is BranchRef &&
      other.nrCompany == nrCompany &&
      other.nrBranch == nrBranch;

  @override
  int get hashCode => Object.hash(nrCompany, nrBranch);
}

// --- helpers de parse (jsonb numerico pode chegar como int ou double) --------

int _int(dynamic value) => (value as num).toInt();

String? _str(dynamic value) => value?.toString();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<dynamic> _list(dynamic value) => value is List ? value : const [];
