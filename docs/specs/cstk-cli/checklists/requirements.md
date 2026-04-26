# Requirements Checklist: cstk CLI

**Purpose**: valida qualidade dos requisitos com foco em (a) testabilidade dos
Success Criteria e (b) clareza dos FRs relacionados a self-update. "Unit tests
for English" — cada item testa qualidade do REQUISITO escrito, nao da implementacao.
**Created**: 2026-04-22
**Feature**: [spec.md](../spec.md)

## Testabilidade dos Success Criteria

### SC-001 (instalacao < 30s em banda larga tipica)

- [ ] CHK001 - "Banda larga tipica" e quantificado com intervalo de Mbps ou referencia
  a um benchmark publico (ex: 100 Mbps FTTH, sera medio brasileiro 2026)? [Clareza, Spec §SC-001]
- [ ] CHK002 - "Maquina padrao de desenvolvimento" e caracterizado por especificacoes
  minimas (CPU class, SSD vs HDD, RAM) para o teste ser reproduzivel? [Clareza, Spec §SC-001]
- [ ] CHK003 - O cronometro de 30 segundos comeca e termina em pontos observaveis
  bem definidos (ex: invocacao do comando ate exit 0)? [Mensurabilidade, Spec §SC-001]
- [ ] CHK004 - O requisito especifica o tamanho aproximado do catalog base contra o
  qual os 30s valem? (Com 100 skills vs 20, o mesmo 30s pode ser inatingivel.) [Gap, Spec §SC-001]

### SC-002 (zero escritas quando nada mudou)

- [ ] CHK005 - "Zero escritas" e definido precisamente — mtime inalterado? inode
  inalterado? ausencia total de `open(2)` em write mode? [Clareza, Spec §SC-002]
- [ ] CHK006 - O criterio contempla que o manifest em si pode ser re-escrito com
  conteudo identico (escrita ocorre mas byte-a-byte igual)? O requisito deveria
  proibir isso ou aceitar? [Ambiguity, Spec §SC-002]
- [ ] CHK007 - O criterio vale tambem para re-escrita do lockfile (criado+removido
  a cada run)? Se sim, lock-via-`mkdir` tecnicamente escreve no filesystem. [Ambiguity, Spec §SC-002]

### SC-003 (100% match byte-a-byte pos install)

- [ ] CHK008 - O requisito define explicitamente como "skill sem edicao local" e
  identificada para ser incluida no conjunto verificado? [Clareza, Spec §SC-003]
- [ ] CHK009 - Arquivos binarios (se existirem em skills futuras) sao tratados da
  mesma forma que texto? Newline endings sao normalizados? [Gap, Spec §SC-003]
- [ ] CHK010 - Files de metadados (timestamps, attributos extendidos xattr) sao
  parte do "byte-a-byte" ou excluidos? [Ambiguity, Spec §SC-003]

### SC-004 (self-update interrompido = CLI antigo funcional em 100% dos testes)

- [x] CHK011 - O "conjunto de teste" e definido em tamanho e composicao (ex: N
  cenarios cobrindo kill em cada etapa do self-update)? [Gap, Spec §SC-004]
  → Resolvido: SC-004 agora ancora explicitamente no Scenario 7b de
  `quickstart.md`, que enumera 4 pontos de kill ao longo da sequencia
  stage-and-rename (pos-download, pos-stage, janela transiente, pos-commit).
- [ ] CHK012 - "CLI anterior 100% funcional" e verificavel — lista de comandos que
  devem funcionar pos-interrupcao esta especificada? [Clareza, Spec §SC-004]
- [x] CHK013 - O requisito especifica em qual momento do self-update a interrupcao
  pode ocorrer (antes do download, durante, apos checksum, durante mv)? Todos os
  momentos? [Gap, Spec §SC-004]
  → Resolvido: SC-004 lista os 4 pontos canonicos de kill — (1) pos-download
  pre-stage, (2) pos-stage pre-rename, (3) entre rename de lib e rename de bin
  (janela transiente, agora coberta pelo estado retry-required de FR-006), e
  (4) pos-commit antes do cleanup.
- [ ] CHK014 - "100% das ocorrencias de teste" e mensuravel — ha definicao de
  quantas execucoes constituem o conjunto estatistico valido? [Mensurabilidade, Spec §SC-004]

### SC-005 (novo usuario completa install+update em <5min)

- [ ] CHK015 - "Novo usuario" e caracterizado com persona especifica (ja usa Claude
  Code? sabe shell? tem `curl` instalado?) para o teste ser replicavel? [Clareza, Spec §SC-005]
- [x] CHK016 - "Sem assistencia externa" inclui acesso ao stack-overflow/LLM ou exige
  apenas README + --help? [Ambiguity, Spec §SC-005]
  → Resolvido: SC-005 ja restringe explicitamente a "lendo apenas o `--help`
  da CLI e o README", o que exclui assistencia externa (StackOverflow/LLM).
- [ ] CHK017 - A metrica de 5 minutos comeca do zero absoluto (ainda sem cstk
  instalado) ou apos o CLI ja estar instalado? [Clareza, Spec §SC-005]

### SC-006 (dry-run = execucao real)

- [ ] CHK018 - "Uniao simetrica vazia" e operacionalmente mensuravel — formato de
  saida comparavel esta especificado (ex: cada linha de acao em formato fixo)?
  [Mensurabilidade, Spec §SC-006]
- [ ] CHK019 - Mensagens humanas (stderr "Downloading...") que so fazem sentido em
  execucao real sao excluidas da comparacao? [Ambiguity, Spec §SC-006]

### SC-007 (doctor detecta 100% em conjunto de teste)

- [x] CHK020 - O "conjunto de teste" esta enumerado exaustivamente — os 4 casos
  listados (deletado/editado/renomeado/removido) sao a unica cobertura obrigatoria
  ou ha mais? [Clareza, Spec §SC-007]
  → Resolvido: SC-007 declara explicitamente que o conjunto canonico e
  "fechado e contem exatamente quatro casos" — cobertura obrigatoria.
- [ ] CHK021 - O requisito define o que constitui "detectar" — apenas flagear? ou
  propor fix correto? (contratos mencionam --fix.) [Clareza, Spec §SC-007]
- [x] CHK022 - O criterio cobre ordem/interacao de drifts (ex: skill editada E
  removida do catalog simultaneamente) ou apenas casos isolados? [Cobertura, Spec §SC-007]
  → Resolvido: SC-007 declara casos compostos/adicionais (permissoes,
  symlinks, interacoes) como "fora do escopo deste SC" — apenas casos
  isolados sao obrigatorios. Ambiguidade fechada por exclusao explicita.

## Clareza dos FRs relacionados a self-update

### FR-005 (self-update existe)

- [x] CHK023 - O FR define como o usuario dispara o self-update (comando explicito
  vs auto-check no boot de todo invoke)? A spec nao diz. [Gap, Spec §FR-005]
  → Resolvido em Clarifications 2026-04-22 (follow-up): exclusivamente comando
  explicito; zero auto-check. FR-005 atualizado.
- [x] CHK024 - O FR especifica onde a CLI esta instalada para que saiba o que
  atualizar? (Spec silencia; detalhe esta em research, nao em FR.) [Gap, Spec §FR-005]
  → Resolvido via FR-005a (adicionado na mesma session): paths `~/.local/bin/cstk`
  e `~/.local/share/cstk/lib/` agora sao requisito explicito.
- [x] CHK025 - O FR cobre a transicao da primeira release (quando nao ha versao
  anterior) — instalacao inicial e self-update sao o mesmo fluxo? [Gap, Spec §FR-005]
  → Resolvido em Clarifications 2026-04-22 (follow-up): bootstrap one-liner via
  `install.sh` publicado na release; fluxos distintos. FR-005a adicionado.

### FR-006 (self-update atomico)

- [x] CHK026 - "Atomico" e operacionalizado — o FR define qual transicao deve ser
  atomica (binario? biblioteca? ambos conjuntos)? [Clareza, Spec §FR-006]
  → Resolvido via reescrita de FR-006: atomicidade estrita do par bin+lib tratado
  como unidade indivisivel.
- [x] CHK027 - "Estado nao-funcional" e especificado — o que conta como nao-funcional?
  Binario corrompido? Shebang invalido? Faltando um modulo de lib? [Clareza, Spec §FR-006]
  → Resolvido via reescrita de FR-006: comando previamente funcional falha OU exit
  code diferente OU output inconsistente com `cstk --version`.
- [x] CHK028 - O FR contempla cenario onde o bin e atualizado com sucesso mas o
  lib/ falha depois (ou vice-versa) — essa divergencia e aceitavel ou viola
  "atomicidade"? [Ambiguity, Spec §FR-006]
  → Resolvido via reescrita de FR-006: substituicao parcial e VIOLACAO;
  sistema so pode estar 100% antigo ou 100% novo como estado observavel.
- [x] CHK029 - O FR especifica que o CLI-em-execucao atual nao pode ser afetado
  por self-update disparado por outro processo (caso teorico de dois self-update
  simultaneos)? [Gap, Spec §FR-006]
  → Resolvido junto com CHK033: lock exclusivo de self-update em
  `$CSTK_LIB/../.self-update.lock` (research Decision 4, contracts self-update
  passo 1, tasks 5.1.4) impede dois self-update simultaneos.

### FRs correlatos que impactam self-update

- [x] CHK030 - FR-010 define a fonte como GitHub Releases, mas nao explicita se
  self-update valida assinatura/checksum do tarball baixado. Ha requisito explicito
  para isso? [Gap, Spec §FR-010, §FR-006]
  → Resolvido em Clarifications 2026-04-22 (follow-up): SHA-256 obrigatorio em todo
  download de tarball; mismatch = abort sem escrita. FR-010a adicionado.
- [ ] CHK031 - FR-011 exige summary com "nome/versao da CLI em uso" — vale para
  self-update reportar versao ANTIGA ou NOVA no summary? Ambiguidade podera gerar
  confusao operacional. [Ambiguity, Spec §FR-011]
- [ ] CHK032 - FR-012 exige dry-run em self-update. O FR cobre como dry-run reporta
  a versao alvo e o plano de arquivos tocados sem realmente tocar? [Clareza, Spec §FR-012]
- [x] CHK033 - FR-015 previne execucoes concorrentes por escopo de skills. Self-update
  nao e ligado a escopo — ha requisito paralelo impedindo dois self-update
  simultaneos ou esse caso esta nao-especificado? [Gap, Spec §FR-015, §FR-005]
  → Resolvido como parte do ajuste cirurgico pos-clarify FR-006: lock exclusivo de
  self-update em `$CSTK_LIB/../.self-update.lock` documentado em research Decision 4,
  tasks 5.1.4 e contracts self-update passo 1.

## Consistencia cross-requirement

- [x] CHK034 - SC-004 (self-update interrompido = CLI antigo funcional) e consistente
  com a politica de FR-006 (atomico)? Se atomico, interrompido deveria significar
  "NADA foi substituido" — e isso esta escrito inequivocamente? [Consistencia, Spec §SC-004, §FR-006]
  → Resolvido: FR-006 reescrito enumera 3 estados observaveis pos-interrupcao
  (100% antigo, 100% novo, retry-required) e proibe substituicao parcial com
  output incorreto. SC-004 ancora no Scenario 7b (4 kill points) e o estado
  retry-required cobre exatamente a janela transiente em que "NADA foi
  substituido" nao e literalmente verdade — alinhamento explicito.
- [x] CHK035 - SC-005 (novo usuario em 5min) depende da existencia de install
  via one-liner/bootstrap. Esse bootstrap e requisito funcional explicito ou apenas
  detalhe do plan? [Gap, Spec §SC-005]
  → Resolvido via FR-005a: bootstrap via one-liner `curl <url-install.sh> | sh`
  publicado junto com cada release e agora requisito funcional formal.
- [ ] CHK036 - FR-005 diz "suportar self-update" mas nao referencia explicitamente
  que a versao alvo e sempre a ULTIMA release. Usuario pode quer self-update para
  versao arbitraria (downgrade, pin). Esse caso esta coberto ou fora de escopo?
  [Gap, Spec §FR-005]
- [ ] CHK037 - A politica de `--force`/`--keep` em update (FR-008) tem analogo
  para self-update (ex: se a nova versao do CLI seria incompativel com o manifest
  v1 atual)? Requisito silente. [Gap, Spec §FR-008, §FR-005]

## Ambiguidades e lacunas adicionais (self-update especifico)

- [x] CHK038 - Ha requisito exigindo que self-update preserve o manifest das skills
  instaladas? (Obvio, mas nao esta escrito — e uma regressao seria desastrosa.)
  [Gap, Spec §FR-005]
  → Resolvido em Clarifications 2026-04-22 (follow-up): self-update NUNCA toca
  manifests; invariante verificada por mtime inalterado. FR-006a adicionado.
- [x] CHK039 - Self-update exige conexao com GitHub. Ha requisito explicito sobre
  comportamento offline alem do Edge Case listado? [Gap, Spec §FR-005, §Edge Cases]
  → Resolvido via FR-010: "A CLI MUST falhar com mensagem clara quando offline
  ou quando a release alvo nao existir" — aplica-se a todos os fluxos de
  download, inclusive self-update.
- [ ] CHK040 - Ha requisito de observabilidade minima para self-update (log em
  arquivo, rollback trace) ou toda informacao vive apenas em stderr daquele run?
  [Gap, Spec §FR-005]

## Notes

- Marcar items concluidos com `[x]`
- Items numerados sequencialmente (CHK001 a CHK040)
- Items com `[Gap]` indicam que a spec precisa ser AMPLIADA
- Items com `[Ambiguity]` indicam que existe requisito mas interpretacao dupla
- Items com `[Clareza]` indicam que requisito existe mas termos vagos precisam
  quantificacao
- Items com `[Consistencia]` indicam conflito potencial entre dois requisitos
- Items com `[Mensurabilidade]` indicam criterios nao diretamente observaveis
- Rodar `/clarify` nos items `[Ambiguity]` / `[Gap]` de maior impacto antes de
  `/create-tasks`
