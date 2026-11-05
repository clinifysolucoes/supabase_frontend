import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_gateway.dart';
import '../domain/company_user.dart';

/// Filtros de `company_user_list`.
class UserFilters {
  const UserFilters({
    this.search,
    this.itStatus,
    this.nrBranch,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? search;
  final int? itStatus;
  final int? nrBranch;
  final int page;
  final int pageSize;

  UserFilters copyWith({
    String? search,
    int? itStatus,
    int? nrBranch,
    int? page,
    bool clearStatus = false,
    bool clearBranch = false,
  }) => UserFilters(
    search: search ?? this.search,
    itStatus: clearStatus ? null : (itStatus ?? this.itStatus),
    nrBranch: clearBranch ? null : (nrBranch ?? this.nrBranch),
    page: page ?? this.page,
    pageSize: pageSize,
  );
}

/// Dados do cadastro de um usuario novo (Edge Function `user-create`).
class NewUser {
  const NewUser({
    required this.name,
    required this.email,
    required this.password,
    required this.branches,
    this.cpf,
    this.phone,
    this.mobile,
  });

  final String name;
  final String email;
  final String password;
  final String? cpf;
  final String? phone;
  final String? mobile;
  final List<BranchAssignment> branches;
}

/// `ad.company_user_list` / `ad.company_user_save` (somente administrador),
/// `ad.branch_list` e a Edge Function `user-create`.
class UserRepository {
  UserRepository(this._gateway);

  final SupabaseGateway _gateway;

  Future<CompanyUserPage> list({
    required int nrCompany,
    UserFilters filters = const UserFilters(),
  }) async {
    final json = await _gateway.rpc('company_user_list', {
      'nr_company': nrCompany,
      if (filters.search != null && filters.search!.trim().isNotEmpty)
        'vc_search': filters.search!.trim(),
      if (filters.itStatus != null) 'it_status': filters.itStatus,
      if (filters.nrBranch != null) 'nr_branch': filters.nrBranch,
      'nr_page': filters.page,
      'qt_page_size': filters.pageSize,
    });
    return CompanyUserPage.fromJson(json);
  }

  Future<List<Branch>> branches({
    required int nrCompany,
    bool includeInactive = false,
  }) async {
    final json = await _gateway.rpc('branch_list', {
      'nr_company': nrCompany,
      'id_include_inactive': includeInactive,
    });
    final items = json['branches'];
    if (items is! List) return const [];
    return [
      for (final b in items)
        Branch.fromJson((b as Map).cast<String, dynamic>()),
    ];
  }

  /// Cadastra o usuario pela empresa: a Edge Function cria a conta no Auth
  /// (se nao existir) e faz o vinculo com filiais x perfis.
  /// Devolve `id_created`: true quando a conta foi criada agora.
  Future<bool> create({
    required int nrCompany,
    int? nrBranch,
    required NewUser user,
  }) async {
    final json = await _gateway.invokeFunction('user-create', {
      'nr_company': nrCompany,
      'nr_branch': nrBranch,
      'vc_name': user.name.trim(),
      'vc_email': user.email.trim().toLowerCase(),
      'vc_password': user.password,
      'vc_cpf': user.cpf,
      'vc_phone': user.phone,
      'vc_mobile': user.mobile,
      'branches': [for (final b in user.branches) b.toJson()],
    });
    return json['id_created'] == true;
  }

  /// Vincula um usuario JA cadastrado no Auth (localizado pelo e-mail).
  Future<int> link({
    required int nrCompany,
    int? nrBranch,
    required String email,
    required List<BranchAssignment> branches,
  }) async {
    final json = await _gateway.rpc('company_user_save', {
      'vc_action': 'I',
      'nr_company': nrCompany,
      if (nrBranch != null) 'nr_branch': nrBranch,
      'vc_email': email.trim(),
      'branches': [for (final b in branches) b.toJson()],
    });
    return (json['nr_user'] as num).toInt();
  }

  /// Situacao/motivo e, se informado, substitui todas as filiais x perfis.
  Future<void> update({
    required int nrCompany,
    int? nrBranch,
    required int nrUser,
    int? itStatus,
    String? blockReason,
    List<BranchAssignment>? branches,
  }) async {
    await _gateway.rpc('company_user_save', {
      'vc_action': 'U',
      'nr_company': nrCompany,
      if (nrBranch != null) 'nr_branch': nrBranch,
      'nr_user': nrUser,
      if (itStatus != null) 'it_status': itStatus,
      if (itStatus != null) 'vc_block_reason': blockReason,
      if (branches != null) 'branches': [for (final b in branches) b.toJson()],
    });
  }

  /// O administrador define uma senha nova (Edge Function user-password-reset).
  Future<void> resetPassword({
    required int nrCompany,
    int? nrBranch,
    required int nrUser,
    required String password,
  }) => _gateway.invokeFunction('user-password-reset', {
    'nr_company': nrCompany,
    'nr_branch': ?nrBranch,
    'nr_user': nrUser,
    'vc_password': password,
  });

  Future<void> unlink({
    required int nrCompany,
    int? nrBranch,
    required int nrUser,
  }) async {
    await _gateway.rpc('company_user_save', {
      'vc_action': 'D',
      'nr_company': nrCompany,
      if (nrBranch != null) 'nr_branch': nrBranch,
      'nr_user': nrUser,
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(supabaseGatewayProvider)),
);
