import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/user_repository.dart';
import '../domain/company_user.dart';

/// Filtros da tela de usuarios (busca, situacao, filial, pagina).
final userFiltersProvider = StateProvider.autoDispose<UserFilters>(
  (ref) => const UserFilters(),
);

/// Filiais ativas da empresa atual (administrador ve todas).
final branchesProvider = FutureProvider.autoDispose<List<Branch>>((ref) async {
  final nrCompany = ref.watch(currentCompanyProvider);
  if (nrCompany == null) return const [];
  return ref.read(userRepositoryProvider).branches(nrCompany: nrCompany);
});

/// Pagina de usuarios da empresa atual conforme os filtros.
class UsersController extends AutoDisposeAsyncNotifier<CompanyUserPage> {
  @override
  Future<CompanyUserPage> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final filters = ref.watch(userFiltersProvider);
    if (nrCompany == null) {
      return const CompanyUserPage(total: 0, page: 1, pageSize: 50, users: []);
    }
    return ref
        .read(userRepositoryProvider)
        .list(nrCompany: nrCompany, filters: filters);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  int? get _nrBranch => ref.read(currentBranchNumberProvider);

  /// Cadastra (cria a conta se preciso) e vincula. true = conta criada agora.
  Future<bool> create(NewUser user) async {
    final nrCompany = ref.read(currentCompanyProvider);
    if (nrCompany == null) return false;
    final created = await ref
        .read(userRepositoryProvider)
        .create(nrCompany: nrCompany, nrBranch: _nrBranch, user: user);
    await refresh();
    return created;
  }

  Future<void> link({
    required String email,
    required List<BranchAssignment> branches,
  }) async {
    final nrCompany = ref.read(currentCompanyProvider);
    if (nrCompany == null) return;
    await ref
        .read(userRepositoryProvider)
        .link(
          nrCompany: nrCompany,
          nrBranch: _nrBranch,
          email: email,
          branches: branches,
        );
    await refresh();
  }

  Future<void> updateUser({
    required int nrUser,
    int? itStatus,
    String? blockReason,
    List<BranchAssignment>? branches,
  }) async {
    final nrCompany = ref.read(currentCompanyProvider);
    if (nrCompany == null) return;
    await ref
        .read(userRepositoryProvider)
        .update(
          nrCompany: nrCompany,
          nrBranch: _nrBranch,
          nrUser: nrUser,
          itStatus: itStatus,
          blockReason: blockReason,
          branches: branches,
        );
    await refresh();
  }

  Future<void> resetPassword({
    required int nrUser,
    required String password,
  }) async {
    final nrCompany = ref.read(currentCompanyProvider);
    if (nrCompany == null) return;
    await ref
        .read(userRepositoryProvider)
        .resetPassword(
          nrCompany: nrCompany,
          nrBranch: _nrBranch,
          nrUser: nrUser,
          password: password,
        );
  }

  Future<void> unlink({required int nrUser}) async {
    final nrCompany = ref.read(currentCompanyProvider);
    if (nrCompany == null) return;
    await ref
        .read(userRepositoryProvider)
        .unlink(nrCompany: nrCompany, nrBranch: _nrBranch, nrUser: nrUser);
    await refresh();
  }
}

final usersProvider =
    AsyncNotifierProvider.autoDispose<UsersController, CompanyUserPage>(
      UsersController.new,
    );

/// Opcoes de usuario para filtros (ate 200, so administrador).
final userOptionsProvider = FutureProvider.autoDispose<List<CompanyUser>>((
  ref,
) async {
  final nrCompany = ref.watch(currentCompanyProvider);
  final isAdmin = ref.watch(isCompanyAdminProvider);
  if (nrCompany == null || !isAdmin) return const [];
  final page = await ref
      .read(userRepositoryProvider)
      .list(nrCompany: nrCompany, filters: const UserFilters(pageSize: 200));
  return page.users;
});
