/// Textos do app em pt-BR e traducao das chaves de erro do backend.
///
/// As chaves de erro vem de `ad.fn_message` (ver dicionario do repositorio
/// supabase, aba Functions > errors). Chave sem traducao cai em UNKNOWN.
abstract final class Strings {
  static const appName = 'Clinify';
  static const tagline = 'Gestão da sua clínica, do agendamento ao prontuário.';

  // Login
  static const loginTitle = 'Bem-vindo de volta';
  static const loginSubtitle = 'Entre para acessar sua clínica.';
  static const email = 'E-mail';
  static const emailHint = 'voce@clinica.com.br';
  static const password = 'Senha';
  static const passwordHint = 'Sua senha';
  static const signIn = 'Entrar';
  static const forgotPassword = 'Esqueci minha senha';
  static const noAccount = 'Ainda não tem conta?';
  static const createAccount = 'Criar conta';
  static const comingSoon = 'Em breve.';
  static const showPassword = 'Mostrar senha';
  static const hidePassword = 'Ocultar senha';

  // Selecao de empresa / filial
  static const selectBranchTitle = 'Onde você vai trabalhar hoje?';
  static const selectBranchSubtitle =
      'Você tem acesso a mais de uma filial. Escolha a empresa e a filial para continuar.';
  static const company = 'Empresa';
  static const branch = 'Filial';
  static const searchHint = 'Pesquisar...';
  static const noResults = 'Nenhum resultado.';
  static const continueLabel = 'Continuar';
  static const cancel = 'Cancelar';
  static const switchBranch = 'Trocar filial';
  static const mainBranch = 'Matriz';
  static const admin = 'Administrador';

  // Sem empresa
  static const noCompanyTitle = 'Você ainda não tem uma empresa';
  static const noCompanySubtitle =
      'Crie a sua clínica para começar ou peça a um administrador para vincular você.';
  static const blockedTitle = 'Acesso indisponível';
  static const blockedSubtitle =
      'Seus vínculos estão sem acesso no momento. Fale com o administrador da empresa.';
  static const createCompany = 'Criar empresa';

  // Shell
  static const dashboard = 'Dashboard';
  static const users = 'Usuários';
  static const profiles = 'Perfis';
  static const logs = 'Logs';
  static const signOut = 'Sair';
  static const dashboardEmptyTitle = 'Seu painel está quase pronto';
  static const dashboardEmptySubtitle =
      'Os indicadores da clínica aparecem aqui assim que houver dados.';

  // Genericos das telas internas
  static const statusActive = 'Ativo';
  static const statusBlocked = 'Bloqueado';
  static const statusInactive = 'Inativo';
  static const allStatuses = 'Todas as situações';
  static const loadError = 'Não foi possível carregar.';
  static const retry = 'Tentar de novo';
  static const confirm = 'Confirmar';
  static const save = 'Salvar';
  static const edit = 'Editar';
  static const remove = 'Remover';
  static const search = 'Buscar';
  static const name = 'Nome';
  static const level = 'Nível';
  static const status = 'Situação';
  static const actions = 'Ações';
  static const profile = 'Perfil';
  static const user = 'Usuário';
  static const showInactive = 'Mostrar inativos';
  static const savedSuccess = 'Salvo com sucesso.';
  static const removedSuccess = 'Vínculo removido.';
  static const previousPage = 'Página anterior';
  static const nextPage = 'Próxima página';
  static const adminOnlyTitle = 'Área de administradores';
  static const adminOnlySubtitle =
      'Somente administradores da empresa podem gerenciar usuários.';
  static String totalRecords(int n) => n == 1 ? '1 registro' : '$n registros';
  static String pageOf(int page, int count) => 'Página $page de $count';

  // Perfis de acesso
  static const profilesTitle = 'Perfis de acesso';
  static const profilesSubtitle =
      'Níveis de acesso que os usuários recebem em cada filial. Nível 100 é administrador da empresa.';
  static const newProfile = 'Novo perfil';
  static const editProfile = 'Editar perfil';
  static const profileName = 'Nome do perfil';
  static const profileLevel = 'Nível de acesso';
  static const profileLevelHint =
      '0 a 100. Quem tem nível 100 administra a empresa: usuários, perfis e filiais.';
  static const profileActive = 'Perfil ativo';
  static const noProfiles = 'Nenhum perfil cadastrado.';
  static const levelAdmin = 'Administrador';
  static const levelUser = 'Usuário';
  static String profileUsers(int n) => n == 1 ? '1 usuário' : '$n usuários';

  // Usuarios da empresa
  static const usersTitle = 'Usuários';
  static const usersSubtitle =
      'Quem acessa a empresa, em quais filiais e com qual perfil.';
  static const linkUser = 'Vincular usuário';
  static const editUser = 'Editar usuário';
  static const userEmailHelp =
      'A pessoa precisa ter criado a conta no app com este e-mail.';
  static const userAccessTitle = 'Acesso por filial';
  static const userNoAccess = 'Sem acesso';
  static const userBranchesRequired =
      'Informe pelo menos uma filial com perfil.';
  static const blockReason = 'Motivo do bloqueio';
  static const lastLogin = 'Último acesso';
  static const never = 'Nunca';
  static const unlinkUser = 'Remover vínculo';
  static const noUsers = 'Nenhum usuário encontrado.';
  static const searchUsersHint = 'Nome ou e-mail';
  static const allBranches = 'Todas as filiais';
  static const userCode = 'Código';
  static String unlinkConfirm(String name) =>
      'Remover $name da empresa? A pessoa perde o acesso a todas as filiais.';

  // Logs de acesso
  static const logsTitle = 'Logs de acesso';
  static const logsSubtitle =
      'Quem entrou, quando, por qual app e em qual filial.';
  static const logsOwnOnly = 'Você vê apenas os seus próprios acessos.';
  static const customPeriod = 'Período';
  static const app = 'App';
  static const allApps = 'Todos os apps';
  static const allUsers = 'Todos os usuários';
  static const dateTime = 'Data e hora';
  static const device = 'Dispositivo';
  static const ip = 'IP';
  static const noLogs = 'Nenhum acesso no período.';
  static const noBranch = 'Sem filial';
  static String lastDays(int n) => 'Últimos $n dias';

  // Navegacao e permissoes
  static const adminMenu = 'Administração';
  static const openAdminMenu = 'Abrir ou fechar o menu de administração';
  static const noPermissionTitle = 'Sem acesso a esta tela';
  static const noPermissionSubtitle =
      'Peça a um administrador para liberar esta tela no seu perfil.';
  static const permRead = 'Ler';
  static const permCreate = 'Criar';
  static const permUpdate = 'Alterar';
  static const screen = 'Tela';
  static const screensTitle = 'Telas e permissões';
  static const adminAllScreens =
      'Nível 100 é administrador: acesso total a todas as telas, sem precisar marcar.';
  static const allScreens = 'Todas as telas';
  static const noScreens = 'Nenhuma tela liberada';
  static String screensCount(int n) => n == 1 ? '1 tela' : '$n telas';
  static const close = 'Fechar';

  // Cadastro de usuario (Edge Function user-create)
  static const newUser = 'Novo usuário';
  static const newUserHelp =
      'Se o e-mail já tiver conta no app, só o vínculo com a empresa é criado.';
  static const fullName = 'Nome completo';
  static const cpf = 'CPF';
  static const phone = 'Telefone';
  static const mobile = 'Celular';
  static const initialPassword = 'Senha inicial';
  static const confirmPassword = 'Confirmar senha';
  static const passwordsDiffer = 'As senhas não conferem.';
  static const userCreated = 'Usuário cadastrado.';

  // Log de atividades
  static const activitiesTab = 'Atividades';
  static const accessTab = 'Acessos';
  static const allScreensFilter = 'Todas as telas';
  static const action = 'Ação';
  static const allActions = 'Todas as ações';
  static const summary = 'O que aconteceu';
  static const details = 'Detalhes';
  static const searchEventsHint = 'Resumo, registro ou chave';
  static const noEvents = 'Nenhuma atividade no período.';

  // Precificacao
  static const pricing = 'Precificação';
  static const pricingTitle = 'Precificação de procedimentos';
  static const pricingSubtitle =
      'Custos da clínica, materiais, tempo e margens: o preço certo de cada procedimento.';
  static const tabSpecialties = 'Especialidades';
  static const tabProcedures = 'Procedimentos';
  static const tabMaterials = 'Materiais';
  static const tabParams = 'Parâmetros';
  static const readOnlyHint = 'Você pode consultar, mas não alterar.';

  // Procedimentos
  static const newProcedure = 'Novo procedimento';
  static const editProcedure = 'Editar procedimento';
  static const viewProcedure = 'Procedimento';
  static const procedureCode = 'Código';
  static const procedureName = 'Procedimento';
  static const specialty = 'Especialidade';
  static const noSpecialty = 'Sem especialidade';
  static const allSpecialties = 'Todas as especialidades';
  static const minutes = 'Tempo (min)';
  static const minutesHelp =
      'Tempo de cadeira. Define o custo da estrutura e a hora do profissional.';
  static const labCost = 'Laboratório / terceiros (R\$)';
  static const materialOther = 'Outros materiais (R\$)';
  static const materialOtherHelp =
      'Materiais sem cadastro, valor informado direto.';
  static const currentPrice = 'Valor cobrado hoje (R\$)';
  static const currentPriceHelp =
      'Comparado com o custo, o preço mínimo e o sugerido para gerar o alerta.';
  static const commissionOverride = 'Comissão própria (%)';
  static const profitOverride = 'Lucro próprio (%)';
  static String defaultValue(String value) =>
      'Vazio = padrão da filial ($value)';
  static String defaultSpecialtyValue(String specialty, String value) =>
      'Vazio = padrão de $specialty ($value)';
  static const materialsUsed = 'Materiais utilizados';
  static const addMaterial = 'Adicionar material';
  static const noMaterialsInProcedure = 'Nenhum material adicionado.';
  static const procedureMaterials = 'Materiais';
  static const editMaterials = 'Adicionar ou editar materiais';
  static const materialsTotal = 'Total em materiais';
  static const otherMaterials = 'Outros materiais';
  static const materialsGrandTotal = 'Custo total de materiais';
  static const addMaterials = 'Adicionar materiais';
  static String viewMaterials(int n) => 'Ver materiais ($n)';
  static String materialsSummary(int n, String total) =>
      n == 1 ? '1 material · $total' : '$n materiais · $total';

  static const jumpToSpecialty = 'Ir para especialidade';
  static const materialsSaved = 'Materiais salvos.';
  static const quantityUsed = 'Quantidade';
  static const unitCost = 'Custo unitário';
  static const lineCost = 'Custo';
  static const procedureActive = 'Procedimento ativo';
  static const procedureNameSuggestHint =
      'Digite para ver os procedimentos da planilha e os já cadastrados';
  static const suggestionFromSheet = 'Da planilha';
  static const suggestionExisting = 'Já cadastrado · copiar valores';
  static const suggestionFilledFromSheet =
      'Campos preenchidos com os dados da planilha. Confira e salve.';
  static String suggestionCopied(String name) =>
      'Valores e materiais copiados de $name. Ajuste o nome e salve.';
  static const copySuffix = '(cópia)';
  static const noProcedures = 'Nenhum procedimento cadastrado.';
  static const searchProceduresHint = 'Código, nome ou especialidade';
  static const time = 'Tempo';
  static const current = 'Atual';
  static const difference = 'Diferença';

  // Composicao do preco
  static const breakdownTitle = 'Composição do preço';
  static const simulation = 'Simulação';
  static const suggestedPrice = 'Preço sugerido';
  static const minPrice = 'Preço mínimo';
  static const minPriceHelp = 'Cobre todos os custos e taxas, com lucro zero.';
  static const directCost = 'Custo direto';
  static const materialsCost = 'Materiais';
  static const labCostShort = 'Laboratório';
  static const structureCost = 'Estrutura da clínica';
  static const professionalCost = 'Hora clínica do profissional';
  static const cardFee = 'Taxa de cartão';
  static const commission = 'Comissão';
  static const extraFees = 'Taxas adicionais';
  static const incomeTax = 'Imposto de renda';
  static const profit = 'Lucro';
  static const profitReal = 'Lucro real';
  static const diffToCurrent = 'Em relação ao valor cobrado hoje';
  static const diffToSuggested = 'Diferença para o preço sugerido';
  static const priceInvalid =
      'Os percentuais somam 100% ou mais: não existe preço possível. Ajuste nos parâmetros.';

  // Regime de IR
  static const taxRegime = 'Regime do imposto de renda';
  static const taxRegimePf = 'Pessoa física';
  static const taxRegimePj = 'Pessoa jurídica';
  static const taxRegimePfShort = 'PF';
  static const taxRegimePjShort = 'PJ';
  static const taxRegimePfHelp =
      'IR incide sobre o lucro do procedimento (carnê-leão): receita menos custos e taxas.';
  static const taxRegimePjHelp =
      'Tributos incidem sobre o faturamento (Simples Nacional ou Lucro Presumido).';
  static const taxPf = 'IR pessoa física (%)';
  static const taxPfHelp = 'Alíquota efetiva da sua faixa (teto 27,5%).';
  static const taxPj = 'Tributos pessoa jurídica (%)';
  static const taxPjHelp =
      'Alíquota efetiva do regime: Simples 6% a 15,5%; Presumido 11,33% + ISS.';
  static const simulateRegime = 'Simular regime';
  static const regimeFromParams = 'Regime da filial';

  // Alertas
  static const alertsTitle = 'Atenção';
  static const alertNoTime = 'Sem tempo';
  static const alertNoMaterial = 'Sem materiais';
  static const alertMaterialNoPrice = 'Material sem preço';
  static const alertPercentTooHigh = 'Percentuais ≥ 100%';
  static const alertPriceBelowCost = 'Cobrado abaixo do custo';
  static const alertPriceBelowMin = 'Cobrado abaixo do mínimo';
  static const alertPriceBelowSuggested = 'Cobrado abaixo do sugerido';

  // Valor cobrado x custo (it_price_status)
  static const priceCheckTitle = 'Valor cobrado hoje';
  static const priceStatusNone = 'Sem valor cobrado';
  static const priceStatusOk = 'Valor adequado';
  static const priceStatusBelowSuggested = 'Abaixo do sugerido';
  static const priceStatusBelowMin = 'Abaixo do mínimo';
  static const priceStatusBelowCost = 'Abaixo do custo';
  static const priceStatusOkHelp =
      'O valor cobrado cobre os custos, as taxas e o lucro desejado.';
  static const priceStatusBelowSuggestedHelp =
      'Cobre custos e taxas, mas o lucro fica menor que o desejado.';
  static const priceStatusBelowMinHelp =
      'Paga o custo direto, mas não cobre cartão, comissão e impostos.';
  static const priceStatusBelowCostHelp =
      'Não paga nem o custo direto: cada atendimento dá prejuízo.';
  static const currentProfit = 'Lucro com o valor cobrado';
  static const priceCheckColumn = 'Situação do preço';

  // Especialidades
  static const newSpecialty = 'Nova especialidade';
  static const editSpecialty = 'Editar especialidade';
  static const specialtyName = 'Nome da especialidade';
  static const specialtyNameHint = 'Ex.: Clínica Geral, Implante, HOF';
  static const specialtyProfit = 'Lucro desejado (%)';
  static const specialtyActive = 'Especialidade ativa';
  static const noSpecialties =
      'Nenhuma especialidade cadastrada. Crie a primeira para organizar os procedimentos.';
  static const specialtiesHint =
      'Clique numa especialidade para ver e cadastrar os procedimentos dela.';
  static const backToSpecialties = 'Especialidades';
  static const noProceduresInSpecialty =
      'Nenhum procedimento nesta especialidade.';
  static const proceduresWithoutSpecialty = 'Procedimentos sem especialidade';
  static String proceduresCount(int n) =>
      n == 1 ? '1 procedimento' : '$n procedimentos';

  // Materiais
  static const newMaterial = 'Novo material';
  static const editMaterial = 'Editar material';
  static const materialName = 'Material';
  static const package = 'Embalagem';
  static const packageHint = 'Ex.: Caixa 100, Seringa 4 g';
  static const packagePrice = 'Preço da embalagem (R\$)';
  static const yieldLabel = 'Rendimento (unidades de uso)';
  static const yieldShort = 'Rendimento';
  static const packagePriceShort = 'Preço embalagem';
  static const yieldHelp =
      'Quantas vezes a embalagem é usada: caixa com 100 luvas = 100; seringa de 4 g a 0,1 g por uso = 40.';
  static const unit = 'Unidade de uso';
  static const unitHint = 'Ex.: unidade, par, g, ml, aplicação';
  static const waste = 'Perda (%)';
  static const wasteHelp = 'Desperdício médio; reduz o rendimento.';
  static const unitCostPreview = 'Custo por unidade de uso';
  static const priceSource = 'Origem do preço';
  static const priceSourceManual = 'Manual';
  static const priceSourceMarket = 'Pesquisa de mercado';
  static const priceSourceText = 'Loja / URL de origem';
  static const priceUpdated = 'Preço atualizado em';
  static const materialActive = 'Material ativo';
  static const noMaterials = 'Nenhum material cadastrado.';
  static const searchMaterialsHint = 'Nome ou embalagem';
  static String usedIn(int n) =>
      n == 1 ? 'Usado em 1 procedimento' : 'Usado em $n procedimentos';

  // Pesquisa de preco de mercado
  static const lookupPrice = 'Buscar preço de mercado';
  static const lookupTitle = 'Preços de mercado';
  static const lookupHelp =
      'Pesquisa em lojas brasileiras de produtos odontológicos. Escolha uma oferta para preencher o preço.';
  static const lookupQuery = 'Produto a pesquisar';
  static const lookupQueryHint = 'Nome do material e embalagem';
  static const lookupSearching = 'Pesquisando na web...';
  static const lookupEmpty =
      'Nenhuma oferta encontrada. Descreva melhor o produto (marca, embalagem).';
  static const lookupSuggested = 'Mediana das ofertas';
  static const useOffer = 'Usar';

  // Parametros
  static const paramsStructureTitle = 'Estrutura da clínica';
  static const rooms = 'Salas (cadeiras)';
  static const hoursWeek = 'Horas por semana, por sala';
  static const weeksMonth = 'Semanas por mês';
  static const occupancy = 'Ocupação da agenda (%)';
  static const occupancyHelp =
      'Parte das horas abertas que realmente vira atendimento.';
  static const productiveHours = 'Horas produtivas por mês';
  static const structureHour = 'Custo da estrutura por hora';
  static const monthlyCost = 'Custo mensal da clínica';
  static const paramsProfessionalTitle = 'Profissional';
  static const professionalHour = 'Hora clínica do profissional (R\$/h)';
  static const professionalHourHelp =
      'Remuneração do dentista por hora de cadeira.';
  static const paramsPercentTitle = 'Percentuais sobre o preço';
  static const cardRate = 'Taxa da máquina de cartão (%)';
  static const cardRateHelp = 'Média ponderada de débito, crédito e parcelado.';
  static const commissionRate = 'Comissão (%)';
  static const commissionRateHelp =
      'Padrão da filial; cada procedimento pode ter a sua.';
  static const profitRate = 'Lucro desejado (%)';
  static const totalPercent = 'Total sobre o preço';
  static const paramsExpensesTitle = 'Custos da clínica';
  static const expensesHelp =
      'Despesas que formam o custo mensal. Eventuais anuais entram divididas por 12.';
  static const expenseFixed = 'Fixas mensais';
  static const expenseVariable = 'Variáveis mensais';
  static const expenseAnnual = 'Eventuais anuais';
  static const expenseMarketing = 'Publicidade mensal';
  static const expenseName = 'Despesa';
  static const expenseAmount = 'Valor (R\$)';
  static const addExpense = 'Adicionar';
  static const paramsFeesTitle = 'Taxas adicionais';
  static const feesHelp =
      'Ligue as que fazem sentido para a clínica. Entram como percentual sobre o preço.';
  static const feeName = 'Taxa';
  static const feeRate = 'Percentual';
  static const addFee = 'Adicionar taxa';
  static const paramsNotSaved =
      'Parâmetros ainda não salvos: estes são valores sugeridos. Ajuste e salve.';
  static const paramsSaved = 'Parâmetros salvos.';
  static const subtotal = 'Subtotal';
  static const perMonth = '/mês';
  static const perHour = '/h';
  static const invalidNumber = 'Número inválido.';
  static const mustBePositive = 'Informe um valor maior que zero.';

  // Edicao inline dos fatores do preco
  static const exportExcel = 'Exportar Excel';
  static const exportDone = 'Planilha gerada.';
  static const exportSheetProcedures = 'Procedimentos';
  static const exportSheetMaterials = 'Materiais por procedimento';
  static const exportSheetParams = 'Parâmetros';
  static const exportGeneratedAt = 'Gerado em';
  static const alerts = 'Alertas';
  static const factorsTitle = 'Fatores do preço';
  static const factorsHint =
      'Clique em um fator para alterar. Vale para todos os procedimentos da filial.';
  static const editFactor = 'Alterar';
  static const structureManual = 'Valor manual (R\$/h)';
  static const structureManualHelp =
      'Vazio = usar o cálculo pelas despesas. A planilha original digitava R\$ 30 sobre os R\$ 30,36 calculados.';
  static const structureCalc = 'Calculado pelas despesas';
  static const structureManualTag = 'manual';
  static const branchDefault = 'Padrão da filial';
  static const onlyThisProcedure = 'Só neste procedimento';
  static const onlyThisProcedureHelp = 'Vazio = usa o padrão da filial.';
  static const appliesToBranch = 'Vale para todos os procedimentos da filial.';
  static const noFees = 'Nenhuma taxa cadastrada.';
  static String activeFees(int n) => n == 1 ? '1 ativa' : '$n ativas';

  // Validacao de formularios
  static const required = 'Campo obrigatório.';
  static const invalidEmail = 'Informe um e-mail válido.';
  static const invalidCpf = 'CPF inválido.';
  static const invalidCnpj = 'CNPJ inválido.';
  static const invalidCpfCnpj = 'CPF/CNPJ inválido.';
  static const invalidPhone = 'Telefone inválido.';
  static const invalidDate = 'Data inválida.';
  static String minLength(int n) => 'Mínimo de $n caracteres.';

  // Pacientes
  static const patients = 'Pacientes';

  // Agenda: profissionais e horario de atendimento
  static const agenda = 'Agenda';
  static const agendaSubtitle =
      'Profissionais, cores e horário de atendimento de cada um na agenda.';
  static const professionals = 'Profissionais';
  static const professional = 'Profissional';
  static const newProfessional = 'Novo profissional';
  static const editProfessional = 'Editar profissional';
  static const professionalName = 'Nome na agenda';
  static const professionalNameHint = 'Ex.: Dra. Ana Souza';
  static const professionalCouncil = 'Registro no conselho';
  static const professionalCouncilHint = 'Ex.: CRO-PR 12345';
  static const slotMinutes = 'Intervalo dos horários';
  static const linkedUser = 'Usuário do sistema';
  static const noLinkedUser = 'Nenhum';
  static const agendaColor = 'Cor na agenda';
  static const workingHours = 'Horário de atendimento';
  static const workingHoursHelp =
      'Fora destas faixas a agenda mostra o horário como indisponível.';
  static const copyMondayToWeekdays = 'Copiar segunda para terça a sexta';
  static const addRange = 'Faixa';
  static const dayOff = 'Não atende';
  static const scheduleStart = 'Início da faixa';
  static const scheduleEnd = 'Fim da faixa';
  static const scheduleInvalid = 'O fim da faixa precisa ser depois do início.';
  static String scheduleOverlap(String day) =>
      'Faixas sobrepostas em $day. Ajuste antes de salvar.';
  static const professionalActive = 'Profissional ativo';
  static const noProfessionals =
      'Nenhum profissional cadastrado. Cadastre quem atende para montar a agenda.';
  static const noWorkingHours = 'Sem horário de atendimento';
  static String weeklyHours(double h) =>
      '${h == h.roundToDouble() ? h.round() : h.toStringAsFixed(1).replaceAll('.', ',')} h por semana';
  static const weekdaySunday = 'Domingo';
  static const weekdayMonday = 'Segunda';
  static const weekdayTuesday = 'Terça';
  static const weekdayWednesday = 'Quarta';
  static const weekdayThursday = 'Quinta';
  static const weekdayFriday = 'Sexta';
  static const weekdaySaturday = 'Sábado';

  // Agenda: grade, consultas e compromissos
  static const tabCalendar = 'Agenda';
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  static String monthName(int month) => _months[(month - 1) % 12];
  static const tabProfessionals = 'Profissionais';
  static const today = 'Hoje';
  static const previous = 'Anterior';
  static const next = 'Próximo';
  static const viewDay = 'Dia';
  static const viewWeek = 'Semana';
  static const viewMonth = 'Mês';
  static const newItem = 'Novo';
  static const newConsultation = 'Nova consulta';
  static const newCommitment = 'Novo compromisso';
  static const editConsultation = 'Editar consulta';
  static const editCommitment = 'Editar compromisso';
  static const consultation = 'Consulta';
  static const commitment = 'Compromisso';
  static const patient = 'Paciente';
  static const choosePatient = 'Escolher paciente';
  static const chooseProfessional = 'Escolha o profissional.';
  static const searchPatientHint = 'Nome, CPF ou celular';
  static const noPatientsFound = 'Nenhum paciente encontrado.';
  static const commitmentTitle = 'Título do compromisso';
  static const commitmentTitleHint = 'Ex.: Reunião, almoço, curso';
  static const consultationReason = 'Motivo (opcional)';
  static const forWholeClinic = 'Clínica toda';
  static const forProfessional = 'Profissional';
  static const date = 'Data';
  static const startTime = 'Início';
  static const duration = 'Duração';
  static const allDay = 'Dia inteiro';
  static const fitIn = 'Encaixe (pode sobrepor outro horário)';
  static const plannedProcedure = 'Procedimento previsto (opcional)';
  static const noProcedure = 'Nenhum';
  static const notes = 'Observações';
  static const appointmentStatus = 'Situação';
  static const cancelAppointment = 'Cancelar agendamento';
  static const cancelAppointmentConfirm =
      'O horário fica livre e o agendamento some da agenda. Continuar?';
  static const openPatientRecord = 'Abrir ficha do paciente';
  static String scheduledBy(String who, String when) =>
      'Agendado por $who em $when';
  static const professionalsFilter = 'Profissionais';
  static const returnAlerts = 'Alertas de retorno';
  static const noReturnAlerts = 'Nenhum retorno no período.';
  static const noAppointmentsDay = 'Nenhum agendamento neste dia.';
  static const noActiveProfessionals =
      'Cadastre os profissionais na aba Profissionais para montar a agenda.';
  static String patientsCount(int n) => n == 1 ? '1 paciente' : '$n pacientes';
  static String moreItems(int n) => '+$n';
  static const statusScheduled = 'Agendado';
  static const statusConfirmed = 'Confirmado';
  static const statusWaiting = 'Em espera';
  static const statusInService = 'Em atendimento';
  static const statusDone = 'Atendido';
  static const statusLate = 'Atrasado';
  static const statusNoShow = 'Faltou';
  static const statusCancelled = 'Cancelado';
  static const patientsSubtitle =
      'Busque, cadastre e acompanhe os pacientes da sua clínica.';
  static const newPatient = 'Novo paciente';
  static const editPatient = 'Editar paciente';
  static const registerPatient = 'Cadastrar paciente';
  static const searchPatientsHint =
      'Nome, apelido, CPF, celular, e-mail ou prontuário';
  static const searchPatientsHelp = 'Sobrenome: digite % antes (ex.: %silva).';
  static const noPatients = 'Nenhum paciente cadastrado.';
  static const noPatientsSubtitle =
      'Cadastre o primeiro paciente para começar.';
  static const noPatientsFoundSubtitle =
      'Confira a grafia ou use % antes do sobrenome.';
  static const backToPatients = 'Voltar para Pacientes';
  static const patientNotFound = 'Paciente não encontrado.';
  static const patientInfo = 'Informações do paciente';
  static const sectionRegistration = 'Cadastro';
  static const sectionContact = 'Contato';
  static const sectionComplement = 'Complemento';
  static const tabRegistration = 'Dados cadastrais';
  static const tabContact = 'Contato';
  static const tabComplement = 'Dados complementares';
  static const tabOverview = 'Visão geral';
  static const tabBudgets = 'Orçamentos';
  static const tabFinance = 'Financeiro';
  static const tabPhotos = 'Fotos';
  static const tabOdontogram = 'Odontograma';
  static const tabAnamnesis = 'Anamnese';
  static const tabDocuments = 'Documentos';
  static const tabExams = 'Exames';
  static const tabAppointments = 'Agendamentos';
  static String moduleSoon(String module) => '$module chega em breve.';
  static const moduleSoonSubtitle =
      'Este módulo será construído em cima da ficha do paciente.';
  static const nickname = 'Apelido';
  static const nicknameHint = 'Como o paciente prefere ser chamado';
  static const rg = 'RG';
  static const rgHint = 'Como está no documento';
  static const birthDate = 'Data de nascimento';
  static const dateHint = 'dd/mm/aaaa';
  static const birth = 'Nascimento';
  static String yearsOld(int age) => '$age anos';
  static const minorTag = 'Menor de idade';
  static const gender = 'Gênero';
  static const genderMale = 'Masculino';
  static const genderFemale = 'Feminino';
  static const genderOther = 'Outro';
  static const maritalStatus = 'Estado civil';
  static const maritalSingle = 'Solteiro(a)';
  static const maritalMarried = 'Casado(a)';
  static const maritalDivorced = 'Divorciado(a)';
  static const maritalWidowed = 'Viúvo(a)';
  static const maritalUnion = 'União estável';
  static const education = 'Escolaridade';
  static const educationElementary = 'Ensino fundamental';
  static const educationHigh = 'Ensino médio';
  static const educationCollege = 'Ensino superior';
  static const educationPostgraduate = 'Pós-graduação';
  static const howFound = 'Como conheceu';
  static const sourceGoogle = 'Google';
  static const sourceInstagram = 'Instagram';
  static const sourceFacebook = 'Facebook';
  static const sourceReferral = 'Indicação';
  static const sourceSchool = 'Escola';
  static const sourceBillboard = 'Outdoor';
  static const sourceFlyer = 'Panfleto';
  static const sourceSign = 'Placa';
  static const sourcePlan = 'Plano / convênio';
  static const sourceRadio = 'Rádio';
  static const sourceTv = 'TV';
  static const sourceMagazine = 'Revista';
  static const sourceOther = 'Outros';
  static const referredBy = 'Indicado por';
  static const referredByHint = 'Ex.: Dra. Ana Souza';
  static const observations = 'Observações';
  static const observationsHint = 'Observações sobre o paciente';
  static const mobileWhatsapp = 'Celular / WhatsApp';
  static const landline = 'Telefone fixo';
  static const otherPhone = 'Outro telefone';
  static const contactName = 'Contato pelo celular de';
  static const contactNameHint = 'Quando o celular é de outra pessoa';
  static const noEmail = 'Não possui e-mail';
  static const addressSection = 'Endereço';
  static const zip = 'CEP';
  static const state = 'UF';
  static const city = 'Cidade';
  static const street = 'Endereço';
  static const addressNumber = 'Número';
  static const district = 'Bairro';
  static const addressComplement = 'Complemento';
  static const recordNumber = 'Nº do prontuário';
  static const profession = 'Profissão';
  static const workplace = 'Local de trabalho';
  static const workTime = 'Tempo de trabalho';
  static const planName = 'Nome do plano';
  static const planNumber = 'Nº do plano';
  static const filiation = 'Filiação';
  static const fatherName = 'Nome do pai';
  static const fatherCpf = 'CPF do pai';
  static const fatherRg = 'RG do pai';
  static const fatherProfession = 'Profissão do pai';
  static const motherName = 'Nome da mãe';
  static const motherCpf = 'CPF da mãe';
  static const motherRg = 'RG da mãe';
  static const motherProfession = 'Profissão da mãe';
  static const legalGuardian = 'Representante legal';
  static const registeredAt = 'Cadastrado em';
  static const cpfNotInformed = 'CPF não informado';
  static const patientActive = 'Paciente ativo';
  static const inactivatePatient = 'Inativar paciente';
  static const reactivatePatient = 'Reativar paciente';
  static const inactivateConfirm =
      'O paciente sai das buscas, mas a ficha e o histórico ficam guardados. Inativar?';
  static const patientInactivated = 'Paciente inativado.';
  static const patientReactivated = 'Paciente reativado.';
  static const patientCreated = 'Paciente cadastrado.';
  static const openRecord = 'Abrir ficha';
  static const nextAppointment = 'Próximo agendamento';
  static const noNextAppointment = 'Sem próximo agendamento';
  static const noNextAppointmentHint = 'A agenda chega em breve.';
  static const noAnamnesis = 'Sem anamnese';
  static const noAnamnesisHint = 'A anamnese digital chega em breve.';
  static const returnAlert = 'Alerta de retorno';
  static const noReturnAlert = 'Sem alerta de retorno';
  static const noReturnAlertHint =
      'Defina uma data para lembrar de chamar o paciente.';
  static const newReturnAlert = 'Novo alerta';
  static const editReturnAlert = 'Alterar alerta';
  static const removeReturnAlert = 'Remover alerta';
  static const returnAlertDate = 'Data do retorno';
  static const returnAlertReason = 'Motivo';
  static const returnAlertReasonHint = 'Ex.: Retorno da limpeza';
  static const returnAlertSaved = 'Alerta de retorno salvo.';
  static const returnAlertRemoved = 'Alerta de retorno removido.';
  static const openBudgets = 'Orçamentos em aberto';
  static const noOpenBudgets = 'Sem orçamentos em aberto';
  static const noOpenBudgetsHint =
      'Os orçamentos chegam em breve, usando a precificação.';
  static const generalNotes = 'Notas gerais';
  static const noNotes = 'Sem notas gerais';
  static const noNotesHint =
      'Registre aqui observações importantes sobre o paciente.';
  static const addNote = 'Adicionar nota';
  static const noteText = 'Nota';
  static const noteHint = 'Escreva a nota...';
  static const deleteNote = 'Excluir nota';
  static const deleteNoteConfirm = 'A nota some da ficha. Excluir?';
  static const noteAdded = 'Nota adicionada.';
  static const noteDeleted = 'Nota excluída.';
  static const requiredFieldsHint = '* obrigatório';
  static const notInformed = 'Não informado';

  // Financeiro
  static const finance = 'Financeiro';
  static const financeSubtitle =
      'Contas a pagar e a receber, saldo das contas, extrato e fluxo de caixa da filial.';
  static const tabFinOverview = 'Visão geral';
  static const tabPayables = 'A pagar';
  static const tabReceivables = 'A receber';
  static const tabStatement = 'Extrato';
  static const tabCashflow = 'Fluxo de caixa';
  static const tabFinRegisters = 'Cadastros';
  static const tabDre = 'DRE';
  static const dreLine = 'Conta';
  static const dreTotal = 'Total';
  static const drePercent = '% receita';
  static const drePrevYear = 'Ano anterior';
  static const dreNextYear = 'Próximo ano';
  static const dreCompetence = 'Competência';
  static const dreCash = 'Caixa';
  static const dreCompetenceHint =
      'Por competência: contas a receber e a pagar não canceladas, pelo mês de competência.';
  static const dreCashHint =
      'Por caixa: só o que foi pago, pelo mês do pagamento e pelo valor pago.';
  static const dreEmpty = 'Sem movimento no ano';
  static const dreEmptyHint =
      'Lance contas a receber e a pagar com categoria para ver o DRE.';
  static const dreEstimatedHint =
      '* Estimado pelas alíquotas de Configurações › Financeiro › DRE.';
  static const settingsDre = 'DRE (estimativa de impostos)';
  static const settingsDreHint =
      'Alíquotas para estimar os impostos no DRE. Deixe zero se os impostos pagos já são lançados como despesa.';
  static const settingsDreRevenueTax = 'Impostos sobre a receita';
  static const settingsDreIncomeTax = 'IRPJ';
  static const settingsDreCsll = 'CSLL';
  static const settingsTaxRange = 'Informe de 0 a 50%.';
  static const finSetupTitle = 'Configure o financeiro da filial';
  static const finSetupSubtitle =
      'Criamos as contas Caixa e Banco e o plano de contas a partir das despesas da precificação. Depois é só ajustar em Cadastros.';
  static const finSetupAction = 'Configurar financeiro';
  static const finSetupDone = 'Financeiro configurado.';
  static const finSetupNoPermission =
      'Peça a um administrador para configurar o financeiro desta filial.';
  static const finBalance = 'Saldo total';
  static const finToday = 'Hoje';
  static const finTodayReceivable = 'A receber hoje';
  static const finTodayPayable = 'A pagar hoje';
  static const finOverdueReceivable = 'Recebimentos vencidos';
  static const finOverduePayable = 'Pagamentos vencidos';
  static const finMonth = 'Este mês';
  static const finReceived = 'Recebido';
  static const finPaid = 'Pago';
  static const finToReceive = 'A receber';
  static const finToPay = 'A pagar';
  static const finMonthResult = 'Resultado do mês';
  static const finAccounts = 'Contas';
  static const finNextDue = 'Próximos vencimentos';
  static const finNoNextDue = 'Nada a vencer nos próximos dias.';
  static String finOverdueCount(int n) =>
      n == 1 ? '1 lançamento' : '$n lançamentos';
  static const finStatusOpen = 'Em aberto';
  static const finStatusOverdue = 'Vencido';
  static const finStatusPaid = 'Pago';
  static const finStatusCancelled = 'Cancelado';
  static const finFilterAll = 'Todos';
  static const finFilterOpen = 'Em aberto';
  static const finFilterOverdue = 'Vencidos';
  static const finFilterPaid = 'Pagos';
  static const finFilterCancelled = 'Cancelados';
  static const finSearchHint = 'Buscar pela descrição';
  static const newPayable = 'Nova conta a pagar';
  static const newReceivable = 'Nova conta a receber';
  static const editPayable = 'Conta a pagar';
  static const editReceivable = 'Conta a receber';
  static const finNoEntries = 'Nenhum lançamento neste mês.';
  static const finOverdueRange =
      'Vencidos dos últimos 400 dias, de todos os meses.';
  static const finNoEntriesHint =
      'Troque o mês ou o filtro, ou cadastre um lançamento.';
  static const finDescription = 'Descrição';
  static const finCategory = 'Categoria';
  static const finAccount = 'Conta';
  static const finAllAccounts = 'Todas as contas';
  static const finSupplier = 'Fornecedor';
  static const finPatient = 'Paciente';
  static const finNoSupplier = 'Sem fornecedor';
  static const finNoPatient = 'Sem paciente';
  static const finChoosePatient = 'Escolher paciente';
  static const finAmount = 'Valor';
  static const finTotalAmount = 'Valor total';
  static const finAmountEach = 'Valor de cada mês';
  static const finDue = 'Vencimento';
  static const finFirstDue = 'Primeiro vencimento';
  static const finCompetence = 'Competência';
  static const finPaymentMethod = 'Forma de pagamento';
  static const finPaidOn = 'Pago em';
  static const finReceivedOn = 'Recebido em';
  static const finPaidAmount = 'Valor pago';
  static const finReceivedAmount = 'Valor recebido';
  static const finRepeat = 'Repetição';
  static const finRepeatOnce = 'Única';
  static const finRepeatInstallments = 'Parcelada';
  static const finRepeatMonthly = 'Mensal (recorrente)';
  static const finInstallments = 'Parcelas';
  static const finMonths = 'Meses';
  static String finInstallmentsPreview(int n, String each) =>
      '$n parcelas de $each, uma por mês.';
  static String finRepeatPreview(int n) =>
      'Cria $n lançamentos, um por mês, com o mesmo valor.';
  static const finAlreadyPaid = 'Já foi pago';
  static const finAlreadyReceived = 'Já foi recebido';
  static String finCreated(int n) =>
      n == 1 ? 'Lançamento criado.' : '$n lançamentos criados.';
  static const finPaidLockedHint =
      'Lançamento pago: só descrição, categoria e observações podem mudar. Para alterar valores, desfaça o pagamento.';
  static const finPay = 'Pagar';
  static const finReceive = 'Receber';
  static const finPayTitle = 'Registrar pagamento';
  static const finReceiveTitle = 'Registrar recebimento';
  static const finUndoPayment = 'Desfazer pagamento';
  static const finUndoConfirm =
      'O lançamento volta a ficar em aberto e sai do saldo da conta. Continuar?';
  static const finCancelEntry = 'Cancelar lançamento';
  static const finCancelConfirm =
      'O lançamento deixa de contar nos totais. Continuar?';
  static const finCancelFollowing = 'Cancelar também as próximas em aberto';
  static const finReopen = 'Reabrir';
  static const finSettled = 'Baixa registrada.';
  static const finUndone = 'Pagamento desfeito.';
  static const finCancelled = 'Lançamento cancelado.';
  static const finReopened = 'Lançamento reaberto.';
  static String finInstallmentOf(int n, int total) => 'Parcela $n de $total';
  static const finRecurring = 'Recorrente';
  static const finTotalOpen = 'Em aberto';
  static const finTotalOverdue = 'Vencido';
  static const finTotalPaid = 'Pago no mês';
  static const finByCostType = 'Por tipo de custo';
  static const finStart = 'Saldo inicial';
  static const finEnd = 'Saldo final';
  static const finIn = 'Entradas';
  static const finOut = 'Saídas';
  static const finNoMovements = 'Nenhum movimento pago neste mês.';
  static const finDate = 'Data';
  static const finBalanceAfter = 'Saldo';
  static const finOpeningBalance = 'Saldo anterior';
  static const finRealized = 'Realizado';
  static const finPlanned = 'Previsto';
  static const finProjected = 'Saldo projetado';
  static const finOverdueCarried =
      'Vencidos de meses anteriores entram como previstos no dia 1.';
  static const finDay = 'Dia';
  static const finAccountsSection = 'Contas';
  static const finCategoriesSection = 'Plano de contas';
  static const finSuppliersSection = 'Fornecedores';
  static const finNewAccount = 'Nova conta';
  static const finNewCategory = 'Nova categoria';
  static const finNewSupplier = 'Novo fornecedor';
  static const finAccountType = 'Tipo da conta';
  static const finOpening = 'Saldo inicial';
  static const finOpeningHelper =
      'Quanto havia na conta quando começou a usar o sistema.';
  static const finKind = 'Tipo';
  static const finRevenue = 'Receita';
  static const finExpense = 'Despesa';
  static const finRevenues = 'Receitas';
  static const finExpenses = 'Despesas';
  static const finCostType = 'Tipo de custo';
  static String finUsedBy(int n) =>
      n == 0 ? 'Sem lançamentos' : (n == 1 ? '1 lançamento' : '$n lançamentos');
  static const finDocument = 'CPF ou CNPJ';
  static const finNoRegisters = 'Nada cadastrado ainda.';
  static const finChooseCategory = 'Escolha a categoria.';
  static const finChooseAccount = 'Escolha a conta.';
  static const costFixed = 'Fixo';
  static const costVariable = 'Variável';
  static const costInvestment = 'Investimento';
  static const costOther = 'Outros';
  static const payCash = 'Dinheiro';
  static const payPix = 'Pix';
  static const payCredit = 'Cartão de crédito';
  static const payDebit = 'Cartão de débito';
  static const payTransfer = 'Transferência';
  static const payBoleto = 'Boleto';
  static const payCheck = 'Cheque';
  static const payOther = 'Outro';
  static const accountCash = 'Caixa';
  static const accountBank = 'Banco';
  static const accountSafe = 'Cofre';
  static const previousMonth = 'Mês anterior';
  static const nextMonth = 'Próximo mês';

  // Financeiro, fase 2: fechamento da consulta, selo, caixa do dia
  static const finSealPending = 'Financeiro pendente';
  static const finSealOpen = 'Recebimento em aberto';
  static const finSealPaid = 'Recebido';
  static const checkoutAction = 'Fechar atendimento';
  static const checkoutView = 'Ver financeiro';
  static const checkoutTitle = 'Fechamento do atendimento';
  static const checkoutDone = 'Atendimento fechado.';
  static const checkoutAlreadyDone =
      'Este atendimento já tem recebimento. Para refazer, cancele as parcelas em aberto em A receber.';
  static const checkoutNotConfigured =
      'Configure o financeiro da filial antes de fechar atendimentos.';
  static const checkoutAmount = 'Valor a receber';
  static const checkoutPriceHint = 'Valor cobrado hoje na precificação.';
  static const checkoutNoPrice =
      'Procedimento sem valor cobrado na precificação: informe o valor.';
  static const checkoutReceiveNow = 'Receber agora (1ª parcela)';
  static const checkoutCommission = 'Gerar comissão do profissional';
  static String checkoutCommissionPreview(String value, String due) =>
      'Comissão de $value a pagar em $due.';
  static const checkoutCommissionPc = 'Comissão';
  static const checkoutEntries = 'Lançamentos deste atendimento';
  static const cashTab = 'Caixa';
  static const cashMine = 'Meu caixa';
  static const cashClosed = 'Seu caixa está fechado.';
  static const cashOpenAction = 'Abrir caixa';
  static const cashOpenTitle = 'Abrir caixa';
  static const cashCloseAction = 'Fechar caixa';
  static const cashCloseTitle = 'Fechar caixa';
  static const cashOpened = 'Caixa aberto.';
  static String cashClosedDiff(String diff) =>
      'Caixa fechado. Diferença: $diff.';
  static const cashAccount = 'Conta caixa';
  static const cashOpenValue = 'Valor na gaveta (abertura)';
  static const cashOpenValueHelper = 'Em branco = saldo atual da conta.';
  static const cashCounted = 'Valor contado';
  static const cashExpected = 'Esperado';
  static const cashDifference = 'Diferença';
  static const cashOpening = 'Abertura';
  static const cashIn = 'Entradas';
  static const cashOut = 'Saídas';
  static const cashMoves = 'Sangrias e suprimentos';
  static const cashByMethod = 'Entradas por forma de pagamento';
  static const cashNoMethod = 'Sem forma';
  static const cashAccounts = 'Caixas da filial';
  static const cashFree = 'Livre';
  static String cashWith(String who) => 'Com $who';
  static const cashHistory = 'Últimos caixas';
  static const cashNoHistory = 'Nenhum caixa fechado ainda.';
  static const cashNoCashAccount =
      'Cadastre uma conta do tipo Caixa em Cadastros para abrir o caixa.';
  static String cashOpenedAt(String when) => 'Aberto em $when';
  static String cashClosedAt(String when) => 'Fechado em $when';
  static const cashWithdrawal = 'Sangria';
  static const cashSupply = 'Suprimento';
  static const cashTransfer = 'Transferência';
  static const cashMoveTitle = 'Movimentar entre contas';
  static const cashFrom = 'Da conta';
  static const cashTo = 'Para a conta';
  static const cashMoved = 'Movimento registrado.';
  static const cashMoveHint =
      'Sangria tira dinheiro do caixa; suprimento coloca. Não é receita nem despesa.';

  // Financeiro, fase 3a: recebiveis, taxas, Receita Saude
  static const accountReceivables = 'Recebíveis';
  static const tabReceivablesCards = 'Recebíveis';
  static const recvStatusPending = 'A receber';
  static const recvStatusReceived = 'Recebido';
  static const recvFilterAll = 'Todos';
  static const recvFilterPending = 'A receber';
  static const recvFilterOverdue = 'Atrasados';
  static const recvFilterReceived = 'Recebidos';
  static const recvFilterCancelled = 'Cancelados';
  static const recvGross = 'Bruto';
  static const recvFee = 'Taxa';
  static const recvNet = 'Líquido';
  static const recvExpected = 'Previsão';
  static const recvPendingTotal = 'A receber (líquido)';
  static const recvReceivedTotal = 'Recebido';
  static const recvNone = 'Nenhum recebível neste mês.';
  static const recvNoneHint =
      'Cadastre as taxas em Cadastros: pagamentos em cartão, boleto ou cheque passam a gerar recebíveis com a previsão.';
  static const recvConfirm = 'Confirmar recebimento';
  static const recvConfirmTitle = 'Confirmar recebimento';
  static const recvConfirmHint =
      'Informe o que caiu na conta. A diferença para o bruto vira despesa em Taxas de recebimento.';
  static const recvReceivedOn = 'Caiu em';
  static const recvReceivedValue = 'Valor que caiu';
  static const recvUndo = 'Desfazer';
  static const recvUndoConfirm =
      'O recebível volta para a receber e a transferência e a taxa são canceladas. Continuar?';
  static const recvConfirmed = 'Recebimento confirmado.';
  static const recvUndone = 'Recebível voltou para a receber.';
  static const cardInstallments = 'Parcelas no cartão';
  static const cardRateHint =
      'Com taxa cadastrada, o valor vai para Recebíveis até a operadora pagar.';
  static const ratesSection = 'Taxas de recebimento';
  static const rateNew = 'Nova taxa';
  static const rateName = 'Nome';
  static const rateMethod = 'Forma de pagamento';
  static const rateInstallmentsMin = 'De (parcelas)';
  static const rateInstallmentsMax = 'Até (parcelas)';
  static const ratePercent = 'Taxa';
  static const rateFixed = 'Tarifa fixa';
  static const rateDays = 'Dias para cair';
  static const rateAccount = 'Conta onde cai';
  static String rateSummary(String pc, String fixed, int days) =>
      '$pc${fixed.isEmpty ? '' : ' + $fixed'} · $days dias';
  static String rateRange(int min, int max) =>
      min == max ? '${min}x' : '$min a ${max}x';
  static const healthExport = 'Receita Saúde';
  static const healthTitle = 'Recebimentos para a Receita Saúde';
  static const healthHint =
      'Gera uma planilha (CSV) com os recebimentos de pacientes no período: CPF e nome de quem pagou e do paciente, data, valor e profissional. Confira antes de declarar.';
  static const healthYear = 'Ano';
  static const healthMonth = 'Mês';
  static const healthWholeYear = 'Ano inteiro';
  static const healthGenerate = 'Gerar planilha';
  static String healthDone(int n, String total) =>
      'Planilha gerada: $n recebimentos, total $total.';
  static String healthMissingCpf(int n) =>
      n == 1 ? '1 recebimento sem CPF.' : '$n recebimentos sem CPF.';
  static const healthEmpty = 'Nenhum recebimento de paciente no período.';
  static const healthColPayerCpf = 'CPF do pagador';
  static const healthColPayer = 'Pagador';
  static const healthColPatientCpf = 'CPF do paciente';
  static const healthColPatient = 'Paciente';
  static const healthColDate = 'Data do pagamento';
  static const healthColValue = 'Valor';
  static const healthColProfessional = 'Profissional';
  static const healthColDescription = 'Descrição';

  // Financeiro, fase 3b: convenios, guias e conciliacao bancaria
  static const tabPlans = 'Convênios';
  static const tabBank = 'Conciliação';
  static const guideOpen = 'Aberta';
  static const guideInvoiced = 'Faturada';
  static const guidePaid = 'Paga';
  static const guideFilterAll = 'Todas';
  static const guideFilterOpen = 'A faturar';
  static const guideFilterInvoiced = 'Faturadas';
  static const guideFilterPaid = 'Pagas';
  static const guideFilterCancelled = 'Canceladas';
  static const guideNew = 'Nova guia';
  static const guideTitle = 'Guia de convênio';
  static const guidePlan = 'Convênio';
  static const guideNumber = 'Número da guia';
  static const guideCard = 'Carteirinha';
  static const guideDate = 'Data do atendimento';
  static const guideItems = 'Procedimentos';
  static const guideAddItem = 'Adicionar procedimento';
  static const guideProcedure = 'Procedimento';
  static const guideTooth = 'Dente/região';
  static const guideQty = 'Qtd.';
  static const guideUnit = 'Valor';
  static const guideTotal = 'Total da guia';
  static const guideNoPlans =
      'Cadastre um convênio (com a tabela de preço) em Cadastros antes de lançar guias.';
  static const guideNone = 'Nenhuma guia neste mês.';
  static const guideInvoice = 'Faturar';
  static String guideInvoiceSelected(int n) =>
      n == 1 ? 'Faturar 1 guia' : 'Faturar $n guias';
  static const guideUninvoice = 'Desfazer faturamento';
  static const guidePay = 'Registrar pagamento';
  static const guidePayTitle = 'Pagamento do convênio';
  static const guidePayHint =
      'Informe a glosa de cada procedimento (o que o convênio não pagou). Quando todas as guias do faturamento estiverem pagas, a conta a receber é baixada.';
  static const guideDenied = 'Glosa';
  static const guidePaidValue = 'Valor pago';
  static const guideUnpay = 'Desfazer pagamento';
  static const guideCancel = 'Cancelar guia';
  static const guideCancelConfirm = 'A guia deixa de contar. Continuar?';
  static const guideDone = 'Guia atualizada.';
  static const guideTotalsOpen = 'A faturar';
  static const guideTotalsInvoiced = 'Faturado';
  static const guideTotalsPaid = 'Recebido';
  static const guideTotalsDenied = 'Glosado';
  static String guideDue(String d) => 'Vence em $d';
  static const plansSection = 'Convênios';
  static const planNew = 'Novo convênio';
  static const planAns = 'Registro ANS';
  static const planDocument = 'CNPJ';
  static const planDays = 'Prazo de repasse (dias)';
  static const planAccount = 'Conta do repasse';
  static const planPrices = 'Tabela de preço';
  static const planAddPrice = 'Adicionar procedimento';
  static const planCode = 'Código';
  static const planPrice = 'Valor do convênio';
  static String planPrivate(String v) => 'Particular: $v';
  static String planSummary(int n, int days) =>
      '$n procedimentos · repasse em $days dias';
  static const bankAccount = 'Conta do banco';
  static const bankChooseAccount = 'Escolha a conta para conciliar.';
  static const bankImport = 'Importar OFX';
  static String bankImported(int n, int dup, int matched) =>
      '$n linhas novas ($matched conciliadas automaticamente, $dup repetidas).';
  static const bankFileInvalid =
      'Não encontrei transações neste arquivo. Exporte o extrato em OFX no site do banco.';
  static const bankNone =
      'Nenhuma linha do banco neste mês. Importe o extrato em OFX.';
  static const bankPending = 'Pendentes';
  static const bankMatched = 'Conciliadas';
  static const bankIgnored = 'Ignoradas';
  static const bankBalance = 'Movimento do banco';
  static const bankUnmatched = 'No sistema e não no banco';
  static const bankMatch = 'Conciliar';
  static const bankCreate = 'Lançar';
  static const bankCreateTitle = 'Lançar a partir do extrato';
  static const bankIgnore = 'Ignorar';
  static const bankUndo = 'Desfazer';
  static String bankSuggestion(String d, int days) =>
      days == 0 ? d : '$d (${days}d)';
  static const bankNoSuggestion = 'Sem sugestão';
  static const bankDone = 'Extrato atualizado.';
  static const bankTransfer = 'Transferência';

  // Financeiro, fase 4: recorrentes, filtros, banco, cartao/cheque,
  // Receita Saude, atendimentos sem fechamento e anexos
  static const recurrences = 'Contas recorrentes';
  static const recurrenceNew = 'Nova conta recorrente';
  static const recurrenceEdit = 'Conta recorrente';
  static const recurrenceDay = 'Dia do vencimento';
  static const recurrenceStart = 'A partir de';
  static const recurrenceEnd = 'Até';
  static const recurrenceNoEnd = 'Sem data final';
  static const recurrenceNone = 'Nenhuma conta recorrente.';
  static const recurrenceNoneHint =
      'Aluguel, salários, internet...: cadastre uma vez e o sistema lança todo mês.';
  static String recurrenceSummary(int day, String? next) =>
      next == null ? 'Todo dia $day' : 'Todo dia $day · próximo $next';
  static String recurrenceEndsOn(String d) => 'até $d';
  static String recurrenceCounts(int open, int paid) =>
      '$open em aberto · $paid pagos';
  static const recurrenceStop = 'Encerrar';
  static const recurrenceStopConfirm =
      'Os lançamentos futuros em aberto serão cancelados; os pagos continuam. Encerrar esta conta recorrente?';
  static const recurrenceStopped = 'Conta recorrente encerrada.';
  static String recurrenceSaved(int n) => n == 0
      ? 'Conta recorrente salva.'
      : 'Conta recorrente salva ($n lançamentos gerados).';
  static const recurrenceChangedHint =
      'Ao salvar, os lançamentos em aberto de hoje em diante passam a ter os dados novos.';
  static const recurrenceShowEnded = 'Mostrar encerradas';
  static const recurrenceEnded = 'Encerrada';
  static const recurrenceFormHint =
      'Gera os lançamentos dos próximos 12 meses e continua gerando sozinha.';
  static const finByCompetence = 'Por competência';
  static const finOnlyInstallments = 'Só parceladas';
  static const bankSection = 'Dados bancários';
  static const bankCode = 'Código do banco';
  static const bankName = 'Banco';
  static const bankAgency = 'Agência';
  static const bankAccountNumber = 'Conta';
  static const bankAgencyShort = 'Ag.';
  static const bankAccountShort = 'CC';
  static const payDetails = 'Dados do pagamento (opcional)';
  static const cardBrand = 'Bandeira';
  static const cardLast4 = 'Últimos 4 dígitos';
  static const cardAuth = 'Autorização';
  static const cardAuthShort = 'Aut.';
  static const holderName = 'Titular';
  static const holderNameCheck = 'Emitente';
  static const holderDocument = 'CPF/CNPJ';
  static const checkBank = 'Banco do cheque';
  static const checkNumber = 'Número do cheque';
  static const checkShort = 'Cheque';
  static const healthList = 'Listar';
  static const healthOnlyPending = 'Só os ainda não exportados';
  static String healthExportedOn(String d) => 'Exportado em $d';
  static String healthSelected(int n, String total) =>
      '$n selecionados · $total';
  static const healthNoneSelected = 'Selecione ao menos um recebimento.';
  static String pendingCheckoutTitle(int n) => n == 1
      ? '1 atendimento sem fechamento'
      : '$n atendimentos sem fechamento';
  static const pendingCheckoutHint =
      'Consultas do mês que já aconteceram e ainda não foram cobradas.';
  static const attachments = 'Anexos';
  static const attachDocument = 'Documento';
  static const attachReceipt = 'Comprovante';
  static const attachAddDocument = 'Anexar documento';
  static const attachAddReceipt = 'Anexar comprovante';
  static const attachNone = 'Nenhum anexo.';
  static const attachTooLarge = 'O arquivo passa de 10 MB.';
  static const attachTypeInvalid =
      'Envie PDF ou imagem (JPG, PNG, WEBP, HEIC).';
  static const attachDone = 'Arquivo anexado.';
  static const attachDeleted = 'Anexo excluído.';
  static const attachDeleteConfirm = 'Excluir este anexo?';
  static const attachDownload = 'Baixar';
  static const attachDownloaded = 'Arquivo baixado.';

  // Usuarios em cards: senha, situacao
  static const resetPassword = 'Redefinir senha';
  static String resetPasswordHint(String name) =>
      'Defina uma senha nova para $name. Passe a senha a ela pessoalmente; ela pode trocá-la depois.';
  static const newPassword = 'Senha nova';
  static const passwordResetDone = 'Senha redefinida.';
  static const passwordMin = 'Use pelo menos 8 caracteres.';
  static const inactivateUser = 'Inativar';
  static const activateUser = 'Ativar';
  static String inactivateUserConfirm(String name) =>
      '$name deixa de entrar na empresa até ser ativado de novo. Inativar?';
  static const userInactivated = 'Usuário inativado.';
  static const userActivated = 'Usuário ativado.';
  static const showOnlyActive = 'Mostrar apenas usuários ativos';

  // Configuracoes
  static const settingsTitle = 'Configurações';
  static const settingsSubtitle =
      'Dados da clínica e regras da agenda e do cadastro de pacientes desta filial.';
  static const settingsClinic = 'Clínica';
  static const settingsAgenda = 'Agenda';
  static const settingsPatients = 'Pacientes';
  static const settingsClinicHint =
      'Dados que aparecem nos documentos e contratos da clínica.';
  static const settingsClinicReadOnly =
      'Só o administrador da empresa altera os dados da clínica.';
  static const settingsClinicData = 'Dados cadastrais';
  static const settingsLegalName = 'Razão social';
  static const settingsCnpj = 'CNPJ';
  static const settingsPhoneExtra = 'Telefone adicional';
  static const settingsAddress = 'Endereço';
  static const settingsZip = 'CEP';
  static const settingsStreet = 'Endereço';
  static const settingsNumber = 'Número';
  static const settingsComplement = 'Complemento';
  static const settingsDistrict = 'Bairro';
  static const settingsCity = 'Cidade';
  static const settingsState = 'UF';
  static const settingsTechnical = 'Responsável técnico';
  static const settingsTechnicalName = 'Nome';
  static const settingsTechnicalCro = 'CRO';
  static const settingsTechnicalState = 'UF do CRO';
  static const settingsForum = 'Foro';
  static const settingsForumHint =
      'Cidade onde eventuais disputas dos contratos são resolvidas.';
  static const settingsForumSame = 'Mesma cidade da clínica';
  static const settingsForumCity = 'Cidade do foro';
  static const settingsAgendaHint =
      'Como a agenda mostra os horários e o que ela deixa marcar.';
  static const settingsSlot = 'Intervalo de visualização';
  static String minutesShort(int m) => '$m min';
  static const settingsParallel = 'Consultas no mesmo horário';
  static const settingsParallelHint =
      'Quantas consultas do mesmo profissional podem ocupar o mesmo horário (encaixe não conta).';
  static const settingsOutside =
      'Permitir agendar fora do horário dos profissionais';
  static const settingsOutsideHint =
      'Desligado, a consulta precisa caber no horário de atendimento do profissional (encaixe passa).';
  static const settingsBusinessHours = 'Horário de funcionamento da clínica';
  static const settingsBusinessHoursHint =
      'Dias e horários em que a clínica abre. Dia sem faixa = fechado.';
  static const settingsPatientsHint = 'Regras do cadastro de pacientes.';
  static const settingsAutoRecord = 'Número de prontuário automático';
  static const settingsAutoRecordHint =
      'Cada paciente novo sem número recebe o próximo da sequência.';
  static const settingsNextRecord = 'Próximo número';
  static const settingsNextRecordInvalid = 'Informe um número a partir de 1.';
  static const settingsRequired = 'Obrigatórios no cadastro';
  static const settingsRequiredFixedHint =
      'Sempre obrigatórios em todo cadastro de paciente.';
  static const settingsRequiredAlways = 'Sempre obrigatório';
  static const settingsRequiredOptional = 'Outros campos obrigatórios';
  static const settingsRequiredOptionalHint =
      'Marque os campos que a recepção precisa preencher ao cadastrar um paciente.';
  static const settingsRequiredAddress = 'Endereço completo';
  static const settingsRequiredPlan = 'Convênio';
  static const requiredByClinic = 'Obrigatórios da clínica';
  static String fieldRequiredNamed(String field) => 'Informe $field.';
  static const settingsFinance = 'Financeiro';
  static const settingsFinanceHint =
      'Pacientes com contas vencidas, caixa do dia, formas de pagamento e acréscimos por atraso.';
  static const settingsDebt = 'Pacientes com contas vencidas';
  static const settingsDebtHint =
      'O que a agenda faz ao marcar consulta de paciente com conta a receber vencida.';
  static const debtRuleNone = 'Não bloquear';
  static const debtRuleNoneHint = 'Agenda normalmente.';
  static const debtRuleWarn = 'Avisar';
  static const debtRuleWarnHint = 'Agenda e mostra o valor em aberto.';
  static const debtRuleApproval = 'Aprovação do administrador';
  static const debtRuleApprovalHint =
      'Só o administrador da empresa agenda, confirmando (fica no log de atividades).';
  static const debtRuleBlock = 'Bloquear';
  static const debtRuleBlockHint =
      'Não agenda até a conta ser paga (nem como encaixe).';
  static const settingsDebtDays = 'Tolerância (dias)';
  static const settingsDebtDaysHint =
      'Dias depois do vencimento antes de valer.';
  static const settingsCash = 'Caixa';
  static const settingsCashEnabled = 'Usar caixa do dia';
  static const settingsCashEnabledHint =
      'Abrir e fechar caixa com o valor contado. Desligado, ninguém abre caixa novo.';
  static const settingsMethods = 'Formas de pagamento aceitas';
  static const settingsMethodsHint =
      'Aparecem ao receber uma conta e no fechamento da consulta.';
  static const settingsMethodsRequired =
      'Escolha ao menos uma forma de pagamento.';
  static const settingsLate = 'Multa e juros por atraso';
  static const settingsLateHint =
      'Somados automaticamente ao receber uma conta vencida (juros pro rata por dia).';
  static const settingsLateFee = 'Multa';
  static const settingsLateInterest = 'Juros de mora';
  static const settingsPerMonth = '% ao mês';
  static const settingsPercentRange = 'Informe de 0 a 10%.';
  static const debtConfirmTitle = 'Paciente com contas vencidas';
  static String debtConfirmMessage(String amount) =>
      'Este paciente tem $amount em contas pendentes. Agendar mesmo assim?';
  static const debtConfirmAction = 'Agendar mesmo assim';
  static String debtWarning(String amount) =>
      'Agendado. Atenção: o paciente tem $amount em contas pendentes.';
  static String finLateIncluded(String fee, String interest) =>
      'Inclui multa de $fee e juros de $interest.';
  static const receipt = 'Recibo';
  static const receiptNone = 'Não emitido';
  static const receiptIssue = 'Emitir recibo';
  static const receiptIssueTitle = 'Emitir recibo';
  static const receiptDownload = 'Recibo (PDF)';
  static const receiptDownloaded = 'Recibo baixado.';
  static const receiptCancel = 'Cancelar recibo';
  static String receiptCancelTitle(String number) =>
      'Cancelar o recibo $number';
  static const receiptCancelHint =
      'O número não volta a ser usado: emitir de novo gera outro recibo.';
  static const receiptCancelReason = 'Motivo';
  static const receiptCancelReasonRequired =
      'Informe o motivo do cancelamento.';
  static const receiptCancelled = 'Recibo cancelado.';
  static String receiptIssued(String number) => 'Recibo $number emitido.';
  static String receiptAlready(String number) =>
      'Esta conta já tem o recibo $number.';
  static const receiptPayer = 'Recebemos de';
  static const receiptPayerRequired = 'Informe quem pagou.';
  static const receiptPayerDocument = 'CPF ou CNPJ de quem pagou';
  static const receiptPayerDocumentHint = 'Vazio = CPF do paciente';
  static const receiptDescription = 'Referente a';
  static const settingsBudgets = 'Orçamentos';
  static const settingsBudgetRequest = 'Permitir pedir aprovação do desconto';
  static const settingsBudgetRequestHint =
      'Desligado, desconto acima do máximo é recusado (só o administrador lança).';
  static const settingsBudgetBelowMin =
      'Administrador pode aprovar abaixo do preço mínimo';
  static const settingsBudgetBelowMinHint =
      'Preço mínimo da precificação (sem lucro). Desligado, ninguém aprova item abaixo dele.';
  static const settingsBudgetReduction =
      'Contar redução de valor como desconto';
  static const settingsBudgetReductionHint =
      'Item lançado abaixo do valor cobrado hoje entra no limite de desconto.';
  static const settingsOpen = 'Pacientes com contas em aberto';
  static const settingsOpenHint =
      'O que a agenda faz com quem tem conta a receber em aberto, mesmo não vencida (vale a regra mais forte).';
  static const settingsLateEdit = 'Edição de multa e juros na baixa';
  static const settingsLateEdit0 = 'Pode reduzir';
  static const settingsLateEdit1 = 'Só o administrador reduz';
  static const settingsLateEdit2 = 'Não pode reduzir';
  static const settingsTimezone = 'Fuso horário';
  static String timezoneLabel(String z) => switch (z) {
    'America/Sao_Paulo' => 'Horário de Brasília (UTC-03:00)',
    'America/Manaus' => 'Amazonas (UTC-04:00)',
    'America/Cuiaba' => 'Mato Grosso (UTC-04:00)',
    'America/Porto_Velho' => 'Rondônia (UTC-04:00)',
    'America/Boa_Vista' => 'Roraima (UTC-04:00)',
    'America/Rio_Branco' => 'Acre (UTC-05:00)',
    'America/Noronha' => 'Fernando de Noronha (UTC-02:00)',
    _ => z,
  };
  static const trashProfessional = 'Profissional';
  static const dreGroupLabel = 'Grupo no DRE';
  static const dreGroupHint = 'Automático = pelo tipo de custo da categoria.';
  static const dreGroupAuto = 'Automático';
  static const dreGroup1 = 'Receita operacional';
  static const dreGroup2 = 'Dedução da receita';
  static const dreGroup3 = 'Custo variável';
  static const dreGroup4 = 'Custo fixo';
  static const dreGroup5 = 'Despesa operacional';
  static const dreGroup6 = 'Receita não operacional';
  static const dreGroup7 = 'Despesa não operacional';
  static const dreGroup8 = 'Investimento (fora do resultado)';
  static const settingsBudgetsHint =
      'Acima do desconto máximo, só o administrador da empresa aprova o orçamento.';
  static const settingsBudgetMax = 'Desconto máximo sem aprovação';
  static const settingsBudgetDays = 'Validade padrão (dias)';
  static const budgets = 'Orçamentos';
  static const budgetsSubtitle =
      'Planos de tratamento dos pacientes: desconto, aprovação e contas a receber.';
  static const budgetNew = 'Novo orçamento';
  static String budgetEdit(int n) => 'Orçamento $n';
  static String budgetNumber(int n) => 'Orçamento nº $n';
  static const budgetNumberLabel = 'Número';
  static const budgetOpen = 'Em aberto';
  static const budgetPending = 'Aguardando aprovação';
  static const budgetAccepted = 'Aprovado pelo paciente';
  static const budgetAcceptedShort = 'Aprovados';
  static const budgetRefused = 'Recusado';
  static const budgetCancelled = 'Cancelado';
  static const budgetExpired = 'Vencido';
  static const budgetAll = 'Todos';
  static const budgetSearch = 'Buscar paciente ou título';
  static const budgetEmpty = 'Nenhum orçamento';
  static const budgetEmptyHint =
      'Crie um orçamento a partir dos procedimentos da precificação.';
  static String budgetItemsCount(int n) => n == 1 ? '1 item' : '$n itens';
  static const budgetChoosePatient = 'Escolha o paciente';
  static const budgetPatientRequired = 'Escolha o paciente.';
  static const budgetItemsRequired = 'Inclua ao menos um procedimento.';
  static const budgetTitle = 'Título';
  static const budgetTitleHint = 'Ex.: Reabilitação superior';
  static const budgetDate = 'Data';
  static const budgetValid = 'Válido até';
  static const budgetValidHint = 'Vazio = validade padrão';
  static const budgetItems = 'Procedimentos';
  static const budgetAddProcedure = 'Adicionar procedimento';
  static const budgetAddFree = 'Item livre';
  static const budgetFreeItem = 'Item';
  static const budgetNoItems = 'Nenhum procedimento ainda.';
  static const budgetNoProcedures = 'Nenhum procedimento encontrado.';
  static const budgetItemDescription = 'Procedimento';
  static const budgetTooth = 'Dente/região';
  static const budgetQty = 'Qtd.';
  static const budgetUnit = 'Valor unitário';
  static const budgetDiscount = 'Desconto';
  static const budgetSubtotal = 'Subtotal';
  static const budgetTotal = 'Total';
  static const budgetInstallments = 'Parcelas';
  static String budgetOverMax(String max) =>
      'Desconto acima de $max: o orçamento fica aguardando a aprovação do administrador.';
  static const budgetSaved = 'Orçamento salvo.';
  static const budgetPendingInfo =
      'Orçamento salvo. O desconto passou do máximo e aguarda o administrador.';
  static String budgetPendingHint(String max) =>
      'O desconto passa de $max: só o administrador da empresa aprova.';
  static String budgetApprovedBy(String who) => 'aprovado por $who';
  static const budgetTerms = 'Pagamento';
  static const budgetEntries = 'Contas a receber';
  static const budgetEntryOpen = 'Em aberto';
  static const budgetEntryPaid = 'Pago';
  static const budgetPdf = 'PDF';
  static const budgetPdfDone = 'PDF do orçamento gerado.';
  static const budgetRefuse = 'Recusado';
  static const budgetRefuseConfirm =
      'Marcar o orçamento como recusado pelo paciente?';
  static const budgetRefusedDone = 'Orçamento recusado.';
  static const budgetCancel = 'Cancelar orçamento';
  static const budgetCancelConfirm = 'Cancelar este orçamento?';
  static const budgetCancelAcceptedConfirm =
      'As contas a receber em aberto do orçamento também serão canceladas.';
  static const budgetCancelledDone = 'Orçamento cancelado.';
  static const budgetReopen = 'Reabrir';
  static const budgetReopenedDone = 'Orçamento reaberto.';
  static const budgetApproveDiscount = 'Aprovar desconto';
  static const budgetDiscountApproved = 'Desconto aprovado.';
  static const budgetAccept = 'Paciente aprovou';
  static String budgetAcceptHint(String total) =>
      'Gera as contas a receber de $total no Financeiro (categoria Tratamentos).';
  static String budgetInstallmentOf(String v) => 'Parcelas de $v';
  static const budgetFirstDue = '1º vencimento';
  static const budgetAcceptConfirm = 'Aprovar e gerar contas';
  static const budgetAcceptedDone =
      'Orçamento aprovado: contas a receber geradas.';
  static const settingsReceipts = 'Recibos';
  static const settingsReceiptsHint =
      'Numeração dos recibos emitidos pelos recebimentos (Financeiro › conta paga › Emitir recibo).';
  static const settingsReceiptPrefix = 'Prefixo do número';
  static const settingsReceiptPrefixInvalid = 'Use letras, números, - / ou .';
  static const settingsReceiptNext = 'Próximo número';
  static const cashDisabled =
      'O caixa do dia está desligado nas configurações.';
  static const settingsSecurity = 'Segurança';
  static const settingsSecurityHint =
      'Verificação em duas etapas com um app autenticador (Google Authenticator, Microsoft Authenticator, Authy...).';
  static const mfaPolicyTitle = 'Exigir verificação em duas etapas';
  static const mfaPolicyHint =
      'Quem precisa da verificação só entra na clínica depois de digitar o código do app autenticador.';
  static const mfaPolicyNone = 'Não exigir';
  static const mfaPolicyAdmins = 'Exigir dos administradores';
  static const mfaPolicyAll = 'Exigir de todos os usuários';
  static const mfaPolicyOnlyAdmin =
      'Só o administrador da empresa altera esta regra.';
  static const mfaPolicyNeedsOwn =
      'Para exigir dos outros, ative primeiro a verificação na sua conta.';
  static const mfaMine = 'Sua conta';
  static const mfaMineOn = 'Verificação em duas etapas ativa nesta conta.';
  static const mfaMineOff =
      'Sua conta ainda não usa a verificação em duas etapas.';
  static const mfaEnable = 'Ativar app autenticador';
  static const mfaDisable = 'Remover app autenticador';
  static const mfaDisableConfirm =
      'Sem o app autenticador, o login volta a pedir só a senha (e a clínica pode exigir de novo).';
  static const mfaRemoved = 'App autenticador removido.';
  static const mfaEnabled = 'Verificação em duas etapas ativada.';
  static const mfaTitle = 'Verificação em duas etapas';
  static const mfaVerifyHint =
      'Abra o app autenticador no celular e digite o código de 6 dígitos da Clinify.';
  static const mfaEnrollHint =
      'A clínica exige a verificação em duas etapas. Leia o QR code com um app autenticador (Google Authenticator, Microsoft Authenticator, Authy) e digite o código que aparecer.';
  static const mfaEnrollHintVoluntary =
      'Leia o QR code com um app autenticador e digite o código que aparecer.';
  static const mfaSecretLabel = 'Não consegue ler? Digite esta chave no app:';
  static const mfaCode = 'Código de 6 dígitos';
  static const mfaCodeInvalidLocal = 'Digite os 6 números do app.';
  static const mfaConfirm = 'Confirmar';
  static const mfaUseOtherAccount = 'Sair e usar outra conta';
  static const settingsExport = 'Exportar';
  static const settingsExportHint =
      'Planilhas Excel com os dados da filial. Cada exportação fica no log de atividades.';
  static const exportForbidden =
      'Só quem pode alterar as configurações exporta planilhas.';
  static const exportOptions = 'Opções';
  static const exportFrom = 'De';
  static const exportTo = 'Até';
  static const exportFinanceKind = 'Contas (financeiro)';
  static const exportBoth = 'A receber e a pagar';
  static const exportReceivable = 'Só a receber';
  static const exportPayable = 'Só a pagar';
  static const exportPeriodHint =
      'O período vale para o financeiro (vencimento) e para a agenda (até 400 dias).';
  static const exportInactive = 'Incluir pacientes e procedimentos inativos';
  static const exportPatients = 'Pacientes';
  static const exportPatientsHint = 'Cadastro, contato, endereço e convênio.';
  static const exportFinance = 'Financeiro';
  static const exportFinanceHint =
      'Contas a receber e a pagar do período, com situação e pagamento.';
  static const exportProcedures = 'Procedimentos';
  static const exportProceduresHint =
      'Tempo, custo direto e preços mínimo, sugerido e cobrado.';
  static const exportAgenda = 'Agenda';
  static const exportAgendaHint =
      'Consultas e compromissos do período, com situação.';
  static const exportNoScreen = 'Sem permissão de leitura nesta tela.';
  static const exportEmpty = 'Nada para exportar com essas opções.';
  static const exportPeriodInvalid =
      'Período inválido: a data final precisa ser depois da inicial e no máximo 400 dias.';
  static String exportRows(int n) => n == 1
      ? 'Planilha gerada com 1 linha.'
      : 'Planilha gerada com $n linhas.';
  static const settingsTrash = 'Lixeira';
  static const settingsTrashHint =
      'Registros excluídos ou cancelados que podem voltar. Restaurar segue as permissões de cada tela.';
  static const trashAll = 'Todos';
  static const trashPatient = 'Paciente';
  static const trashPatientNote = 'Nota do paciente';
  static const trashAppointment = 'Agendamento';
  static const trashFinEntry = 'Conta';
  static const trashProcedure = 'Procedimento';
  static const trashMaterial = 'Material';
  static const trashRestore = 'Restaurar';
  static const trashRestored = 'Restaurado.';
  static const trashEmpty = 'Lixeira vazia';
  static const trashEmptyHint = 'Nada foi excluído por aqui.';
  static String trashDeletedAt(String when) => 'Excluído em $when';

  static const Map<String, String> _errors = {
    // Auth (Supabase Auth)
    'AUTH_INVALID_CREDENTIALS': 'E-mail ou senha inválidos.',
    'AUTH_EMAIL_NOT_CONFIRMED': 'Confirme seu e-mail antes de entrar.',
    'AUTH_USER_BANNED': 'Este usuário está suspenso.',
    'AUTH_RATE_LIMIT':
        'Muitas tentativas. Aguarde um instante e tente de novo.',
    'AUTH_ERROR': 'Não foi possível entrar. Tente novamente.',
    // Backend: sessao (ad.fn_message)
    'VERSION_MISMATCH': 'Seu app está desatualizado. Atualize para continuar.',
    'SESSION_USER_NOT_FOUND':
        'Usuário não encontrado. Fale com o administrador.',
    'SESSION_USER_INACTIVE': 'Seu usuário está inativo.',
    'SESSION_USER_BLOCKED': 'Seu usuário está bloqueado. {Reason}',
    'SESSION_COMPANY_BLOCKED': 'Empresa bloqueada pela plataforma. {Reason}',
    'SESSION_COMPANY_INACTIVE': 'Empresa inativa.',
    'SESSION_USER_COMPANY_BLOCKED':
        'Seu acesso a esta empresa está bloqueado. {Reason}',
    'SESSION_USER_COMPANY_INACTIVE': 'Seu acesso a esta empresa está inativo.',
    'SESSION_WITHOUT_PROFILE':
        'Você não tem perfil em nenhuma filial ativa desta empresa.',
    // Backend: perfis de acesso
    'ACCESS_PROFILE_ACTION_INVALID': 'Ação inválida.',
    'ACCESS_PROFILE_COMPANY_REQUIRED': 'Empresa não informada.',
    'ACCESS_PROFILE_FORBIDDEN':
        'Somente administradores da empresa podem alterar perfis.',
    'ACCESS_PROFILE_NAME_REQUIRED': 'Informe o nome do perfil.',
    'ACCESS_PROFILE_NAME_IN_USE': 'Já existe um perfil chamado {Name}.',
    'ACCESS_PROFILE_LEVEL_INVALID': 'O nível deve estar entre 0 e 100.',
    'ACCESS_PROFILE_REQUIRED': 'Perfil não informado.',
    'ACCESS_PROFILE_NOT_FOUND': 'Perfil não encontrado.',
    'ACCESS_PROFILE_STATUS_INVALID': 'Situação inválida.',
    'ACCESS_PROFILE_LAST_ADMIN':
        'A empresa ficaria sem administrador ativo. Mantenha ao menos um.',
    'ACCESS_PROFILE_LIST_COMPANY_REQUIRED': 'Empresa não informada.',
    'ACCESS_PROFILE_LIST_FORBIDDEN': 'Você não tem acesso a esta empresa.',
    // Backend: usuarios da empresa
    'COMPANY_USER_ACTION_INVALID': 'Ação inválida.',
    'COMPANY_USER_COMPANY_REQUIRED': 'Empresa não informada.',
    'COMPANY_USER_FORBIDDEN':
        'Somente administradores da empresa podem gerenciar usuários.',
    'COMPANY_USER_EMAIL_REQUIRED': 'Informe o e-mail do usuário.',
    'COMPANY_USER_EMAIL_NOT_FOUND':
        'Não existe conta com o e-mail {Email}. A pessoa precisa criar a conta no app antes.',
    'COMPANY_USER_ALREADY_LINKED': 'Este usuário já está vinculado à empresa.',
    'COMPANY_USER_USER_REQUIRED': 'Usuário não informado.',
    'COMPANY_USER_NOT_FOUND': 'Usuário não encontrado nesta empresa.',
    'COMPANY_USER_STATUS_INVALID': 'Situação inválida.',
    'COMPANY_USER_BRANCHES_REQUIRED':
        'Informe pelo menos uma filial com perfil.',
    'COMPANY_USER_BRANCH_INVALID': 'Filial inválida: {Branch}.',
    'COMPANY_USER_PROFILE_INVALID': 'Perfil inválido: {Profile}.',
    'COMPANY_USER_LAST_ADMIN':
        'A empresa ficaria sem administrador ativo. Mantenha ao menos um.',
    'COMPANY_USER_LIST_COMPANY_REQUIRED': 'Empresa não informada.',
    'COMPANY_USER_LIST_FORBIDDEN':
        'Somente administradores podem ver os usuários da empresa.',
    'COMPANY_USER_LIST_STATUS_INVALID': 'Situação inválida.',
    // Backend: filiais e logs
    'BRANCH_LIST_COMPANY_REQUIRED': 'Empresa não informada.',
    'BRANCH_LIST_FORBIDDEN': 'Você não tem acesso a esta empresa.',
    'ACCESS_LOG_LIST_COMPANY_REQUIRED': 'Empresa não informada.',
    'ACCESS_LOG_LIST_FORBIDDEN': 'Você não tem acesso a esta empresa.',
    'ACCESS_LOG_LIST_APP_INVALID': 'Tipo de app inválido.',
    'ACCESS_LOG_LIST_PERIOD_INVALID':
        'A data inicial deve ser anterior à data final.',
    // Backend: telas, permissoes e log de atividades
    'SCREEN_LIST_FORBIDDEN': 'Sessão inválida. Entre de novo.',
    'ACCESS_PROFILE_SCREENS_INVALID': 'Lista de telas inválida.',
    'ACCESS_PROFILE_SCREEN_INVALID': 'Tela inválida: {Screen}.',
    'EVENT_LOG_LIST_COMPANY_REQUIRED': 'Empresa não informada.',
    'EVENT_LOG_LIST_FORBIDDEN': 'Você não tem acesso a esta empresa.',
    'EVENT_LOG_LIST_ACTION_INVALID': 'Tipo de ação inválido.',
    'EVENT_LOG_LIST_PERIOD_INVALID':
        'A data inicial deve ser anterior à data final.',
    // Edge Function user-create
    'USER_CREATE_COMPANY_REQUIRED': 'Empresa não informada.',
    'USER_CREATE_FORBIDDEN':
        'Somente administradores da empresa podem cadastrar usuários.',
    'USER_CREATE_EMAIL_REQUIRED': 'Informe o e-mail.',
    'USER_CREATE_EMAIL_INVALID': 'E-mail inválido: {Email}.',
    'USER_CREATE_NAME_REQUIRED': 'Informe o nome.',
    'USER_CREATE_PASSWORD_WEAK':
        'A senha inicial precisa ter ao menos 8 caracteres.',
    'USER_CREATE_AUTH_FAILED': 'Não foi possível criar a conta. {Detail}',
    'USER_CREATE_BACKEND_ERROR': 'Falha no cadastro. {Detail}',
    'USER_CREATE_UNAUTHORIZED': 'Sessão inválida. Entre de novo.',
    'USER_CREATE_METHOD': 'Requisição inválida.',
    'USER_CREATE_BODY_INVALID': 'Dados inválidos.',
    // Backend: precificacao (schema od)
    'PRICING_BRANCH_REQUIRED': 'Filial não informada.',
    'PRICING_FORBIDDEN': 'Você não tem acesso à precificação desta filial.',
    'PRICING_PARAM_INVALID': 'Valor inválido no campo {Field}.',
    'PRICING_EXPENSES_INVALID': 'Lista de despesas inválida.',
    'PRICING_EXPENSE_NAME_REQUIRED': 'Informe o nome de todas as despesas.',
    'PRICING_EXPENSE_TYPE_INVALID': 'Tipo inválido na despesa {Expense}.',
    'PRICING_EXPENSE_AMOUNT_INVALID': 'Valor inválido na despesa {Expense}.',
    'PRICING_FEES_INVALID': 'Lista de taxas inválida.',
    'PRICING_FEE_NAME_REQUIRED': 'Informe o nome de todas as taxas.',
    'PRICING_FEE_RATE_INVALID': 'Percentual inválido na taxa {Fee}.',
    'PRICING_PERCENT_TOO_HIGH':
        'Os percentuais sobre o preço somam {Total}%: não existe preço possível. Reduza lucro, taxas ou impostos.',
    'PROCEDURE_LIST_REGIME_INVALID': 'Regime de imposto inválido.',
    'MATERIAL_ACTION_INVALID': 'Ação inválida.',
    'MATERIAL_FORBIDDEN': 'Você não tem permissão para alterar materiais.',
    'MATERIAL_NAME_REQUIRED': 'Informe o nome do material.',
    'MATERIAL_NAME_IN_USE': 'Já existe um material chamado {Name}.',
    'MATERIAL_PRICE_INVALID': 'Preço inválido.',
    'MATERIAL_YIELD_INVALID': 'O rendimento deve ser maior que zero.',
    'MATERIAL_WASTE_INVALID': 'A perda deve ficar entre 0% e 99%.',
    'MATERIAL_SOURCE_INVALID': 'Origem do preço inválida.',
    'MATERIAL_STATUS_INVALID': 'Situação inválida.',
    'MATERIAL_REQUIRED': 'Material não informado.',
    'MATERIAL_NOT_FOUND': 'Material não encontrado.',
    'PROCEDURE_ACTION_INVALID': 'Ação inválida.',
    'PROCEDURE_FORBIDDEN': 'Você não tem permissão para alterar procedimentos.',
    'PROCEDURE_NAME_REQUIRED': 'Informe o nome do procedimento.',
    'PROCEDURE_NAME_IN_USE': 'Já existe um procedimento chamado {Name}.',
    'PROCEDURE_CODE_IN_USE': 'O código {Code} já está em uso.',
    'PROCEDURE_MINUTES_INVALID': 'Tempo inválido.',
    'PROCEDURE_VALUE_INVALID': 'Valor inválido no campo {Field}.',
    'PROCEDURE_PERCENT_INVALID': 'Percentual inválido no campo {Field}.',
    'PROCEDURE_STATUS_INVALID': 'Situação inválida.',
    'PROCEDURE_MATERIALS_INVALID': 'Lista de materiais inválida.',
    'PROCEDURE_MATERIAL_INVALID': 'Material inválido ou inativo: {Material}.',
    'PROCEDURE_QUANTITY_INVALID':
        'Informe a quantidade do material {Material}.',
    'PROCEDURE_SPECIALTY_INVALID': 'Especialidade inválida ou inativa.',
    'PROCEDURE_REQUIRED': 'Procedimento não informado.',
    'PROCEDURE_NOT_FOUND': 'Procedimento não encontrado.',
    'AGENDA_BRANCH_REQUIRED': 'Escolha a filial.',
    'AGENDA_FORBIDDEN': 'Você não tem acesso à agenda desta filial.',
    'APPOINTMENT_LIST_PERIOD_INVALID': 'Período da agenda inválido.',
    'APPOINTMENT_ACTION_INVALID': 'Ação inválida.',
    'APPOINTMENT_FORBIDDEN': 'Você não tem permissão para alterar a agenda.',
    'APPOINTMENT_REQUIRED': 'Agendamento não informado.',
    'APPOINTMENT_NOT_FOUND': 'Agendamento não encontrado.',
    'APPOINTMENT_VALUE_INVALID': 'Dados do agendamento inválidos.',
    'APPOINTMENT_TYPE_INVALID': 'Tipo de agendamento inválido.',
    'APPOINTMENT_PATIENT_REQUIRED': 'Escolha o paciente.',
    'APPOINTMENT_PATIENT_INVALID': 'Paciente inválido ou inativo.',
    'APPOINTMENT_PROFESSIONAL_REQUIRED': 'Escolha o profissional.',
    'APPOINTMENT_PROFESSIONAL_INVALID': 'Profissional inválido ou inativo.',
    'APPOINTMENT_PROCEDURE_INVALID': 'Procedimento inválido ou inativo.',
    'APPOINTMENT_TITLE_REQUIRED': 'Informe o título do compromisso.',
    'APPOINTMENT_PERIOD_INVALID':
        'O fim precisa ser depois do início (no máximo 1 dia).',
    'APPOINTMENT_STATUS_INVALID': 'Situação inválida.',
    'APPOINTMENT_CONFLICT':
        'Já existe um agendamento neste horário ({Time}). Marque "Encaixe" para agendar mesmo assim.',
    'PROFESSIONAL_ACTION_INVALID': 'Ação inválida.',
    'PROFESSIONAL_FORBIDDEN':
        'Você não tem permissão para alterar profissionais.',
    'PROFESSIONAL_NAME_REQUIRED': 'Informe o nome do profissional.',
    'PROFESSIONAL_NAME_IN_USE': 'Já existe um profissional chamado {Name}.',
    'PROFESSIONAL_COLOR_INVALID': 'Cor inválida.',
    'PROFESSIONAL_SLOT_INVALID':
        'O intervalo deve ficar entre 5 e 240 minutos.',
    'PROFESSIONAL_USER_INVALID': 'Usuário inválido ou inativo na empresa.',
    'PROFESSIONAL_USER_IN_USE': 'Este usuário já está vinculado a {Name}.',
    'PROFESSIONAL_STATUS_INVALID': 'Situação inválida.',
    'PROFESSIONAL_SCHEDULES_INVALID': 'Horário de atendimento inválido.',
    'PROFESSIONAL_SCHEDULE_INVALID': 'Faixa de horário inválida.',
    'PROFESSIONAL_SCHEDULE_OVERLAP':
        'Faixas de horário sobrepostas no mesmo dia.',
    'PROFESSIONAL_REQUIRED': 'Profissional não informado.',
    'PROFESSIONAL_NOT_FOUND': 'Profissional não encontrado.',
    'SPECIALTY_ACTION_INVALID': 'Ação inválida.',
    'SPECIALTY_FORBIDDEN':
        'Você não tem permissão para alterar especialidades.',
    'SPECIALTY_NAME_REQUIRED': 'Informe o nome da especialidade.',
    'SPECIALTY_NAME_IN_USE': 'Já existe uma especialidade chamada {Name}.',
    'SPECIALTY_PERCENT_INVALID': 'O lucro deve ficar entre 0% e 100%.',
    'SPECIALTY_STATUS_INVALID': 'Situação inválida.',
    'SPECIALTY_REQUIRED': 'Especialidade não informada.',
    'SPECIALTY_NOT_FOUND': 'Especialidade não encontrada.',
    // Edge Function material-price-lookup
    'MATERIAL_LOOKUP_UNAUTHORIZED': 'Sessão inválida. Entre de novo.',
    'MATERIAL_LOOKUP_METHOD': 'Requisição inválida.',
    'MATERIAL_LOOKUP_BODY_INVALID': 'Dados inválidos.',
    'MATERIAL_LOOKUP_QUERY_INVALID':
        'Descreva o produto com pelo menos 3 letras.',
    'MATERIAL_LOOKUP_UNAVAILABLE':
        'A pesquisa de preços não está configurada neste ambiente. Informe o preço manualmente.',
    'MATERIAL_LOOKUP_FAILED': 'A pesquisa de preços falhou. {Detail}',
    'MATERIAL_LOOKUP_BACKEND_ERROR': 'Falha na pesquisa. {Detail}',
    // Backend: pacientes
    'PATIENT_ACTION_INVALID': 'Ação inválida.',
    'PATIENT_BRANCH_REQUIRED': 'Filial não informada.',
    'PATIENT_FORBIDDEN': 'Você não tem permissão para esta ação em pacientes.',
    'PATIENT_REQUIRED': 'Paciente não informado.',
    'PATIENT_NOT_FOUND': 'Paciente não encontrado.',
    'PATIENT_VALUE_INVALID': 'Valor inválido no campo {Field}.',
    'PATIENT_NAME_REQUIRED': 'Informe o nome do paciente.',
    'PATIENT_BIRTH_REQUIRED': 'Informe a data de nascimento.',
    'PATIENT_BIRTH_INVALID': 'Data de nascimento inválida.',
    'PATIENT_CPF_INVALID': 'CPF inválido.',
    'PATIENT_CPF_IN_USE': 'Este CPF já está no cadastro de {Name}.',
    'PATIENT_EMAIL_INVALID': 'E-mail inválido.',
    'PATIENT_PHONE_INVALID': 'Telefone inválido.',
    'PATIENT_ZIP_INVALID': 'CEP inválido.',
    'PATIENT_STATE_INVALID': 'UF inválida.',
    'PATIENT_STATUS_INVALID': 'Situação inválida.',
    'PATIENT_NOTE_ACTION_INVALID': 'Ação inválida.',
    'PATIENT_NOTE_FORBIDDEN': 'Você não tem permissão para alterar as notas.',
    'PATIENT_NOTE_REQUIRED': 'Escreva a nota.',
    'PATIENT_NOTE_NOT_FOUND': 'Nota não encontrada.',
    // Backend: financeiro
    'FINANCE_BRANCH_REQUIRED': 'Escolha a filial.',
    'FINANCE_FORBIDDEN': 'Você não tem acesso ao financeiro desta filial.',
    'FIN_LIST_FILTER_INVALID':
        'Filtro ou período inválido (no máximo 400 dias).',
    'FIN_ACCOUNT_ACTION_INVALID': 'Ação inválida.',
    'FIN_ACCOUNT_FORBIDDEN': 'Você não tem permissão para alterar contas.',
    'FIN_ACCOUNT_NAME_REQUIRED': 'Informe o nome da conta.',
    'FIN_ACCOUNT_NAME_IN_USE': 'Já existe uma conta chamada {Name}.',
    'FIN_ACCOUNT_TYPE_INVALID': 'Tipo de conta inválido.',
    'FIN_ACCOUNT_VALUE_INVALID': 'Dados da conta inválidos.',
    'FIN_ACCOUNT_STATUS_INVALID': 'Situação inválida.',
    'FIN_ACCOUNT_REQUIRED': 'Conta não informada.',
    'FIN_ACCOUNT_NOT_FOUND': 'Conta não encontrada.',
    'FIN_CATEGORY_ACTION_INVALID': 'Ação inválida.',
    'FIN_CATEGORY_FORBIDDEN':
        'Você não tem permissão para alterar o plano de contas.',
    'FIN_CATEGORY_NAME_REQUIRED': 'Informe o nome da categoria.',
    'FIN_CATEGORY_NAME_IN_USE': 'Já existe uma categoria chamada {Name}.',
    'FIN_CATEGORY_KIND_INVALID': 'Escolha receita ou despesa.',
    'FIN_CATEGORY_COST_TYPE_INVALID': 'Tipo de custo inválido.',
    'FIN_CATEGORY_STATUS_INVALID': 'Situação inválida.',
    'FIN_CATEGORY_REQUIRED': 'Categoria não informada.',
    'FIN_CATEGORY_NOT_FOUND': 'Categoria não encontrada.',
    'FIN_SUPPLIER_ACTION_INVALID': 'Ação inválida.',
    'FIN_SUPPLIER_FORBIDDEN':
        'Você não tem permissão para alterar fornecedores.',
    'FIN_SUPPLIER_NAME_REQUIRED': 'Informe o nome do fornecedor.',
    'FIN_SUPPLIER_NAME_IN_USE': 'Já existe um fornecedor chamado {Name}.',
    'FIN_SUPPLIER_DOCUMENT_INVALID': 'CPF ou CNPJ inválido.',
    'FIN_SUPPLIER_PHONE_INVALID': 'Telefone inválido.',
    'FIN_SUPPLIER_EMAIL_INVALID': 'E-mail inválido.',
    'FIN_SUPPLIER_STATUS_INVALID': 'Situação inválida.',
    'FIN_SUPPLIER_REQUIRED': 'Fornecedor não informado.',
    'FIN_SUPPLIER_NOT_FOUND': 'Fornecedor não encontrado.',
    'FIN_ENTRY_ACTION_INVALID': 'Ação inválida.',
    'FIN_ENTRY_FORBIDDEN':
        'Você não tem permissão para esta ação no financeiro.',
    'FIN_ENTRY_VALUE_INVALID': 'Dados do lançamento inválidos.',
    'FIN_ENTRY_KIND_INVALID': 'Escolha a pagar ou a receber.',
    'FIN_ENTRY_CATEGORY_INVALID':
        'Categoria inválida, inativa ou de outro tipo (receita × despesa).',
    'FIN_ENTRY_ACCOUNT_INVALID': 'Conta inválida ou inativa.',
    'FIN_ENTRY_SUPPLIER_INVALID': 'Fornecedor inválido ou inativo.',
    'FIN_ENTRY_PATIENT_INVALID': 'Paciente inválido.',
    'FIN_ENTRY_DESCRIPTION_REQUIRED': 'Informe a descrição.',
    'FIN_ENTRY_AMOUNT_INVALID': 'Informe um valor maior que zero.',
    'FIN_ENTRY_DUE_REQUIRED': 'Informe o vencimento.',
    'FIN_ENTRY_METHOD_INVALID': 'Forma de pagamento inválida.',
    'FIN_ENTRY_INSTALLMENTS_INVALID':
        'Parcelas: de 1 a 120. Repetição mensal: de 1 a 60 meses.',
    'FIN_ENTRY_PAID_ACCOUNT_REQUIRED': 'Escolha a conta do pagamento.',
    'FIN_ENTRY_REQUIRED': 'Lançamento não informado.',
    'FIN_ENTRY_NOT_FOUND': 'Lançamento não encontrado.',
    'FIN_ENTRY_PAID_LOCKED':
        'Lançamento pago: desfaça o pagamento para alterar valores e datas.',
    'FIN_ENTRY_CANCELLED_LOCKED': 'Lançamento cancelado: reabra para alterar.',
    'FIN_SETTLE_ACTION_INVALID': 'Ação inválida.',
    'FIN_SETTLE_STATUS_INVALID':
        'Esta ação não vale para a situação atual do lançamento.',
    // Backend: financeiro fase 2
    'FIN_ENTRY_PROFESSIONAL_INVALID': 'Profissional inválido ou inativo.',
    'CHECKOUT_APPOINTMENT_REQUIRED': 'Atendimento não informado.',
    'CHECKOUT_APPOINTMENT_NOT_FOUND': 'Atendimento não encontrado.',
    'CHECKOUT_APPOINTMENT_INVALID':
        'Só consultas que não foram canceladas nem faltas podem ser fechadas.',
    'CHECKOUT_ALREADY_DONE':
        'Este atendimento já tem recebimento. Cancele as parcelas em aberto para refazer.',
    'CHECKOUT_NOT_CONFIGURED':
        'Configure o financeiro da filial antes de fechar atendimentos.',
    'CHECKOUT_COMMISSION_INVALID': 'A comissão deve ficar entre 0% e 100%.',
    'FIN_CASH_FORBIDDEN': 'Você não tem permissão para operar o caixa.',
    'FIN_CASH_VALUE_INVALID': 'Valor inválido.',
    'FIN_CASH_ACCOUNT_INVALID': 'Escolha uma conta ativa do tipo Caixa.',
    'FIN_CASH_ACCOUNT_IN_USE':
        'O caixa {Account} já está aberto com outra pessoa.',
    'FIN_CASH_USER_HAS_OPEN': 'Você já tem um caixa aberto. Feche-o antes.',
    'FIN_CASH_SESSION_NOT_FOUND': 'Caixa não encontrado.',
    'FIN_CASH_SESSION_CLOSED':
        'O caixa deste movimento já foi fechado: não dá para desfazer.',
    'FIN_TRANSFER_ACTION_INVALID': 'Ação inválida.',
    'FIN_TRANSFER_FORBIDDEN': 'Você não tem permissão para movimentar contas.',
    'FIN_TRANSFER_VALUE_INVALID': 'Dados do movimento inválidos.',
    'FIN_TRANSFER_TYPE_INVALID': 'Tipo de movimento inválido.',
    'FIN_TRANSFER_ACCOUNT_INVALID':
        'Contas inválidas (sangria sai de um caixa; suprimento entra num caixa).',
    'FIN_TRANSFER_SAME_ACCOUNT': 'Escolha contas diferentes.',
    'FIN_TRANSFER_AMOUNT_INVALID': 'Informe um valor maior que zero.',
    'FIN_TRANSFER_REQUIRED': 'Movimento não informado.',
    'FIN_TRANSFER_NOT_FOUND': 'Movimento não encontrado.',
    'FIN_TRANSFER_STATUS_INVALID': 'Este movimento já foi cancelado.',
    // Backend: financeiro fase 3a
    'FIN_RECEIVABLE_CONFIRMED':
        'Este pagamento tem recebível já confirmado. Desfaça a confirmação em Recebíveis antes.',
    'FIN_RECEIVABLE_FORBIDDEN':
        'Você não tem permissão para confirmar recebíveis.',
    'FIN_RECEIVABLE_REQUIRED': 'Recebível não informado.',
    'FIN_RECEIVABLE_NOT_FOUND': 'Recebível não encontrado.',
    'FIN_RECEIVABLE_ACTION_INVALID': 'Ação inválida.',
    'FIN_RECEIVABLE_STATUS_INVALID':
        'Esta ação não vale para a situação do recebível.',
    'FIN_RECEIVABLE_VALUE_INVALID':
        'Informe um valor maior que zero e no máximo o bruto.',
    'FIN_RECEIVABLE_ACCOUNT_INVALID':
        'Escolha uma conta ativa (não a de Recebíveis).',
    'FIN_RATE_ACTION_INVALID': 'Ação inválida.',
    'FIN_RATE_FORBIDDEN': 'Você não tem permissão para alterar taxas.',
    'FIN_RATE_REQUIRED': 'Taxa não informada.',
    'FIN_RATE_NOT_FOUND': 'Taxa não encontrada.',
    'FIN_RATE_VALUE_INVALID': 'Dados da taxa inválidos.',
    'FIN_RATE_NAME_REQUIRED': 'Informe o nome da taxa.',
    'FIN_RATE_NAME_IN_USE': 'Já existe uma taxa chamada {Name}.',
    'FIN_RATE_METHOD_INVALID':
        'Taxas valem para cartão de crédito, débito, boleto ou cheque.',
    'FIN_RATE_INSTALLMENTS_INVALID': 'Faixa de parcelas inválida (1 a 24).',
    'FIN_RATE_FEE_INVALID':
        'A taxa deve ficar entre 0% e 100% e a tarifa não pode ser negativa.',
    'FIN_RATE_DAYS_INVALID': 'O prazo deve ficar entre 0 e 365 dias.',
    'FIN_RATE_ACCOUNT_INVALID': 'Escolha a conta onde o dinheiro cai.',
    'FIN_RATE_STATUS_INVALID': 'Situação inválida.',
    // Backend: financeiro fase 3b
    'FIN_BANK_RECONCILED':
        'Já conciliado com o extrato do banco. Desfaça a conciliação antes.',
    'FIN_BANK_FORBIDDEN': 'Você não tem permissão para a conciliação bancária.',
    'FIN_BANK_ACCOUNT_INVALID': 'Escolha uma conta ativa.',
    'FIN_BANK_LINES_INVALID':
        'O arquivo não tem transações (até 2000 por vez).',
    'FIN_BANK_LINE_INVALID': 'Transação {Line} do arquivo inválida.',
    'FIN_BANK_ACTION_INVALID': 'Ação inválida.',
    'FIN_BANK_LINE_REQUIRED': 'Linha do extrato não informada.',
    'FIN_BANK_LINE_NOT_FOUND': 'Linha do extrato não encontrada.',
    'FIN_BANK_STATUS_INVALID': 'Esta ação não vale para a situação da linha.',
    'FIN_BANK_MATCH_INVALID':
        'O lançamento precisa ser da mesma conta, com o mesmo valor e ainda não conciliado.',
    'FIN_BANK_CATEGORY_INVALID':
        'Escolha uma categoria do tipo certo (receita ou despesa).',
    'HEALTH_PLAN_ACTION_INVALID': 'Ação inválida.',
    'HEALTH_PLAN_FORBIDDEN': 'Você não tem permissão para alterar convênios.',
    'HEALTH_PLAN_REQUIRED': 'Convênio não informado.',
    'HEALTH_PLAN_NOT_FOUND': 'Convênio não encontrado.',
    'HEALTH_PLAN_VALUE_INVALID': 'Dados do convênio inválidos.',
    'HEALTH_PLAN_NAME_REQUIRED': 'Informe o nome do convênio.',
    'HEALTH_PLAN_NAME_IN_USE': 'Já existe um convênio chamado {Name}.',
    'HEALTH_PLAN_ANS_INVALID': 'O registro ANS tem 6 dígitos.',
    'HEALTH_PLAN_DOCUMENT_INVALID': 'CNPJ inválido.',
    'HEALTH_PLAN_DAYS_INVALID': 'O prazo deve ficar entre 0 e 365 dias.',
    'HEALTH_PLAN_ACCOUNT_INVALID': 'Escolha a conta do repasse.',
    'HEALTH_PLAN_STATUS_INVALID': 'Situação inválida.',
    'HEALTH_PLAN_PRICES_INVALID': 'Tabela de preço inválida.',
    'HEALTH_PLAN_PRICE_INVALID':
        'Procedimento inválido, inativo ou repetido na tabela de preço.',
    'HEALTH_GUIDE_ACTION_INVALID': 'Ação inválida.',
    'HEALTH_GUIDE_FORBIDDEN': 'Você não tem permissão para alterar guias.',
    'HEALTH_GUIDE_REQUIRED': 'Guia não informada.',
    'HEALTH_GUIDE_NOT_FOUND': 'Guia não encontrada.',
    'HEALTH_GUIDE_LOCKED': 'Só guias abertas podem ser alteradas.',
    'HEALTH_GUIDE_VALUE_INVALID': 'Dados da guia inválidos.',
    'HEALTH_GUIDE_PLAN_INVALID': 'Convênio inválido ou inativo.',
    'HEALTH_GUIDE_PATIENT_INVALID': 'Paciente inválido.',
    'HEALTH_GUIDE_PROFESSIONAL_INVALID': 'Profissional inválido.',
    'HEALTH_GUIDE_APPOINTMENT_INVALID':
        'Atendimento inválido para este paciente.',
    'HEALTH_GUIDE_DATE_REQUIRED': 'Informe a data do atendimento.',
    'HEALTH_GUIDE_ITEMS_REQUIRED': 'Adicione de 1 a 50 procedimentos.',
    'HEALTH_GUIDE_ITEM_INVALID': 'Procedimento {Item} inválido.',
    'HEALTH_GUIDE_PRICE_REQUIRED':
        'O procedimento {Item} não está na tabela do convênio: informe o valor.',
    'HEALTH_GUIDE_SETTLE_ACTION_INVALID': 'Ação inválida.',
    'HEALTH_GUIDE_STATUS_INVALID':
        'Esta ação não vale para a situação da guia.',
    'HEALTH_GUIDE_PLAN_MIXED': 'Fature juntas só guias do mesmo convênio.',
    'HEALTH_GUIDE_EMPTY': 'As guias não têm valor para faturar.',
    'HEALTH_GUIDE_ACCOUNT_REQUIRED':
        'Informe a conta do repasse (no convênio ou no pagamento).',
    'HEALTH_GUIDE_ENTRY_PAID':
        'O faturamento já tem pagamento. Desfaça o pagamento antes.',
    // Backend: financeiro fase 4
    'FIN_RECURRENCE_ACTION_INVALID': 'Ação inválida.',
    'FIN_RECURRENCE_FORBIDDEN':
        'Você não tem permissão para alterar contas recorrentes.',
    'FIN_RECURRENCE_REQUIRED': 'Conta recorrente não informada.',
    'FIN_RECURRENCE_NOT_FOUND': 'Conta recorrente não encontrada.',
    'FIN_RECURRENCE_CANCELLED': 'Esta conta recorrente já foi encerrada.',
    'FIN_RECURRENCE_VALUE_INVALID': 'Dados da conta recorrente inválidos.',
    'FIN_RECURRENCE_DAY_INVALID': 'O dia do vencimento vai de 1 a 31.',
    'FIN_RECURRENCE_PERIOD_INVALID':
        'Informe o início; a data final não pode ser antes dele.',
    'FIN_ACCOUNT_BANK_INVALID': 'O código do banco tem 3 dígitos.',
    'FIN_RECEIVABLE_DETAILS_INVALID':
        'Confira os 4 últimos dígitos do cartão e o CPF/CNPJ do titular.',
    'FIN_ATTACHMENT_ACTION_INVALID': 'Ação inválida.',
    'FIN_ATTACHMENT_FORBIDDEN': 'Você não tem permissão para anexar arquivos.',
    'FIN_ATTACHMENT_VALUE_INVALID': 'Dados do anexo inválidos.',
    'FIN_ATTACHMENT_TYPE_INVALID':
        'Envie PDF ou imagem (JPG, PNG, WEBP, HEIC).',
    'FIN_ATTACHMENT_TOO_LARGE': 'O arquivo passa de 10 MB.',
    'FIN_ATTACHMENT_REQUIRED': 'Anexo não informado.',
    'FIN_ATTACHMENT_NOT_FOUND': 'Anexo não encontrado.',
    'FIN_ATTACHMENT_STORAGE_FAILED':
        'Não foi possível guardar o arquivo. Tente de novo.',
    'FIN_ATTACHMENT_BACKEND_ERROR': 'Erro ao processar o anexo.',
    'FIN_ATTACHMENT_UNAUTHORIZED': 'Sessão expirada. Entre de novo.',
    'FIN_ATTACHMENT_BODY_INVALID': 'Dados do anexo inválidos.',
    'FIN_ATTACHMENT_METHOD': 'Requisição inválida.',
    // Backend: redefinir senha
    'USER_PASSWORD_COMPANY_REQUIRED': 'Empresa não informada.',
    'USER_PASSWORD_FORBIDDEN': 'Só o administrador da empresa redefine senhas.',
    'USER_PASSWORD_SHARED':
        'Este usuário também usa outra empresa: ele mesmo precisa trocar a senha.',
    'USER_PASSWORD_AUTH_FAILED': 'Não foi possível trocar a senha.',
    'USER_PASSWORD_BACKEND_ERROR': 'Erro ao redefinir a senha.',
    'USER_PASSWORD_UNAUTHORIZED': 'Sessão expirada. Entre de novo.',
    'USER_PASSWORD_BODY_INVALID': 'Dados inválidos.',
    'USER_PASSWORD_METHOD': 'Requisição inválida.',
    // Backend: configuracoes
    'SETTINGS_BRANCH_REQUIRED': 'Filial não informada.',
    'SETTINGS_FORBIDDEN':
        'Você não tem permissão para alterar as configurações.',
    'SETTINGS_VALUE_INVALID': 'Valor inválido nas configurações.',
    'SETTINGS_SLOT_INVALID': 'Escolha 5, 15, 20 ou 30 minutos.',
    'SETTINGS_PARALLEL_INVALID': 'Informe de 1 a 20 consultas.',
    'SETTINGS_RECORD_INVALID': 'Informe um número a partir de 1.',
    'SETTINGS_HOURS_INVALID':
        'Horário de funcionamento inválido (faixas que se sobrepõem?).',
    'BRANCH_UPDATE_PHONE_INVALID': 'Telefone adicional inválido.',
    'BRANCH_UPDATE_STATE_INVALID': 'UF do CRO inválida.',
    'APPOINTMENT_OUTSIDE_HOURS':
        'Fora do horário de atendimento do profissional. Use encaixe para marcar assim mesmo.',
    'PATIENT_CPF_REQUIRED': 'Informe o CPF do paciente.',
    'PATIENT_FIELD_REQUIRED': 'Campo obrigatório nas configurações: {Field}.',
    'SETTINGS_DEBT_INVALID': 'Regra de inadimplentes ou tolerância inválida.',
    'SETTINGS_METHODS_INVALID':
        'Escolha ao menos uma forma de pagamento válida.',
    'SETTINGS_LATE_INVALID': 'Multa e juros devem ficar entre 0 e 10%.',
    'APPOINTMENT_DEBT_BLOCKED':
        'Paciente com contas vencidas: a agenda está bloqueada até o pagamento.',
    'APPOINTMENT_DEBT_APPROVAL':
        'Paciente com contas vencidas: só o administrador da empresa pode agendar.',
    'APPOINTMENT_DEBT_CONFIRM':
        'Paciente com contas vencidas: confirme para agendar.',
    'FIN_ENTRY_METHOD_NOT_ACCEPTED':
        'Esta forma de pagamento não é aceita nas configurações da filial.',
    'FIN_CASH_DISABLED': 'O caixa do dia está desligado nas configurações.',
    'FIN_DRE_PERIOD_INVALID': 'Período inválido para o DRE (até 24 meses).',
    'SETTINGS_DRE_INVALID': 'As alíquotas do DRE devem ficar entre 0 e 50%.',
    'FIN_RECEIPT_FORBIDDEN':
        'Você não tem permissão para emitir ou cancelar recibos.',
    'FIN_RECEIPT_NOT_FOUND': 'Recibo não encontrado.',
    'FIN_RECEIPT_NOT_PAID':
        'Só dá para emitir recibo de conta a receber já paga.',
    'FIN_RECEIPT_PAYER_REQUIRED': 'Informe quem pagou.',
    'FIN_RECEIPT_DOCUMENT_INVALID': 'CPF ou CNPJ de quem pagou inválido.',
    'FIN_RECEIPT_REASON_REQUIRED': 'Informe o motivo do cancelamento.',
    'SETTINGS_RECEIPT_INVALID': 'Prefixo ou próximo número do recibo inválido.',
    'SESSION_MFA_REQUIRED':
        'A clínica exige a verificação em duas etapas (app autenticador).',
    'COMPANY_UPDATE_MFA_INVALID':
        'Regra de verificação em duas etapas inválida.',
    'COMPANY_UPDATE_MFA_FIRST':
        'Ative a verificação em duas etapas na sua conta antes de exigir dos outros.',
    'MFA_CODE_INVALID':
        'Código inválido ou expirado. Confira o app e tente de novo.',
    'MFA_AAL_REQUIRED':
        'Confirme o código do app autenticador antes de fazer isso.',
    'MFA_ERROR': 'Não foi possível configurar o app autenticador.',
    'BUDGET_ACTION_INVALID': 'Ação inválida no orçamento.',
    'BUDGET_BRANCH_REQUIRED': 'Filial não informada.',
    'BUDGET_FORBIDDEN': 'Você não tem permissão para esta ação nos orçamentos.',
    'BUDGET_REQUIRED': 'Orçamento não informado.',
    'BUDGET_NOT_FOUND': 'Orçamento não encontrado.',
    'BUDGET_STATUS_INVALID': 'A situação do orçamento não permite esta ação.',
    'BUDGET_VALUE_INVALID': 'Valor inválido no orçamento.',
    'BUDGET_PATIENT_INVALID': 'Paciente inválido ou inativo.',
    'BUDGET_PROFESSIONAL_INVALID': 'Profissional inválido ou inativo.',
    'BUDGET_DATE_INVALID':
        'A validade precisa ser depois da data do orçamento.',
    'BUDGET_ITEMS_REQUIRED': 'Inclua ao menos um procedimento.',
    'BUDGET_ITEM_INVALID': 'Item {Item} do orçamento inválido.',
    'BUDGET_PROCEDURE_INVALID': 'Procedimento do item {Item} não encontrado.',
    'BUDGET_DISCOUNT_INVALID': 'Desconto inválido (entre zero e o subtotal).',
    'BUDGET_DISCOUNT_FORBIDDEN':
        'Só o administrador da empresa aprova o desconto.',
    'BUDGET_EXPIRED': 'Orçamento vencido: altere a validade antes de aprovar.',
    'BUDGET_EMPTY': 'O orçamento está sem valor.',
    'BUDGET_HAS_PAYMENTS':
        'Já há parcela paga: estorne no Financeiro antes de cancelar.',
    'BUDGET_FILTER_INVALID': 'Filtro inválido.',
    'BUDGET_DISCOUNT_OVER_MAX':
        'Desconto acima do máximo da clínica: só o administrador pode lançar.',
    'BUDGET_BELOW_MIN':
        'Item {Item} abaixo do preço mínimo da precificação: não pode ser aprovado.',
    'APPOINTMENT_OPEN_BLOCKED':
        'Paciente com contas em aberto: a agenda está bloqueada até o pagamento.',
    'APPOINTMENT_OPEN_APPROVAL':
        'Paciente com contas em aberto: só o administrador da empresa pode agendar.',
    'APPOINTMENT_OPEN_CONFIRM':
        'Paciente com contas em aberto: confirme para agendar.',
    'FIN_LATE_EDIT_FORBIDDEN':
        'Multa e juros não podem ser reduzidos (Configurações › Financeiro).',
    'FIN_LATE_EDIT_ADMIN': 'Só o administrador pode reduzir multa e juros.',
    'FIN_CATEGORY_DRE_GROUP_INVALID': 'Grupo do DRE inválido.',
    'SETTINGS_BUDGET_INVALID':
        'Desconto máximo (0 a 100%) ou validade (1 a 365 dias) inválidos.',
    'EXPORT_BRANCH_REQUIRED': 'Filial não informada.',
    'EXPORT_FORBIDDEN': 'Você não tem permissão para exportar estes dados.',
    'EXPORT_KIND_INVALID': 'Tipo de planilha inválido.',
    'EXPORT_PERIOD_INVALID':
        'Período inválido: a data final precisa ser depois da inicial e no máximo 400 dias.',
    'TRASH_BRANCH_REQUIRED': 'Filial não informada.',
    'TRASH_FORBIDDEN': 'Você não tem permissão para ver a lixeira.',
    'TRASH_KIND_INVALID': 'Tipo inválido na lixeira.',
    'TRASH_NOT_FOUND': 'Este item não está mais na lixeira.',
    // App
    'NETWORK': 'Sem conexão. Verifique sua internet e tente de novo.',
    'UNKNOWN': 'Ocorreu um erro inesperado. Tente novamente.',
  };

  /// Traduz uma chave de erro, substituindo `{Param}` pelos parametros.
  /// Parametro vazio some junto com o espaco que o precede.
  static String errorMessage(
    String key,
    Map<String, dynamic> parameters, [
    String? fallback,
  ]) {
    var text = _errors[key] ?? fallback ?? _errors['UNKNOWN']!;
    parameters.forEach((name, value) {
      final v = value?.toString().trim() ?? '';
      text = text.replaceAll('{$name}', v);
    });
    return text.replaceAll(RegExp(r'\s*\{\w+\}'), '').trim();
  }
}
