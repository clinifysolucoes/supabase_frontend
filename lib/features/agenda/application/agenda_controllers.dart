import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profiles_controller.dart';
import '../data/agenda_repository.dart';
import '../domain/agenda_models.dart';

/// Mostrar os profissionais inativos tambem?
final professionalShowInactiveProvider = StateProvider.autoDispose<bool>(
  (_) => false,
);

/// Profissionais da filial atual (com horarios) e os usuarios para vincular.
class ProfessionalsController
    extends AutoDisposeAsyncNotifier<ProfessionalListData> {
  @override
  Future<ProfessionalListData> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    final includeInactive = ref.watch(professionalShowInactiveProvider);
    if (nrCompany == null || nrBranch == null) {
      return const ProfessionalListData();
    }
    return ref
        .read(agendaRepositoryProvider)
        .professionals(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          includeInactive: includeInactive,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int?> create(ProfessionalDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    final nr = await ref
        .read(agendaRepositoryProvider)
        .createProfessional(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          draft: draft,
        );
    await refresh();
    return nr;
  }

  Future<void> updateProfessional(
    int nrProfessional,
    ProfessionalDraft draft,
  ) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(agendaRepositoryProvider)
        .updateProfessional(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrProfessional: nrProfessional,
          draft: draft,
        );
    await refresh();
  }
}

final professionalsProvider =
    AsyncNotifierProvider.autoDispose<
      ProfessionalsController,
      ProfessionalListData
    >(ProfessionalsController.new);
