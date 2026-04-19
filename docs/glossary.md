# Glossário

Vocabulário do `claude-ai-tips`. Termos em ordem alfabética.

## A

### Agnóstica (skill)

Skill que não depende de linguagem, plataforma ou serviço específico. Vive em
`global/skills/`. Exemplos: `cred-store`, `bugfix`, `briefing`.

### Audit log

Arquivo append-only que registra operações sensíveis (resolve de credencial,
chamada API destrutiva). Contém metadata mas **nunca valores de segredos**.
Tipicamente em `~/.claude/credentials/<provider>/audit.log`.

## B

### Backing service

Serviço externo consumido pela aplicação via rede/cliente (DB, cache, search,
fila). Termo do [12-factor app](https://12factor.net/backing-services).
Equivalente ao que o toolkit chama de `data-related/`.

### Body (de commit)

Texto após subject line, separado por linha em branco. Descreve **o que
mudou** e **por que**, não apenas **o quê** (que está no subject). Obrigatório
em commits `feat`, `fix` e `BREAKING CHANGE` (mínimo 20 chars no padrão
clw-auth).

### Breaking change

Mudança incompatível com versão anterior. Dispara bump **MAJOR** em SemVer.
Sinalizada via `feat!:` (bang) no header OU `BREAKING CHANGE:` no footer.
Em 0.x, alguns projetos tratam como MINOR (ver [semver.md](../global/skills/git-methodology/references/semver.md)).

### Bump

Incremento de versão SemVer. Tipos: `major` (1.x → 2.0), `minor` (1.2 → 1.3),
`patch` (1.2.3 → 1.2.4). Detectado automaticamente por `release-please` ou
pelo script `release.mjs` a partir dos commits desde última tag.

## C

### Cascata (de fontes)

Estratégia de `cred-store` para resolver credenciais: tenta fonte mais segura
primeiro (env → 1Password → Keychain → arquivo). Primeira que retorna vence.
Cada entrada no registry declara fonte primária e opcionais fallback.

### CHANGELOG

`CHANGELOG.md` no formato [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Documenta mudanças por versão com seções: Added, Changed, Deprecated,
Removed, Fixed, Security.

### CLI (Conventional)

Ver [Conventional Commits](#conventional-commits).

### Conventional Commits

Especificação [conventionalcommits.org/v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
Formato `type(scope): description` com types padrão (`feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`).

### `core.hooksPath`

Configuração git que aponta para diretório de hooks alternativo ao `.git/hooks/`.
Usada para versionar hooks no repo (`.githooks/`) e compartilhar entre
contribuidores. Per-clone: cada clone precisa configurar (postinstall
automatiza).

### `cred-store`

Skill agnóstica de **leitura** de credenciais via cascata. Não-interativa.
Invocada por outras skills quando precisam autenticar contra serviços externos.

### `cred-store-setup`

Skill agnóstica de **registro** interativo de credenciais novas. Guia
usuário por escolha de fonte, coleta de segredo sem echo, coleta de metadata,
validação opcional, gravação no registry.

## D

### `data-related/`

Namespace top-level para skills de **consumo** de dados/serviços externos —
queries, DSL, mapping, padrões de acesso. Responde "como meu código fala com
o serviço?". Ver [architecture.md](./architecture.md#data-related).

### DSL (Domain-Specific Language)

Linguagem de domínio específico. Contexto do toolkit: query DSL de
Elasticsearch, Cypher do Neo4j, HCL do Terraform, etc.

### Dry-run

Modo que **simula** operação sem executá-la. Útil antes de ops destrutivas.
Convenção nas skills: flag `--dry-run` imprime request/comando sem aplicar.

## E

### Extra-files (release-please)

Arquivos além de `package.json` que contêm número de versão e devem ser
atualizados em cada release (HTML, JSON de i18n, constants.ts). Configurados
em `release-please-config.json` via array `extra-files`.

## F

### Frontmatter YAML

Bloco YAML no topo de SKILL.md entre `---`. Contém metadata consumida pelo
Claude Code: `name`, `description`, `argument-hint`, `allowed-tools`,
opcionalmente `version`.

## G

### `.githooks/`

Diretório versionado no repo com hooks git customizados (`commit-msg`,
`pre-commit`, etc.). Ativado via `git config core.hooksPath .githooks`.

### `global/skills/`

Diretório de skills agnósticas (não-categorizadas por linguagem/plataforma/
dados). Inclui pipeline SDD, skills complementares e agnósticas da 2.x
(`cred-store`, `git-methodology/`, etc.).

### GraphQL (Cloudflare Analytics)

API alternativa ao REST tradicional. CF expõe Analytics via `POST /graphql`
em `https://api.cloudflare.com/client/v4/graphql`. Usada para queries com
agregação (top hosts, top IPs, timeseries).

## H

### Hook (git)

Script executado automaticamente pelo git em pontos específicos do ciclo
(pre-commit, commit-msg, pre-push, post-commit, etc.). No toolkit:
`commit-msg` e `pre-commit` padrão; outros sob demanda.

### Hook (Claude Code)

Shell script registrado em `settings.json` do projeto que intercepta ações
do Claude Code. Tipos: `PreToolCall`, `PostToolCall`, `Stop`. Usado para
validação automática (ex: `check-wrangler-version`).

## I

### Idempotente (script)

Script que produz mesmo resultado se rodado múltiplas vezes. No toolkit:
`init-store.sh`, `install-hooks.sh`, `scaffold.sh` são idempotentes — não
sobrescrevem arquivos existentes (exceto com `--force`).

### Identidade (enforce de)

Padrão do hook `pre-commit` que rejeita commits de autores diferentes do
esperado. Configurável via `REQUIRED_NAME` + `REQUIRED_EMAIL` no template.

## K

### Keep a Changelog

Formato de [CHANGELOG.md](#changelog). Especificação 1.1.0 em
[keepachangelog.com](https://keepachangelog.com/en/1.1.0/).

### Keychain (macOS)

Gerenciador de credenciais nativo do macOS. Acessado via CLI `security`.
Uma das fontes suportadas por `cred-store`.

### Key (credential)

Identificador único de credencial no registry. Formato:
`<provider>.<account>.<credtype>`. Exemplos: `cloudflare.idcbr.api_token`,
`neon.production.api_key`, `elasticsearch.smartgw.password`.

## L

### `language-related/`

Namespace top-level para skills específicas de **linguagem/ecossistema**.
Responde "como o código é escrito?". Cobre Go, .NET, planejado TS e Python.

## M

### Manifest (release-please)

Arquivo `.release-please-manifest.json` que rastreia a versão atual do
projeto. Formato: `{ ".": "1.2.3" }` para single package, ou
`{ "packages/web": "1.0", "packages/api": "2.0" }` para monorepo.

### Metadata (credential)

Dados **públicos** associados a uma credencial no `registry.json`: `account_id`,
`email`, `zone_ids`, `token_permissions`, etc. Nunca contém o segredo.
Consumido por skills via `resolve.sh --with-metadata`.

### Monorepo

Repositório com múltiplos pacotes versionados independentemente. Suportado
nativamente por release-please via `include-component-in-tag: true` e tags
no formato `<component>-vX.Y.Z`.

## N

### Nickname (account)

Apelido curto e kebab-case para identificar conta em multi-account. Ex:
`idcbr`, `pessoal`, `cliente-acme`. Usado em `--account=<nick>` nas skills
de API.

## O

### 1Password CLI (`op`)

CLI oficial da 1Password. Instalação: `brew install 1password-cli`. Comandos:
`op signin`, `op read "op://vault/item/field"`. **Fonte recomendada** para
credenciais do toolkit.

### Operation (ops vs consumo)

Dicotomia que guia decisão entre `platform-related/` e `data-related/`. Ops =
provisionar/configurar/deployar. Consumo = escrever queries/DSL/patterns
contra recurso já existente.

## P

### `platform-related/`

Namespace top-level para skills de **plataforma/runtime**. Responde "como o
recurso é provisionado/operado?". Cobre Cloudflare (`cloudflare-shared/`,
`cloudflare-workers/`, `cloudflare-dns/`), Neon, planejados outros.

### Playbook (insights)

`global/insights/usage-insights.md` — documento com padrões empíricos
extraídos de análise de 134 sessões + 1490 mensagens reais de uso.
Consumido pela skill `apply-insights`.

### POSIX (shell)

Padrão POSIX.1-2017 para shell scripts. Toolkit usa POSIX sh (não Bash-only)
para máxima portabilidade: `sh`, não `bash`; sem arrays; sem `[[ ... ]]`;
sem process substitution `<()`.

### Pre-1.0

Versões `0.x.y`. Toolkit suporta 2 convenções:

- **Tradicional**: minor/major normais, projeto imaturo
- **clw-auth pattern**: major em 0.x vira minor (reserva 1.0 como marco
  de estabilidade)

Configurável no `release.mjs` via `PRE_1_0_MAJOR_AS_MINOR`.

### Progressive disclosure

Estratégia de organização: `SKILL.md` enxuto com links para subpastas
(`templates/`, `references/`, `examples/`, `scripts/`). Modelo carrega
sob demanda — paga custo de contexto apenas do SKILL.md na invocação.

### PR (Pull Request)

Branch submetida ao repositório upstream para revisão + merge. Toolkit usa
GitHub PRs; cada fase tem PR separado com body rico documentando escopo,
commits, estrutura e checklist.

## R

### `registry.json`

Arquivo central do cred-store em `~/.claude/credentials/registry.json`.
Mapeia cada key para `{source, ref, metadata, created_at, updated_at}`.
Nunca contém segredos. Permissões `600`.

### Release-please

Tool do Google que automatiza releases via GitHub Actions. Abre/atualiza
PR de release em cada push para `main`, gera CHANGELOG, bumpa versão.
Cobertura em `release-please-setup/`.

### Resolve (credencial)

Ato de obter o valor de uma credencial a partir da key. Feito por
`cred-store/scripts/resolve.sh <key>`. Retorna segredo em stdout
(formatos `raw|env|json`) + exit code indicativo.

## S

### Scope (conventional commits)

Parte entre parênteses em `type(scope): description`. Tipicamente nome de
módulo (`auth`, `db`), subprojeto (`web`, `api`) ou domínio (`billing`).
Kebab-case.

### Script (POSIX)

Ver [POSIX](#posix-shell).

### Secret

Sinônimo para credencial no contexto do toolkit. Termo também usado para
`wrangler secret put` (Cloudflare Workers secrets, que são distintos do
cred-store).

### SDD (Spec-Driven Development)

Metodologia codificada no pipeline de 10 skills: briefing → constitution →
specify → clarify → plan → checklist → create-tasks → analyze → execute-task
→ review-task. Ver [architecture.md](./architecture.md#pipeline-sdd-spec-driven-development).

### SemVer

[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Formato
`MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`. Ver [semver.md](../global/skills/git-methodology/references/semver.md).

### Skill

Unidade invocável do toolkit. Pasta contendo `SKILL.md` + opcionais
`templates/`, `examples/`, `references/`, `scripts/`, `config.json`.
Carregada pelo Claude Code a partir de `.claude/skills/` (local) ou
`~/.claude/skills/` (global).

### `SKILL.md`

Arquivo canônico de cada skill. Frontmatter YAML + instruções markdown.
Fonte consumida pelo Claude Code em invocação — documentação em `docs/`
é **complementar**.

### Soft delete

Padrão de deletar registro marcando coluna `deleted_at` com timestamp ao
invés de remover fisicamente. Convenção observada nos projetos de
referência (unity, inde, split-ai). Documentado como regra em insights.

### Store (credential)

Ver [cred-store](#cred-store). Diretório `~/.claude/credentials/` com
`registry.json`, `audit.log`, `files/`, `<provider>/` por conta.

## T

### Tag (git)

Referência a commit específico. Tipos: lightweight (só ponteiro) e
**anotada** (com autor, data, mensagem). Toolkit usa **sempre** anotada
(`git tag -a v1.2.3 -m "..."`).

### Template (de skill)

Arquivo em `<skill>/templates/` pronto para copiar para projeto-cliente.
Exemplos: `release-please-config.json`, `commit-msg`, `release.mjs`.

### Token (API)

Credencial moderna que substitui Global API Key. Scoped (permissões
limitadas) e rotacionável. Header `Authorization: Bearer <token>`.
Formato recomendado para todas as APIs suportadas.

### Trigger-condition

Estilo da description no frontmatter YAML: "Use quando X, Y ou Z. NÃO
use quando W." ao invés de "Skill que faz X". Padrão capturado como
valor no próprio projeto, especialmente relevante com modelos que
interpretam descriptions literalmente.

## U

### `[Unreleased]`

Seção de CHANGELOG que acumula mudanças desde última tag. Obrigatória em
projetos com release-please. No release, contents viram `[X.Y.Z] - DATE`
e novo `[Unreleased]` vazio é criado.

### UTC

Fuso horário usado em timestamps de CHANGELOG, audit log e tags. Convenção
codificada em skills — `new Date().toISOString()` retorna UTC por padrão.

## V

### Vault (1Password)

Container no 1Password (Personal, Work, Shared). Cada item fica em um
vault. URI `op://<vault>/<item>/<field>` identifica unicamente.

### Version-aware (skill)

Skill que considera versão do cliente/SDK/CLI. Exemplos: `cf-wrangler-update`
compara versão local vs latest do npm; skill futura de ES consideraria
cliente 7/8/9 por breaking changes entre majors.

## W

### Wrangler

CLI oficial da Cloudflare para Workers/D1/KV/R2/Pages. Instalação: `bun add
-d wrangler@latest` (devDep) ou `npm i -g wrangler` (global — menos comum).
Cobre subset das operações CF (deploy, dev, tail, secret, d1 migrations,
queues create). Para o que não cobre, usar `cf-api-call`.

### `wrangler.toml` / `wrangler.jsonc`

Arquivo de configuração do Wrangler. Define bindings (D1, KV, R2, Queues),
compatibility_date, cron triggers, variáveis não-sensíveis, etc. Editado
**manualmente** — skills de API não tocam.

## Z

### Zone (Cloudflare)

Domínio gerenciado pela Cloudflare (ex: `example.com`). Identificado por
`zone_id` (32 hex chars). Operações DNS, WAF, cache, rules são
zone-scoped. Listadas via `GET /zones`.

## Abreviações comuns

| Sigla | Significado |
|-------|-------------|
| CI | Continuous Integration |
| CD | Continuous Deployment |
| CF | Cloudflare |
| CLI | Command-Line Interface |
| DSL | Domain-Specific Language |
| HCL | HashiCorp Configuration Language |
| KV | Key-Value (Cloudflare Workers KV storage) |
| MRC | Minimum Reproducible Case |
| PKCE | Proof Key for Code Exchange (OAuth 2.1) |
| R2 | Cloudflare object storage (S3-compatible) |
| RBAC | Role-Based Access Control |
| SDD | Spec-Driven Development |
| TTL | Time To Live |
| UUID | Universally Unique Identifier |
| UTC | Coordinated Universal Time |
| WAF | Web Application Firewall |
