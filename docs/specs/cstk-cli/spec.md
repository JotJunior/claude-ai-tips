# Feature Specification: CSTK — Claude Specs Toolkit CLI

**Feature**: `cstk-cli`
**CLI name**: `cstk` (canonico — ver Clarifications 2026-04-22)
**Created**: 2026-04-22
**Status**: Draft

## Resumo

Hoje as skills deste toolkit sao distribuidas via `cp -r global/skills/ ~/.claude/skills/`
(documentado no `CLAUDE.md`). Esse fluxo tem dois problemas cronicos: (a) drift entre o
repositorio fonte e a copia instalada, que o proprio CLAUDE.md ja reconhece como recorrente;
(b) nenhuma forma de saber qual versao esta instalada nem de aplicar apenas as mudancas
novas. Esta feature adiciona uma CLI dedicada (`cstk`) que instala skills no escopo global
(`~/.claude/skills/`) ou de projeto (`./.claude/skills/`), detecta e aplica atualizacoes
sem sobrescrever edicoes locais cegamente, e sabe atualizar a si propria.

## Clarifications

### Session 2026-04-22

- Q: Fonte de distribuicao canonica das skills e do CLI? → A: Tarballs de releases
  versionadas publicadas no GitHub (tags SemVer). Cliente precisa apenas de `curl`/`tar`;
  versao alvo = tag. Skills e CLI podem ter releases separadas ou conjuntas; nao exige
  clone git do repositorio nem infra propria do mantenedor.
- Q: Politica de conflito no update quando skill instalada tem edicoes locais? → A:
  Abortar a skill afetada com mensagem clara. Usuario deve passar `--force` para
  sobrescrever ou `--keep` para manter a cozinha local intocada nessa skill. Outras
  skills continuam atualizando normalmente. Nenhum backup automatico, nenhuma mesclagem
  automatica.
- Q: Granularidade de selecao no install? → A: Perfis nomeados (`all`, `sdd`,
  `complementary`, `language-go`, `language-dotnet`) + cherry-pick por nome tambem
  suportado. Default = `sdd` (pipeline SDD tende a ser o uso global mais comum;
  language-* faz sentido principalmente em escopo de projeto onde a linguagem e
  conhecida). Adicionalmente, modo interativo disponivel via flag, onde a CLI lista
  perfis e skills e permite selecao manual sem exigir que o usuario decore nomes.
- Q: Catalogo da CLI inclui hooks de `language-related/*/hooks/`? → A: Sim, mas
  com restricoes: (a) hooks sao instalaveis APENAS em escopo de projeto, nunca global
  — perfis `language-*` em escopo global instalam apenas skills e ignoram hooks; (b)
  merge do `settings.json` da linguagem em `./.claude/settings.json` do projeto segue
  deteccao de ambiente: se `jq` estiver disponivel, CLI faz merge automatico; se nao,
  CLI imprime na saida o bloco JSON exato que o usuario precisa colar manualmente no
  arquivo e referencia a documentacao local. CLI nao tenta merge POSIX puro de JSON
  para evitar risco de corromper o arquivo.
- Q: Nome definitivo do binario/comando da CLI? → A: `cstk` (Claude Specs Toolkit).
  Confirmado como nome final e canonico. Qualquer rename futuro e BREAKING e exige
  bump MAJOR conforme politica documentada em CLAUDE.md.

### Session 2026-04-22 (follow-up — gap CHK023)

- Q: Como o usuario dispara o self-update? → A: Exclusivamente via comando explicito
  `cstk self-update`. NAO ha auto-check passivo em nenhum outro comando da CLI (list,
  install, update, doctor) — zero trafego de rede sem demanda explicita do usuario,
  alinhado com Principio IV da constitution (Zero coleta remota). Para verificar sem
  aplicar, o usuario invoca `cstk self-update --check`, que tambem e explicito.
- Q: Como e a primeira instalacao (bootstrap) quando ainda nao ha `cstk` na maquina?
  → A: Via one-liner documentado no README (`curl <url-asset-install.sh> | sh`) que
  baixa o `install.sh` bootstrap da ultima release, que por sua vez baixa o tarball,
  valida checksum e instala `cstk` + `cli/lib/`. Bootstrap e self-update sao fluxos
  DISTINTOS: self-update pressupoe CLI ja instalado e falha com mensagem clara
  instruindo o one-liner caso o binario nao exista.
- Q: Integridade de tarballs baixados e requisito explicito? → A: Sim. Verificacao
  SHA-256 e OBRIGATORIA em todo download de tarball feito pela CLI (bootstrap,
  install, update, self-update). Mismatch aborta a operacao sem realizar qualquer
  escrita no filesystem de destino. O checksum canonico vem de um asset `.sha256`
  publicado na mesma release que o tarball.
- Q: Self-update pode tocar o manifest de skills? → A: Nao. Self-update e estritamente
  sobre o binario `cstk` e a biblioteca `cli/lib/`. Invariante explicita: self-update
  NUNCA le, escreve, nem modifica de qualquer forma o manifest de skills (global ou
  projeto). Verificavel: mtime dos manifests antes e depois do self-update e
  identico. Trava a porta contra regressoes que corromperiam estado de instalacao.
- Q: Semantica operacional de "atomico" em FR-006 (unidade, estado nao-funcional,
  substituicao parcial)? → A: Atomicidade estrita do par binario+biblioteca. Apos
  qualquer interrupcao, o sistema MUST estar 100% na versao antiga OU 100% na nova,
  nunca em estado misto. "Estado nao-funcional" e operacionalizado como qualquer
  situacao em que um comando previamente funcional (pre self-update) falhe, retorne
  exit code diferente, ou produza output inconsistente com a versao reportada por
  `cstk --version`. Substituicao parcial (bin novo + lib antiga, ou inverso) e
  VIOLACAO de FR-006. A implementacao fica livre (stage-and-rename, symlink flip,
  outras), desde que o observavel acima seja preservado.

### Session 2026-04-24

- Q: Estado transiente entre rename de lib e rename de bin (quando kill dura
  impede trap rodar rollback) e observavel pela proxima invocacao — esse terceiro
  estado viola FR-006? → A: Nao. FR-006 passa a reconhecer explicitamente um
  terceiro estado observavel "retry-required": a CLI detecta divergencia bin/lib
  no boot-check e aborta imediatamente com mensagem instrutiva. Nenhum comando
  opera, mas tambem nenhum retorna output incorreto. Proxima invocacao de
  `cstk self-update` completa o rollback. Trade-off aceito: a alternativa
  (rollback automatico no boot) teria surface de bug maior e menos transparencia
  para o usuario.

## User Scenarios & Testing

### User Story 1 - Instalacao inicial de skills no escopo global (Priority: P1)

Desenvolvedor recem-clonou o toolkit em uma maquina nova e precisa que todas as skills
fiquem disponiveis para o Claude Code. Ele executa a CLI uma unica vez apontando para o
escopo global e passa a ter todas as skills do toolkit acessiveis em qualquer projeto.

**Why this priority**: sem instalacao inicial nao ha nada. Esta story e o MVP — entrega
o valor principal (parar de fazer `cp -r` manual e passar a ter uma acao atomica e
rastreavel), mesmo que update, project-scope e self-update ainda nao existam.

**Independent Test**: em uma maquina/ambiente sem `~/.claude/skills/` povoado, rodar o
comando de instalacao global, verificar que todas as skills do toolkit aparecem no
diretorio destino, e que o Claude Code consegue invoca-las por nome.

**Acceptance Scenarios**:

1. **Given** `~/.claude/skills/` vazio ou inexistente, **When** o usuario executa o
   comando de instalacao em escopo global, **Then** todas as skills listadas no
   toolkit ficam disponiveis em `~/.claude/skills/{nome}/` com estrutura identica a
   `global/skills/{nome}/`.
2. **Given** uma maquina recem-configurada sem conexao previa com o toolkit, **When**
   o usuario executa o comando, **Then** a CLI reporta quantas skills foram instaladas
   e grava um registro do que foi instalado e em qual versao.
3. **Given** `~/.claude/skills/foo/` ja existe porque o usuario tem skills de terceiros,
   **When** o comando de instalacao roda, **Then** skills de terceiros (fora do catalogo
   do toolkit) sao preservadas intactas e apenas as skills do toolkit sao instaladas.

---

### User Story 2 - Atualizacao das skills ja instaladas (Priority: P2)

Depois de instalar, o toolkit evolui — skills ganham conteudo novo, bugs de scripts POSIX
sao corrigidos, novas skills sao adicionadas. O usuario precisa trazer essas mudancas para
a copia instalada sem perder edicoes locais que ele tenha feito deliberadamente.

**Why this priority**: endereca diretamente a dor documentada no CLAUDE.md sobre "drift
entre installed e source". Sem atualizacao nao ha razao para o registro de versao existir.
P2 porque so faz sentido depois de ter algo instalado (P1).

**Independent Test**: com uma instalacao existente apontando para uma versao antiga,
rodar o comando de atualizacao e verificar que (a) skills desatualizadas foram atualizadas,
(b) skills ja em dia foram puladas sem escrita desnecessaria, (c) edicoes locais foram
tratadas segundo a politica definida (ver [NEEDS CLARIFICATION] abaixo).

**Acceptance Scenarios**:

1. **Given** instalacao existente com skill `foo` na versao antiga e fonte com `foo` na
   versao nova, **When** o usuario executa o comando de atualizacao, **Then** `foo`
   passa a refletir o conteudo da versao nova e o registro de versao e atualizado.
2. **Given** instalacao existente onde todas as skills ja estao na versao mais recente,
   **When** o usuario executa o comando de atualizacao, **Then** a CLI reporta que nada
   mudou e nao realiza escritas.
3. **Given** uma skill que deixou de existir no toolkit fonte, **When** o usuario executa
   o comando de atualizacao, **Then** a CLI sinaliza essa skill como removida no fonte
   e pede confirmacao antes de apagar a copia instalada.
4. **Given** instalacao com edicoes locais em `~/.claude/skills/foo/SKILL.md` feitas
   manualmente pelo usuario, **When** o usuario executa o comando de atualizacao e `foo`
   tem versao nova disponivel, **Then** o comportamento segue a politica definida em
   FR-008 (abaixo).

---

### User Story 3 - Instalacao em escopo de projeto (Priority: P3)

Um projeto especifico precisa de um conjunto curado de skills (por exemplo, apenas as
do pipeline SDD, mais uma skill `bugfix` customizada) ou de versao travada diferente da
global. O usuario executa a CLI dentro do diretorio do projeto com a flag de escopo de
projeto, e a instalacao acontece em `./.claude/skills/` isoladamente.

**Why this priority**: escopo de projeto e explicitamente pedido. E util para casos em
que o projeto quer travar versao ou subconjunto de skills, mas nao bloqueia o fluxo
principal de um unico desenvolvedor. Funciona de forma analoga ao escopo global — a
unica diferenca e o diretorio destino e o registro de versao.

**Independent Test**: em um diretorio de projeto sem `.claude/skills/`, rodar o comando
com flag de escopo de projeto, verificar que a instalacao ocorreu em `./.claude/skills/`
e nao tocou `~/.claude/skills/`, e que o Claude Code rodando dentro do projeto ve ambas
as copias (a global e a do projeto, com a do projeto tendo prioridade conforme o
comportamento padrao do Claude Code).

**Acceptance Scenarios**:

1. **Given** CWD em um diretorio de projeto sem `.claude/skills/`, **When** o usuario
   executa instalacao em escopo de projeto, **Then** skills sao instaladas em
   `./.claude/skills/` e `~/.claude/skills/` nao e modificada.
2. **Given** instalacao global e de projeto coexistindo, **When** o usuario executa
   atualizacao em escopo de projeto, **Then** apenas a copia do projeto e atualizada e
   a global permanece intacta.

---

### User Story 4 - Self-update da propria CLI (Priority: P4)

A CLI evolui (novos comandos, correcoes de bugs, suporte a novas estruturas de skill).
O usuario executa um comando `self-update` e a CLI se atualiza para a versao mais recente,
sem que ele precise reinstalar manualmente via clonagem do repositorio.

**Why this priority**: util mas nao bloqueante para o MVP. Nos primeiros dias a CLI pode
ser distribuida junto do toolkit via `make install` ou `git pull`; self-update e
conveniencia que paga o proprio custo so quando a base de usuarios cresce ou quando a
CLI passa a ter ciclo de release independente.

**Independent Test**: com uma versao antiga da CLI instalada e uma versao nova disponivel
no canal de distribuicao, rodar o comando de self-update e verificar que apos a execucao
`cstk --version` reporta a nova versao e todos os comandos continuam funcionais.

**Acceptance Scenarios**:

1. **Given** CLI instalada em versao antiga e canal de distribuicao com versao nova,
   **When** o usuario executa `self-update`, **Then** a CLI e substituida pela versao
   nova e subsequentes invocacoes usam a nova versao.
2. **Given** CLI ja na versao mais recente, **When** o usuario executa `self-update`,
   **Then** a CLI informa que ja esta atualizada e nao realiza escritas.
3. **Given** self-update disparado e falha de rede durante o download, **When** o
   download falha, **Then** a CLI antiga permanece funcional e a falha e reportada —
   nenhuma substituicao parcial pode deixar a CLI quebrada.

---

### Edge Cases

- Instalacao invocada sem permissao de escrita em `~/.claude/skills/` — CLI deve abortar
  cedo com mensagem clara, sem deixar estado parcial.
- Atualizacao disparada enquanto outra instancia da CLI ja esta rodando — CLI deve
  detectar lock e abortar em vez de produzir corrupcao.
- Self-update em uma maquina offline — CLI deve falhar cedo e preservar a versao atual.
- Registro de versao corrompido ou ausente — CLI deve reconstruir o registro inspecionando
  o estado atual dos diretorios antes de decidir o que atualizar.
- Skill renomeada no fonte (caso ja documentado no CLAUDE.md como BREAKING MAJOR) — o
  update precisa tratar como remocao + adicao, nao tentar mesclar.
- Usuario executa comando em diretorio que parece projeto mas nao tem `.claude/` — CLI
  deve pedir confirmacao antes de criar `.claude/skills/` do zero, para evitar
  poluicao acidental de um diretorio arbitrario.

## Requirements

### Functional Requirements

- **FR-001**: A CLI MUST oferecer um comando para instalar skills do toolkit em escopo
  global (`~/.claude/skills/`).
- **FR-002**: A CLI MUST oferecer um comando para instalar skills do toolkit em escopo
  de projeto (`./.claude/skills/` relativo ao CWD).
- **FR-003**: A CLI MUST oferecer um comando para atualizar skills ja instaladas,
  detectando quais estao desatualizadas e aplicando apenas as mudancas necessarias.
- **FR-004**: A CLI MUST manter um registro (manifest) por escopo de instalacao,
  informando cada skill instalada e sua versao/identificador correspondente.
- **FR-005**: A CLI MUST suportar self-update — substituir seu proprio binario/executavel
  por uma versao mais nova sem exigir reinstalacao manual. O self-update MUST ser
  disparado exclusivamente por comando explicito do usuario (`cstk self-update`); a
  CLI NAO MUST realizar verificacoes passivas de versao em nenhum outro comando (list,
  install, update, doctor nao falam com a rede para checar novas versoes). Verificacao
  sem instalacao tambem e explicita (`cstk self-update --check`).
- **FR-005a**: A distribuicao MUST disponibilizar um script de bootstrap (`install.sh`)
  publicado junto com cada release, acessivel via URL estavel da ultima release, que
  realize a primeira instalacao via one-liner `curl <url> | sh`. O bootstrap MUST:
  baixar o tarball da ultima release, validar seu checksum, copiar `cstk` para
  `~/.local/bin/` e `cli/lib/` para `~/.local/share/cstk/lib/`, sem exigir sudo nem
  toolchain de build. Bootstrap e self-update sao fluxos DISTINTOS: quando self-update
  e invocado sem o binario existir na maquina, a CLI MUST falhar com mensagem clara
  apontando o one-liner de bootstrap.
- **FR-006**: O self-update MUST ser atomico no par `binario + biblioteca` tratado
  como unidade indivisivel. Apos qualquer interrupcao (rede, kill, falha de disco),
  o sistema MUST ficar em um de tres estados observaveis:
  (a) **100% na versao antiga** — `cstk --version` reporta a versao antiga E todos
      os comandos que funcionavam continuam funcionando com o comportamento antigo;
  (b) **100% na versao nova** — `cstk --version` reporta a versao nova E todos os
      comandos operam com o comportamento novo;
  (c) **transiente "retry-required"** — quando o processo e morto exatamente na
      janela curta entre o commit parcial da biblioteca e o commit do binario, a
      proxima invocacao de `cstk` MUST detectar a divergencia via boot-check e
      abortar imediatamente com mensagem clara instruindo o usuario a re-executar
      `cstk self-update` (que completa o rollback para o estado (a)). Neste estado
      NENHUM outro comando funciona, mas nenhum comando retorna output incorreto —
      a CLI se recusa a agir ate recuperar.

  Substituicao parcial com output incorreto (bin novo rodando com lib antiga que
  responde comandos, ou vice-versa) MUST ser impossivel como estado observavel.
  "Estado nao-funcional" proibido e definido como qualquer estado em que um comando
  retorne exit code zero com output inconsistente com a versao reportada por
  `cstk --version`. O estado (c) acima nao viola a proibicao porque a CLI se recusa
  a operar — um erro claro e aceitavel; output silenciosamente incorreto nao.

  A implementacao (stage-and-rename, symlink flip, co-existencia versionada, etc.)
  fica a cargo do plan tecnico; o FR fixa apenas os estados observaveis.
- **FR-006a**: Self-update MUST NOT ler, escrever ou modificar manifests de skills
  em qualquer escopo (global ou projeto). Self-update opera exclusivamente sobre o
  proprio binario `cstk` e sobre a biblioteca `cli/lib/`, preservando intocado todo
  estado de skills instaladas. Esta invariante MUST ser verificavel no teste: mtime
  dos arquivos `.cstk-manifest` antes e depois de um self-update bem-sucedido MUST
  permanecer identico.
- **FR-007**: A CLI MUST preservar skills de terceiros (fora do catalogo do toolkit)
  presentes no mesmo diretorio destino — instalacao e atualizacao so tocam skills
  cuja origem e o toolkit.
- **FR-008**: Quando uma skill instalada tiver sido editada localmente (conteudo difere
  do manifest registrado), a CLI MUST, durante update, pular essa skill e reportar que
  ela foi preservada, nao realizando nenhuma escrita nela. O usuario MUST poder invocar
  novamente com `--force` para sobrescrever as edicoes locais ou com `--keep` para
  silenciar o aviso e manter a cozinha local. Skills nao afetadas continuam sendo
  atualizadas normalmente no mesmo run — uma skill com edicao local nao interrompe o
  update das demais.
- **FR-009**: A CLI MUST suportar selecao de skills via perfis nomeados (minimo:
  `all`, `sdd`, `complementary`, `language-go`, `language-dotnet`) E via cherry-pick
  por nome explicito de skill. Quando nenhuma selecao e informada, o perfil padrao
  e `sdd` (independente de escopo). A CLI MUST tambem oferecer um modo interativo
  (flag dedicada) que lista perfis e skills disponiveis e permite selecao manual,
  servindo como alternativa ergonomica quando o usuario nao memorizou nomes.
- **FR-009a**: O mesmo mecanismo de selecao (perfis, cherry-pick, interativo) MUST
  valer para update e para install — update em escopo ja instalado opera, por default,
  sobre o que esta instalado naquele escopo (registrado no manifest), e nao sobre o
  perfil default global.
- **FR-009b**: O catalogo que a CLI gerencia MUST incluir: (a) todas as skills de
  `global/skills/` do toolkit; (b) todas as skills de `language-related/{linguagem}/skills/`;
  (c) hooks de `language-related/{linguagem}/hooks/` junto com seu `settings.json` de
  referencia. Hooks sao sempre considerados parte do perfil `language-{linguagem}`.
- **FR-009c**: Hooks e respectivo `settings.json` MUST ser instalaveis APENAS em
  escopo de projeto. Quando um perfil `language-*` e acionado em escopo global, a CLI
  instala apenas as skills desse perfil e omite/ignora os hooks, reportando essa
  omissao no resumo final.
- **FR-009d**: Para mesclar o `settings.json` da linguagem no `./.claude/settings.json`
  do projeto, a CLI MUST: (a) detectar se `jq` esta disponivel no PATH; (b) se sim,
  realizar merge automatico preservando chaves existentes nao conflitantes; (c) se
  nao, imprimir na saida o bloco JSON exato a ser mesclado manualmente e instrucoes
  claras de onde cola-lo. A CLI NUNCA faz merge de JSON sem `jq` nem sobrescreve um
  `./.claude/settings.json` existente.
- **FR-010**: A CLI MUST obter skills e suas atualizacoes a partir de tarballs
  publicados como GitHub Releases do repositorio do toolkit, identificados por tag
  SemVer. A CLI MUST funcionar usando apenas ferramentas POSIX tipicas (`curl`/`tar`)
  sem exigir `git` instalado na maquina do usuario. A CLI MUST falhar com mensagem
  clara quando offline ou quando a release alvo nao existir.
- **FR-010a**: Toda operacao que baixa um tarball do GitHub Releases (bootstrap,
  install, update, self-update) MUST verificar o checksum SHA-256 do tarball contra
  o asset `.sha256` publicado na mesma release ANTES de qualquer escrita no
  filesystem de destino. Em caso de mismatch, a CLI MUST abortar a operacao e
  reportar erro claro, sem ter tocado binario, biblioteca, catalog ou manifest.
  Este requisito se aplica uniformemente a todos os fluxos de download — nao ha
  caminho "rapido" que pule a verificacao.
- **FR-011**: A CLI MUST reportar, em todos os comandos de escrita (install, update,
  self-update), um resumo final com contagem de skills afetadas (instaladas, atualizadas,
  puladas, removidas) e nome/versao da CLI em uso.
- **FR-012**: A CLI MUST aceitar uma flag de dry-run que mostra o que seria feito sem
  executar escritas reais, valido tanto para install quanto update quanto self-update.
- **FR-013**: A CLI MUST ser observavel — o usuario precisa conseguir inspecionar a
  qualquer momento o estado de uma instalacao (quais skills estao presentes, em que
  versao, se ha drift entre manifest e arquivos reais).
- **FR-014**: A CLI MUST detectar quando uma skill foi removida da fonte e sinalizar
  isso ao usuario durante update, exigindo confirmacao antes de apagar.
- **FR-015**: A CLI MUST prevenir execucoes concorrentes no mesmo escopo via lockfile
  para evitar corrupcao quando dois comandos rodam em paralelo.

### Key Entities

- **Skill**: unidade de capacidade instalavel. Identificada por nome (ex: `specify`),
  possui um conjunto de arquivos (`SKILL.md` + subpastas opcionais) e uma versao
  derivada da fonte.
- **Installation Scope**: contexto onde skills ficam instaladas. Dois valores: `global`
  (`~/.claude/skills/`) e `project` (`./.claude/skills/` no CWD).
- **Manifest**: registro persistido por escopo que descreve quais skills foram
  instaladas via CLI, em que versao, e quando. E a fonte de verdade para detectar
  drift e decidir o que atualizar.
- **CLI Release**: versao distribuida da propria CLI `cstk`. Consumida pelo comando
  self-update.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Instalacao inicial em escopo global completa em menos de 30 segundos em
  uma maquina padrao de desenvolvimento com conexao de banda larga residencial tipica.
- **SC-002**: Durante um comando de atualizacao onde zero skills tiveram mudanca na
  fonte, a CLI realiza zero escritas em disco no destino (idempotencia observavel via
  timestamps dos arquivos).
- **SC-003**: Apos execucao bem-sucedida de install ou update, 100% das skills
  instaladas correspondem ao conteudo da versao registrada no manifest (verificavel
  via comparacao byte-a-byte entre fonte e destino para skills sem edicao local).
- **SC-004**: Self-update interrompido no meio (kill de processo, queda de rede) deixa
  a CLI anterior 100% funcional em todas as ocorrencias de teste — zero casos de CLI
  quebrada por atualizacao parcial. O conjunto de teste canonico desse SC e o
  Scenario 7b documentado em `quickstart.md`, que enumera 4 pontos de kill ao longo
  da sequencia stage-and-rename: (1) pos-download pre-stage, (2) pos-stage pre-rename,
  (3) entre rename de lib e rename de bin (janela transiente), e (4) pos-commit
  antes do cleanup.
- **SC-005**: Um usuario novo consegue, lendo apenas o `--help` da CLI e o README, fazer
  a instalacao inicial e uma atualizacao subsequente em menos de 5 minutos sem assistencia
  externa.
- **SC-006**: Dry-run produz saida que descreve com precisao 100% das acoes que a
  execucao real faria (nenhuma acao executada em real ausente do dry-run; nenhuma acao
  listada no dry-run ausente da execucao real).
- **SC-007**: A CLI detecta 100% dos casos de drift entre manifest e estado real do
  filesystem. O conjunto de teste canonico e fechado e contem exatamente quatro
  casos: (1) arquivo deletado manualmente, (2) arquivo editado localmente, (3) skill
  renomeada na fonte, (4) skill removida da fonte. Casos adicionais (ex: permissoes
  alteradas, symlinks introduzidos) sao fora do escopo deste SC e podem ser
  adicionados em specs futuras.