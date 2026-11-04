# Clinify — app Flutter (web + Android + iOS) da clínica odontológica

## O que é este projeto

Front-end único em **Flutter** para três alvos: **Web**, **Android** e **iOS**. O backend é o projeto
Supabase do repositório **`supabase`** (`github.com/zeoliveirajunior/supabase`): PostgreSQL + Auth +
PostgREST com o schema `ad` (empresas, filiais, usuários multi-empresa, perfis por filial, log de
sessão). Este repositório **não tem banco**: toda regra de negócio e toda segurança (RLS, validação
de sessão, quem acessa qual empresa/filial) vivem lá. Aqui só há telas, estado e chamadas de RPC.

Telas hoje: **login** → **seleção de empresa/filial** (pop-up, só quando o usuário acessa mais de
uma filial) → **dashboard** (em branco até existirem dados) → **usuários** (admin: vincular por e-mail,
acesso por filial × perfil, bloquear, remover), **perfis de acesso** (lista para todos; criar/editar
só admin) e **logs de acesso** (admin vê a empresa, usuário comum só os próprios).

Pacote Dart `odonto_app`; id Android/iOS `br.com.odonto.odonto_app`; nome de exibição **Clinify** (logomarca: monograma "C" em ouro com diamante sobre selo grafite, `assets/images/clinify_logo.svg`, e nome em caixa alta; pacote e ids continuam `odonto_app`).

---

## 🔌 Regra absoluta: nunca chamar o Supabase direto

1. **Um único arquivo importa `supabase_flutter`**: `lib/core/supabase/supabase_gateway.dart`
   (mais o `main.dart`, que só inicializa). O teste `test/no_direct_supabase_access_test.dart` falha
   se qualquer outro arquivo importar o pacote ou chamar `.from(` / `.rpc(`.
2. **Nenhuma tabela é lida ou escrita pelo app.** Todo dado passa por **function no banco**
   (`gateway.rpc('<function>', {...})` → `supabase.schema('ad').rpc(..., params: {'p_json': {...}})`),
   e a function valida a sessão (`auth.uid()`) e o acesso do usuário às empresas/filiais.
   Precisa de um dado novo na tela? **Primeiro** nasce a RPC no repositório `supabase`
   (`p_json` com `nr_version`, erros via `ad.fn_message`, entrada no dicionário de dados), **depois**
   o método no repositório da feature aqui, chamando `SupabaseGateway.rpc`.
3. Exceção única: autenticação (`signInWithPassword`, `signOut`, sessão) é o **Supabase Auth**.
4. Contrato: `p_json` sempre leva `nr_version` (`AppConfig.contractVersion`, injetado pelo gateway).
   Erro do banco chega como `{"Message": "CHAVE", "Parameters": {...}}` e vira `AppError`, traduzido
   em `lib/l10n/strings.dart` (`Strings._errors`). **Chave nova no backend = tradução nova aqui.**
5. `service_role` **nunca** entra no app. A chave publicável (`sb_publishable_...`) é pública por
   natureza e vai por `--dart-define` (`AppConfig`).

---

## Fluxo de sessão (`lib/features/session`)

1. `App` chama `SessionController.restore()` na abertura: sem sessão → `/login`; com sessão →
   `ad.session_context` com a última filial lembrada (`SelectionStore`, por usuário, no dispositivo).
2. Login (`LoginController.signIn`): Supabase Auth → `SessionController.afterSignIn()` →
   `session_context`. Erro do banco (usuário inexistente, inativo, bloqueado) derruba a sessão e
   mostra a mensagem traduzida no login.
3. `session_context` devolve `companies[] → branches[] → profiles[]` e `blocked[]`:
   - nenhuma filial acessível → `/sem-empresa` (primeiro acesso: "criar empresa"; ou lista dos
     vínculos bloqueados com o motivo traduzido);
   - **uma** filial → entra direto no dashboard;
   - **mais de uma** → `/selecionar-filial` abre o **pop-up** `BranchSelectionDialog`: combo de
     empresa e combo de filial, ambos com **campo de pesquisa** (`SearchableDropdown`); "Sair" encerra
     a sessão. A escolha é lembrada e enviada em `nr_company/nr_branch` na próxima abertura, e também
     registrada no log via uma segunda chamada a `session_context` logo após a escolha.
4. Toda navegação é decidida em `lib/core/routing/app_router.dart` pelo `SessionStatus`
   (`loading | signedOut | noCompany | needsSelection | ready`). Tela interna **nunca** renderiza sem
   `selected` (filial atual). Trocar de filial: chip no cabeçalho da `AppShell` ou menu do usuário.
5. `it_app` do log: 1 web · 2 android · 3 ios (`AppConfig.itApp`). `vc_app_version` vem de
   `package_info_plus` (`appVersionProvider`).

---

## Estrutura

```
lib/
├── main.dart / app.dart          # bootstrap, MaterialApp.router, locale pt-BR
├── core/
│   ├── config/                   # AppConfig (--dart-define), app_info (versão)
│   ├── supabase/                 # SupabaseGateway: ÚNICO acesso ao Supabase
│   ├── errors/                   # AppError
│   ├── theme/                    # AppTheme, AppColors, AppSpacing, AppRadius
│   ├── responsive/               # Breakpoints, ResponsiveBuilder, context.isMobile/isDesktop
│   └── routing/                  # GoRouter + redirect por estado de sessão
├── features/<feature>/           # domain (modelos) · data (repositórios) · application (controllers) · presentation (telas)
│   ├── auth/                     # login
│   ├── session/                  # session_context, seleção de filial, sem-empresa
│   ├── dashboard/
│   ├── profiles/                 # access_profile_list / access_profile_save
│   ├── users/                    # company_user_list / company_user_save / branch_list
│   ├── logs/                     # access_log_list
│   ├── pricing/                  # precificação: specialty_list/save (aba Especialidades), pricing_param_get/save, material_list/save, procedure_list/save (alerta cobrado x custo), procedure_suggest (auto complete do nome), export Excel
│   ├── agenda/                   # agenda: professional_list/save (profissionais, cor, horário de atendimento)
│   └── patients/                 # pacientes: patient_list/get/save, patient_note_save (lista, cadastro rápido, ficha com abas)
├── shared/
│   ├── widgets/                  # AppTextField, AppPasswordField, AppButton, SearchableDropdown, AppShell, AppPageHeader, AppTable, AppStatusChip/AppTagChip, AppEmptyState, AppConfirmDialog, AppPagination, Choice, AppLogo, AppSnack, LoadingOverlay, SplashPage
│   ├── formatters/masks.dart     # MaskType: cpf, cnpj, cpfCnpj, phone, cep, date (+ unmask/format)
│   ├── formatters/dates.dart     # dd/MM/yyyy <-> ISO, idade (datas vão ao backend em ISO)
│   └── validators/validators.dart# required, email, minLength, cpf, cnpj, cpfCnpj, phone, date, compose
└── l10n/strings.dart             # textos pt-BR + tradução das chaves de erro
assets/images/*.svg               # ilustrações próprias (tema odontológico)
test/                             # unit + widget + guarda do gateway
.github/workflows/                # validate, guard de main, 3 deploys manuais
```

Estado: **Riverpod** (`Notifier`/`AsyncNotifier`, providers no fim de cada arquivo).
Tela com ficha (ex.: Pacientes): lista em `/pacientes` e ficha em `/pacientes/:nr`; a guarda de permissão do
router casa a rota pelo prefixo (`AppRoutes.screenFor`). O formulário envia um mapa `coluna -> valor` com as
mesmas chaves do backend (`vc_name`, `dt_birth`...): chave presente altera, `null` limpa, ausente mantém.
Navegação: **go_router**. Tema: **Material 3**. Fonte: Manrope via `google_fonts` (em runtime;
testes usam `AppTheme.light(useGoogleFonts: false)`).

---

## Componentes reutilizáveis — use os de `shared/`, não crie widgets soltos

| Componente | Uso |
|---|---|
| `AppTextField(label, mask: MaskType.cpf, validator: Validators.cpf(), prefixIcon: ...)` | todo campo de texto; `mask` aplica o formatador e o teclado numérico |
| `AppPasswordField` | senha com mostrar/ocultar |
| `AppButton(label, onPressed, loading, variant: primary\|secondary\|text, icon)` | todo botão; `loading` desabilita e mostra progresso |
| `SearchableDropdown<T>(label, items, value, itemLabel, itemSubtitle, onChanged)` | combo com pesquisa (diálogo no desktop, folha inferior no mobile) |
| `AppShell(section, child)` | moldura das telas internas: menu lateral (desktop) / barra inferior (mobile), filial atual e usuário |
| `AppSnack.error/success/info(context, msg)` | mensagens rápidas |
| `AppPageHeader(title, subtitle, actions)` | topo de toda tela interna |
| `AppTable(columns, rows)` (desktop) + cards em `ListView` (mobile) | listagens; toda lista tem as duas formas via `ResponsiveBuilder` |
| `AppStatusChip(status)`, `AppTagChip(label)` | situação (1/80/90) e etiquetas |
| `AppEmptyState` / `AppEmptyState.error(onRetry)` | lista vazia e falha de carregamento |
| `AppConfirmDialog.show(...)` | confirmação de ação destrutiva |
| `AppPagination` + `Choice<T>` em `SearchableDropdown` | paginação e filtros (`Choice(value: null)` = todos) |
| `AppLogo`, `SplashPage`, `LoadingOverlay` | marca e estados de carregamento |
| `Masks.unmask(value)` | **sempre** antes de enviar CPF/CNPJ/telefone/CEP ao backend |

Padrão de tela de cadastro: `features/<x>/{domain,data,application,presentation}`, estado em
`AutoDisposeAsyncNotifier` que observa `currentCompanyProvider` (recarrega ao trocar de filial),
filtros em `StateProvider`, formulário em `Dialog` que devolve `true` ao salvar, erros em `AppSnack`
via `describeError(e)`. Seções só de administrador usam `isCompanyAdminProvider` (menu as esconde).
Regras: nenhum `TextFormField`/`ElevatedButton`/`DropdownButton` direto nas telas; espaçamento só
com `AppSpacing`, cantos com `AppRadius`, cores com `AppColors`; textos em `Strings` (nunca literal
na tela, para futura i18n). Validação de formulário com `Form` + `AutovalidateMode.onUserInteraction`.

---

## Responsividade — web e mobile são layouts diferentes de verdade

- Decide pela **largura** (`Breakpoints`: < 600 mobile · < 1024 tablet · ≥ 1024 desktop · ≥ 1280
  wide), nunca pela plataforma. Janela estreita no navegador recebe o layout mobile.
- Toda tela nova usa `ResponsiveBuilder(mobile:, tablet:, desktop:)`. Desktop: conteúdo com largura
  máxima (440–520 em formulários), painéis lado a lado, `NavigationRail`. Mobile: tela cheia,
  `SingleChildScrollView` (teclado), `NavigationBar` inferior, alvos de toque ≥ 48 px.
- Login é o exemplo de referência: painel da marca + formulário (desktop), cartão sobre gradiente
  (tablet), cabeçalho compacto + formulário (mobile).

## Design

- Material 3, paleta clínica em `AppColors` (teal `#0E8C86`, acento `#2ED3C6`, tinta `#0F2A33`).
- Ícones Material `*_rounded`. Cantos 12/20/28. Botões com 52 px de altura.
- Imagens: **SVG próprios** em `assets/images` (dente, ilustração do login). Nunca baixar imagem de
  terceiros sem licença clara; nunca referenciar marcas ou projetos de terceiros no código ou docs.

---

## 🌿 Branch obrigatória — pré-flight antes de qualquer edição

**Regra absoluta**: antes de qualquer `Write`, `Edit` ou `Bash` que altere estado (incl. `git commit`,
`mv`, `rm`, deploy), a Claude DEVE fazer **dois** checks na branch atual:

1. **Nome** bate com `^[a-z0-9.-]+_(feature|bugfix|hotfix)_.+$` (`git rev-parse --abbrev-ref HEAD`).
2. **Origem** é `staging` (não `main`):

```bash
git fetch origin --quiet
BASE_STAGING=$(git merge-base HEAD origin/staging)
BASE_MAIN=$(git merge-base HEAD origin/main)
if git merge-base --is-ancestor "$BASE_MAIN" "$BASE_STAGING"; then echo "OK"; else echo "BLOQUEADO: forkada de main"; fi
```

Se qualquer um falhar: **PARA**, mostra a branch e o motivo, pergunta tipo/nome/descrição e sugere
`git fetch origin && git checkout -b <dev>_feature_<desc> origin/staging`. Só edita depois que o dev
rodar (ou autorizar rodar).

| Branch | Papel | Forkar dela? |
|---|---|---|
| `main` | Produção | ❌ |
| `staging` | Homologação | ✅ sempre |

Proibido: trabalhar em `main`/`staging`; branches criadas pela Claude sem confirmação; **worktrees**
(dev e Claude trabalham lado a lado na mesma pasta). Permitido em branch inválida: leitura,
`git status/log/diff`, planejamento.

### 🚀 Publicação — só por PR, e `main` só recebe `staging`

`staging` e `main` são protegidas no GitHub: PR obrigatório com 1 aprovação, revisão de code owner
(`.github/CODEOWNERS`), conversas resolvidas, sem force push e sem deleção. A branch default é `staging`.

| Para | Vem de | Checks no PR | No merge |
|---|---|---|---|
| `staging` | `<dev>_(feature\|bugfix\|hotfix)_<desc>` | `flutter-validate.yml` (format + analyze + testes + build web) | nada automático: deploy é manual |
| `main` | **somente `staging`** | `main-author-allowlist.yml`: autor em `MAIN_PR_ALLOWED_AUTHORS` **e** origem = `staging` (required status checks) | nada automático: deploy é manual |

Fluxo da Claude: branch a partir de `origin/staging` → commits → `git push -u origin <branch>` →
`gh pr create --base staging`. A Claude **nunca** abre PR para `main`; a promoção é decisão do dev.

---

## CI/CD — três deploys manuais, organizados por branch

Os deploys são `workflow_dispatch`. **A branch escolhida ao disparar define o destino**: `staging`
→ environment `staging` (homologação); `main` → environment `production`. Qualquer outra ref é
recusada pelo job `guard`. Cada environment tem as vars `SUPABASE_URL` e `SUPABASE_ANON_KEY`, que
entram no build por `--dart-define` (`AppConfig`). O build number é o `run_number` do workflow.

| Workflow | Produz | Publica quando existir |
|---|---|---|
| `deploy-web.yml` | `build/web` como artifact | **Firebase Hosting**: secret `FIREBASE_SERVICE_ACCOUNT` + var `FIREBASE_PROJECT_ID` (`firebase.json` já aponta para `build/web`) |
| `deploy-android.yml` | APK + AAB como artifacts | **Google Play** (`internal` em staging, `production` em main): secret `PLAY_SERVICE_ACCOUNT_JSON`. Assinatura de release: `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (obrigatória em produção; sem ela em staging sai assinado com debug) |
| `deploy-ios.yml` (macOS) | IPA ou `Runner.app` sem assinatura | **TestFlight**: secrets `APPLE_CERT_P12_B64`, `APPLE_CERT_PASSWORD`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_PRIVATE_KEY` + var `IOS_BUNDLE_ID` |

Sem os secrets de publicação o workflow ainda roda, gera o artifact e avisa o que falta. Segredos só
em GitHub Environments, nunca no repo (`android/key.properties`, `*.jks`, `env/*.json` estão no
`.gitignore`).

---

## Rodar local

```bash
flutter pub get
flutter run -d chrome                    # aponta para homologação por default (AppConfig)
dart format lib test                     # a CI reprova arquivo fora do formato
flutter analyze --fatal-infos            # a CI trata info como erro
flutter test
```

Outro projeto Supabase: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
Teste visual dos três layouts: redimensione a janela do navegador (mobile < 600 px, desktop ≥ 1024 px).

## Encoding e formato

UTF-8 sem BOM, fim de linha LF (`.gitattributes`). `dart format` padrão (80 colunas). Identificadores em
inglês; textos ao usuário em português, sempre em `Strings`.

---

## O que NÃO está aqui ainda (próximos passos conhecidos)

- Criar empresa no primeiro acesso (`company_create`) e criar conta / recuperar senha.
- Dashboard com dados.
- Secrets de publicação nos environments (Firebase, Google Play, Apple).
