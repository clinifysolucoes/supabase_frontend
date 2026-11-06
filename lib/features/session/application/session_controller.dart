import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/supabase_gateway.dart';
import '../data/selection_store.dart';
import '../data/session_repository.dart';
import '../domain/session_context.dart';

enum SessionStatus {
  /// Verificando sessao / carregando contexto.
  loading,

  /// Sem sessao no Supabase Auth: tela de login.
  signedOut,

  /// Logado, mas sem nenhuma filial acessivel (primeiro acesso ou bloqueado).
  noCompany,

  /// A conta tem app autenticador sem o codigo confirmado nesta sessao, ou a
  /// empresa exige 2FA: tela de verificacao (cadastrar ou digitar o codigo).
  mfaRequired,

  /// Mais de uma filial acessivel: pop-up de selecao.
  needsSelection,

  /// Filial escolhida: app liberado.
  ready,
}

class SessionState {
  const SessionState({
    required this.status,
    this.context,
    this.selected,
    this.error,
  });

  const SessionState.loading() : this(status: SessionStatus.loading);

  const SessionState.signedOut({AppError? error})
    : this(status: SessionStatus.signedOut, error: error);

  final SessionStatus status;
  final SessionContext? context;
  final BranchRef? selected;

  /// Ultimo erro ao restaurar/entrar (mostrado uma vez na tela de login).
  final AppError? error;

  bool get isReady => status == SessionStatus.ready && selected != null;

  SessionState copyWith({
    SessionStatus? status,
    SessionContext? context,
    BranchRef? selected,
  }) => SessionState(
    status: status ?? this.status,
    context: context ?? this.context,
    selected: selected ?? this.selected,
    error: error,
  );
}

/// Dono do estado de sessao do app. Regras:
///   * `restore()` na abertura: sem sessao -> login; com sessao -> carrega contexto.
///   * `afterSignIn()` depois do Supabase Auth: carrega contexto; erro do banco
///     (usuario inexistente/bloqueado) derruba a sessao e propaga o erro.
///   * Uma unica filial acessivel entra direto; mais de uma abre a selecao;
///     a ultima filial usada e lembrada por dispositivo.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState.loading();

  SupabaseGateway get _gateway => ref.read(supabaseGatewayProvider);
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);
  SelectionStore get _store => ref.read(selectionStoreProvider);

  Future<void> restore() async {
    if (!_gateway.hasSession) {
      state = const SessionState.signedOut();
      return;
    }
    try {
      await _load();
    } on AppError catch (e) {
      await _dropSession();
      state = SessionState.signedOut(error: e);
    }
  }

  Future<void> afterSignIn() async {
    try {
      await _load();
    } on AppError {
      await _dropSession();
      state = const SessionState.signedOut();
      rethrow;
    }
  }

  Future<void> _load() async {
    state = const SessionState.loading();
    final authUserId = _gateway.authUserId;
    final remembered = authUserId == null
        ? null
        : await _store.read(authUserId);

    final SessionContext context;
    try {
      context = await _repository.loadContext(selected: remembered);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.unexpected(e);
    }

    // 2FA: conta com app autenticador ainda sem o codigo nesta sessao, ou
    // empresa que exige 2FA e nao deixou entrar
    final mfa = await _gateway.mfaStatus();
    if (mfa.needsChallenge ||
        (!context.hasAccess && context.requiresMfa && !mfa.isVerifiedSession)) {
      state = SessionState(status: SessionStatus.mfaRequired, context: context);
      return;
    }

    if (!context.hasAccess) {
      state = SessionState(status: SessionStatus.noCompany, context: context);
      return;
    }

    var selected = remembered == null
        ? null
        : context.find(remembered.nrCompany, remembered.nrBranch);

    if (selected == null && context.branches.length == 1) {
      selected = context.branches.single;
      if (authUserId != null) await _store.save(authUserId, _ids(selected));
    }

    state = selected == null
        ? SessionState(status: SessionStatus.needsSelection, context: context)
        : SessionState(
            status: SessionStatus.ready,
            context: context,
            selected: selected,
          );
  }

  /// Escolha feita no pop-up (ou "trocar filial" dentro do app).
  Future<void> select(BranchRef branch) async {
    final authUserId = _gateway.authUserId;
    if (authUserId != null) await _store.save(authUserId, _ids(branch));

    state = state.copyWith(status: SessionStatus.ready, selected: branch);

    // Registra no log de acesso qual filial foi aberta; nao bloqueia a UI.
    unawaited(
      _repository
          .loadContext(selected: _ids(branch))
          .then((context) {
            final current = state.selected;
            if (current == null) return;
            final refreshed = context.find(current.nrCompany, current.nrBranch);
            if (refreshed != null) {
              state = state.copyWith(context: context, selected: refreshed);
            }
          })
          .catchError((_) {}),
    );
  }

  /// Depois de confirmar o 2FA: recarrega o contexto (agora com aal2).
  Future<void> afterMfa() async {
    try {
      await _load();
    } on AppError catch (e) {
      await _dropSession();
      state = SessionState.signedOut(error: e);
    }
  }

  Future<void> signOut() async {
    await _dropSession();
    state = const SessionState.signedOut();
  }

  Future<void> _dropSession() async {
    try {
      await _gateway.signOut();
    } catch (_) {
      // sessao local ja limpa ou offline: o estado vira signedOut mesmo assim
    }
  }

  SelectedBranchIds _ids(BranchRef ref) =>
      SelectedBranchIds(nrCompany: ref.nrCompany, nrBranch: ref.nrBranch);
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
