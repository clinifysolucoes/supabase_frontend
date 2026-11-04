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

/// Dia em foco na agenda (a grade mostra o dia, a semana ou o mes dele).
final agendaDayProvider = StateProvider.autoDispose<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Dia, semana ou mes.
final agendaViewProvider = StateProvider.autoDispose<AgendaView>(
  (_) => AgendaView.day,
);

/// Profissionais escondidos na grade (vazio = todos visiveis).
final agendaHiddenProfessionalsProvider = StateProvider.autoDispose<Set<int>>(
  (_) => const {},
);

/// Profissionais ativos, na ordem da agenda.
final agendaProfessionalsProvider =
    FutureProvider.autoDispose<List<Professional>>((ref) async {
      final data = await ref.watch(professionalsProvider.future);
      return [
        for (final p in data.professionals)
          if (p.isActive) p,
      ];
    });

/// Consultas e compromissos do periodo da visualizacao.
class AppointmentsController
    extends AutoDisposeAsyncNotifier<AppointmentListData> {
  @override
  Future<AppointmentListData> build() async {
    final nrCompany = ref.watch(currentCompanyProvider);
    final nrBranch = ref.watch(currentBranchNumberProvider);
    final day = ref.watch(agendaDayProvider);
    final view = ref.watch(agendaViewProvider);
    if (nrCompany == null || nrBranch == null) {
      return const AppointmentListData();
    }
    final range = agendaRange(view, day);
    return ref
        .read(agendaRepositoryProvider)
        .appointments(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          from: range.from,
          to: range.to,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<int?> create(AppointmentDraft draft) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return null;
    final nr = await ref
        .read(agendaRepositoryProvider)
        .createAppointment(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          draft: draft,
        );
    await refresh();
    return nr;
  }

  /// Alteracao parcial (inclusive so a situacao: `{'it_status': 2}`).
  Future<void> change(int nrAppointment, Map<String, dynamic> changes) async {
    final nrCompany = ref.read(currentCompanyProvider);
    final nrBranch = ref.read(currentBranchNumberProvider);
    if (nrCompany == null || nrBranch == null) return;
    await ref
        .read(agendaRepositoryProvider)
        .updateAppointment(
          nrCompany: nrCompany,
          nrBranch: nrBranch,
          nrAppointment: nrAppointment,
          changes: changes,
        );
    await refresh();
  }
}

final appointmentsProvider =
    AsyncNotifierProvider.autoDispose<
      AppointmentsController,
      AppointmentListData
    >(AppointmentsController.new);
