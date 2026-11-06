import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/logs/presentation/logs_page.dart';
import '../../features/patients/presentation/patient_record_page.dart';
import '../../features/patients/presentation/patients_page.dart';
import '../../features/agenda/presentation/agenda_page.dart';
import '../../features/finance/presentation/finance_page.dart';
import '../../features/pricing/presentation/pricing_page.dart';
import '../../features/profiles/presentation/profiles_page.dart';
import '../../features/session/application/session_controller.dart';
import '../../features/session/domain/screen_codes.dart';
import '../../features/session/presentation/branch_selection_page.dart';
import '../../features/session/presentation/no_company_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/users/presentation/users_page.dart';
import '../../shared/widgets/splash_page.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const selectBranch = '/selecionar-filial';
  static const noCompany = '/sem-empresa';
  static const dashboard = '/dashboard';
  static const users = '/usuarios';
  static const profiles = '/perfis';
  static const logs = '/logs';
  static const pricing = '/precificacao';
  static const patients = '/pacientes';
  static const agenda = '/agenda';
  static const finance = '/financeiro';
  static const settings = '/configuracoes';

  /// Ficha de um paciente.
  static String patient(int nrPatient) => '$patients/$nrPatient';

  /// Rotas que nao fazem sentido com a sessao pronta.
  static const transient = {splash, login, selectBranch, noCompany};

  /// Tela (ad.screen.vc_code) que cada rota interna exige poder LER.
  static const screenOf = {
    users: ScreenCodes.users,
    profiles: ScreenCodes.profiles,
    logs: ScreenCodes.logs,
    pricing: ScreenCodes.pricing,
    patients: ScreenCodes.patients,
    agenda: ScreenCodes.agenda,
    finance: ScreenCodes.finance,
    settings: ScreenCodes.settings,
  };

  /// Tela exigida por [location]: a rota exata ou o prefixo (`/pacientes/3`).
  static String? screenFor(String location) {
    for (final e in screenOf.entries) {
      if (location == e.key || location.startsWith('${e.key}/')) {
        return e.value;
      }
    }
    return null;
  }
}

/// Com a sessao pronta: rotas transitorias vao para [pending] (a rota pedida
/// antes da sessao carregar, ex.: F5 em /configuracoes) ou ao dashboard; rota
/// sem permissao de leitura vai ao dashboard (o menu ja a esconde; isto cobre
/// URL digitada).
String? _guardReady(SessionState session, String location, {String? pending}) {
  if (AppRoutes.transient.contains(location)) {
    final target = pending ?? AppRoutes.dashboard;
    return _guardReady(session, Uri.parse(target).path) ?? target;
  }
  final code = AppRoutes.screenFor(location);
  if (code != null && !(session.selected?.canRead(code) ?? false)) {
    return AppRoutes.dashboard;
  }
  return null;
}

/// Avisa o GoRouter sempre que o estado de sessao muda.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(
      sessionControllerProvider,
      (_, __) => notifyListeners(),
    );
  }
}

/// Toda navegacao e decidida pelo estado da sessao: o usuario nunca ve uma
/// tela interna sem filial escolhida, nem o login com sessao valida.
final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  ref.onDispose(listenable.dispose);

  // Rota interna pedida enquanto a sessao nao estava pronta (recarregar a
  // pagina ou abrir um link): volta para ela depois do splash/login.
  String? pending;

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      String? stay(String target) {
        if (location == target) return null;
        if (!AppRoutes.transient.contains(location)) {
          pending = state.uri.toString();
        }
        return target;
      }

      if (session.status == SessionStatus.ready) {
        final to = _guardReady(session, location, pending: pending);
        pending = null;
        return to;
      }
      return switch (session.status) {
        SessionStatus.loading => stay(AppRoutes.splash),
        SessionStatus.signedOut => stay(AppRoutes.login),
        SessionStatus.noCompany => stay(AppRoutes.noCompany),
        _ => stay(AppRoutes.selectBranch),
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.selectBranch,
        builder: (_, __) => const BranchSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.noCompany,
        builder: (_, __) => const NoCompanyPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const DashboardPage(),
      ),
      GoRoute(path: AppRoutes.users, builder: (_, __) => const UsersPage()),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (_, __) => const ProfilesPage(),
      ),
      GoRoute(path: AppRoutes.logs, builder: (_, __) => const LogsPage()),
      GoRoute(path: AppRoutes.pricing, builder: (_, __) => const PricingPage()),
      GoRoute(path: AppRoutes.agenda, builder: (_, __) => const AgendaPage()),
      GoRoute(path: AppRoutes.finance, builder: (_, __) => const FinancePage()),
      GoRoute(
        path: AppRoutes.patients,
        builder: (_, __) => const PatientsPage(),
      ),
      GoRoute(
        path: '${AppRoutes.patients}/:nr',
        builder: (_, state) => PatientRecordPage(
          nrPatient: int.tryParse(state.pathParameters['nr'] ?? '') ?? 0,
        ),
      ),
    ],
  );
});
