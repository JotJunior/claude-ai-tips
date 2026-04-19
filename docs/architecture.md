# Arquitetura e Filosofia

Por que o toolkit é organizado como está, e como decidir onde cada coisa nova
deve entrar.

## Princípio central

Toda skill responde a **uma das três perguntas**:

| Pergunta | Categoria |
|----------|-----------|
| "Como o código é escrito em X?" | `language-related/` |
| "Como o recurso é provisionado/operado?" | `platform-related/` |
| "Como meu código consome o serviço?" | `data-related/` |

Quando a skill é **agnóstica** (serve qualquer linguagem/plataforma/serviço),
vai para `global/skills/`.

Esse princípio é a **única regra** de organização — todas as outras decisões
descendem dela.

## As 3 categorias em detalhe

### `language-related/`

Skills/hooks específicos de **linguagem e ecossistema**. Mudam quando você
troca de linguagem.

**Entra aqui:**
- Scaffold de módulos idiomáticos (entidade Go, feature .NET, componente React)
- Commits com convenções da stack
- Geração de testes idiomáticos
- Gates de lint/typecheck específicos
- Padrões de DDD no layout do próprio código

**NÃO entra aqui:**
- Como criar banco de dados (é plataforma)
- Como escrever queries (é consumo de dados)
- Skills de processo agnósticas (vão para `global/`)

**Estado atual:**

| Subpasta | Status |
|----------|--------|
| `go/` | 8 skills + 4 hooks |
| `dotnet/` | 8 skills |
| `typescript/` | planejada |
| `python/` | planejada |

### `platform-related/`

Skills/hooks específicos de **plataforma/runtime onde o código roda** e de
**provisionamento de recursos**.

**Entra aqui:**
- Comandos CLI proprietários (`wrangler`, `cloudflared`, `flyctl`, `vercel`)
- APIs de provisionamento (criar DB, criar zona DNS, criar Worker)
- Configuração de bindings (`wrangler.toml`, etc.)
- Deploy e lifecycle de recursos
- Setup de credenciais específicas de plataforma

**NÃO entra aqui:**
- Como escrever código que roda na plataforma (é linguagem)
- Como consumir dados de DB provisionado (é consumo)

**Estado atual:**

| Subpasta | Status |
|----------|--------|
| `cloudflare-shared/` | parcial (3 skills + 1 hook + 3 references) |
| `cloudflare-workers/` | planejada |
| `cloudflare-dns/` | planejada |
| `neon/` | planejada |

### `data-related/`

Skills específicas de **consumo de serviços externos** — queries, DSL, mapping,
padrões de acesso.

**Entra aqui:**
- Escrever SQL, query DSL de ES, aggregation pipeline Mongo
- Modelagem de schema
- Indexação, particionamento, otimização
- Padrões de cache, pub/sub, fila consumer
- Migration strategies (no nível SQL)

**NÃO entra aqui:**
- Como criar o DB/cluster (é plataforma)
- Como escrever código cliente (é linguagem)

**Estado atual:**

| Subpasta | Status |
|----------|--------|
| `postgres/` | planejada |
| `d1/` | planejada |
| `elasticsearch/` | planejada |

### A dicotomia "provisionar vs consumir"

O mesmo serviço pode ter facetas em **categorias diferentes**:

| Serviço | Platform (ops) | Data (consumo) |
|---------|----------------|----------------|
| D1 | `wrangler d1 create`, `migrations apply` | query patterns, batch vs serial, FTS5 |
| Postgres (Neon) | API Neon: projects, branches, compute | queries SQL, indexing, JSONB, EXPLAIN |
| Elasticsearch | ILM, snapshots, shard allocation | DSL queries, mapping design, aggregations |

**Regra mnemônica:**

> Se é `wrangler ...`, `cloudflared ...`, API de provisionamento ou config
> de binding → `platform-related/`.
>
> Se é SQL, DSL de query, mapping, padrão de cache, consumer de fila →
> `data-related/`.

## `global/` — skills agnósticas

Nem toda skill cabe nas 3 categorias. Skills **transversais** ficam em
`global/skills/`:

### Pipeline SDD (Spec-Driven Development)

```
briefing → constitution → specify → clarify → plan
                                                  ↓
review-task ← execute-task ← analyze ← create-tasks ← checklist
```

10 skills que levam ideia → código via artefatos versionados (`spec.md`,
`plan.md`, `tasks.md`, ...). Não dependem de linguagem, plataforma ou dados.

### Skills complementares

- `advisor` — conselheiro brutalmente honesto (ideias/planos/decisões)
- `bugfix` — protocolo stack-agnostic de 8 etapas para bugs multi-camada
- `create-use-case` — UC formal em formato `UC-{DOMINIO}-{NNN}`
- `image-generation` — prompts estruturados Subject-Context-Style
- `initialize-docs` — scaffold `docs/01-09/`
- `owasp-security` — OWASP Top 10:2025 + ASVS 5.0 + AI Agent Security 2026
- `apply-insights` — aplica playbook empírico ao CLAUDE.md do projeto
- `validate-documentation` / `validate-docs-rendered`

### Skills agnósticas da 2.x

- `cred-store` / `cred-store-setup` — credenciais com cascata
- `git-methodology/` (hub não-invocável)
- `release-please-setup` / `release-manual-setup`
- `changelog-write-entry`
- `git-hooks-install`
- `release-quality-gate`

## Anatomia de uma skill

Uma skill é **uma pasta** com:

```
<skill-name>/
├── SKILL.md           # frontmatter YAML + instruções ao modelo
├── templates/         # documentos/configs preenchíveis
├── examples/          # good.md vs bad.md comentados
├── references/        # material consultado sob demanda
├── scripts/           # POSIX sh para operações determinísticas
└── config.json        # parâmetros por projeto (opcional)
```

Nem toda skill usa todas as subpastas. O mínimo é `SKILL.md`.

### Frontmatter YAML — trigger-condition, não resumo

Descrição da skill deve dizer **quando invocar**, não **o que faz**:

```yaml
---
name: cred-store
description: |
  Use quando uma skill precisa LER uma credencial (API token, password,
  connection string) de forma segura. Tambem quando o usuario pedir para
  "resolver credencial", "ler token", "carregar secret". Cascata:
  env var -> 1Password CLI -> macOS Keychain -> arquivo protegido.
  NAO use para ARMAZENAR credenciais novas (use cred-store-setup).
argument-hint: "<credential-key> [--format=raw|env|json]"
allowed-tools: [Bash, Read]
---
```

Padrão capturado dos projetos em produção: modelo precisa **decidir quando
invocar**, não apenas **o que ela faz**. Particularmente relevante com Opus
4.7, que interpreta descrições de forma mais literal.

### Seção Gotchas

Toda SKILL.md tem uma seção `## Gotchas` no final com armadilhas conhecidas.
É o conteúdo de **maior valor** da skill — o diferencial sobre o happy-path.

Exemplo (de `cred-store/SKILL.md`):

```markdown
## Gotchas

### Não imprimir segredo em log nem em mensagem de erro
### Segredo em variável de ambiente vaza em `ps -E`
### 1Password CLI tem cache de sessão curto
### audit.log nunca contém segredo
### Não é substituto para secrets de projeto
```

### Scripts POSIX

Toda ação que não precisa de LLM (calcular próximo ID, extrair métricas,
scaffold de pasta, validar regex) vira `scripts/*.sh`:

- Economiza tokens
- Evita alucinação em contas simples
- Determinístico por definição
- Testável isoladamente

Padrão de header (consistente no toolkit):

```sh
#!/bin/sh
# <nome-do-script> — <resumo em uma linha>.
#
# Uso:
#   <nome> [opções] <args>
#
# Opções:
#   --foo=X    descrição
#
# Exit codes:
#   0  sucesso
#   1  erro lógico
#   2  erro de permissão
```

### `config.json` — parametrização sem forkar

Quando parâmetros variam entre projetos, a skill lê `config.json` opcional.
Exemplo em `create-use-case/config.json`:

```json
{
  "domains": ["AUTH", "CAD", "PED", "FIN"],
  "id_format": "UC-{domain}-{nnn}",
  "templates_dir": "docs/02-requisitos-casos-uso/"
}
```

Projeto sobrescreve sem bifurcar a skill.

## Progressive disclosure

O modelo paga o custo de contexto da `SKILL.md` na invocação e carrega
`templates/`, `references/` e `examples/` **sob demanda**. Isso significa:

- Skill enxuta no `SKILL.md` (instruções + gotchas + links)
- Conteúdo pesado em subpastas (templates longos, catálogos, exemplos)
- Modelo consulta apenas o que precisar

Anti-pattern: SKILL.md com 2000 linhas inline — todo o contexto sempre
carregado, caro.

## Versionamento e compatibilidade

- [SemVer 2.0.0](https://semver.org/) estrito
- BREAKING changes rastreadas no [CHANGELOG.md](../CHANGELOG.md)
- Rename de skill (mudança de `name:`) = BREAKING (contrato público)
- Adição de skill nova = MINOR
- Fix em skill existente sem mudar contrato = PATCH

## Decisão: onde adicionar nova skill?

Árvore de decisão:

```
Sua skill é específica de uma linguagem/ecossistema?
│
├─ SIM → language-related/<linguagem>/
│
└─ NÃO →
     │
     Sua skill é sobre provisionar/operar recurso?
     │
     ├─ SIM → platform-related/<plataforma>/
     │
     └─ NÃO →
          │
          Sua skill é sobre consumir dados de serviço externo?
          │
          ├─ SIM → data-related/<serviço>/
          │
          └─ NÃO → global/skills/<skill-name>/
```

Exemplos práticos:

| Skill proposta | Categoria | Razão |
|----------------|-----------|-------|
| `go-add-handler` | `language-related/go/` | idiomático Go |
| `ts-add-domain` | `language-related/typescript/` | scaffold TS |
| `cf-dns-add-record` | `platform-related/cloudflare-dns/` | API CF DNS |
| `pg-query-optimize` | `data-related/postgres/` | SQL + EXPLAIN |
| `d1-batch-pattern` | `data-related/d1/` | query pattern |
| `neon-create-branch` | `platform-related/neon/` | API de provisionamento |
| `cred-store` | `global/skills/` | agnóstica (qualquer provider) |
| `review-pr` | `global/skills/` ou `language-related/<ling>/` (se específica de linguagem) |

## Anti-patterns arquiteturais

### Skill duplicada em categorias diferentes

Se você sente necessidade de criar `go-review-pr` **e** `review-pr`, pare.
Há 2 opções:

1. `review-pr` agnóstica em `global/skills/` com seções por linguagem
2. `<lang>-review-pr` específica em `language-related/<lang>/`

Escolha uma. Duplicar é manutenção dupla.

### "Plataforma" virando saco de gato

Resistir à tentação de botar qualquer coisa não-linguagem em `platform-related/`.
ES, Redis, PG, Mongo são **serviços consumidos** (→ `data-related/`), não
plataformas de execução.

### Forkar skill para customizar

Projeto precisa de variação? Use `config.json`. Se não couber, abra issue
para estender a skill (parametrização) — não fork.

### Documentação inline na SKILL.md de 2000 linhas

Progressive disclosure. Mova para `references/` e linke.

### Skill que faz N coisas

Uma skill = um propósito. Se `create-use-case` também valida + lint + deploy,
está inchada. Divida.

## Camadas de enforcement

O toolkit usa múltiplas camadas para enforcar convenções:

1. **Hook `commit-msg`** (local) — rejeita commits mal-formados antes de entrar
2. **Hook `PreToolCall`** (tempo de execução) — valida antes de o Claude rodar
3. **Hook `PostToolCall`** (tempo de execução) — valida depois (ex: build gate)
4. **Skill `release-quality-gate`** (release time) — bateria de 10 checks
5. **CI workflow** (tempo de PR) — reforça tudo acima em ambiente limpo

Camadas diferentes capturam tipos diferentes de erro. Nenhuma substitui a outra.

## Ver também

- [getting-started.md](./getting-started.md) — quickstart prático
- [skills-catalog.md](./skills-catalog.md) — lista completa
- [contributing.md](./contributing.md) — convenções para adicionar skills
- [glossary.md](./glossary.md) — termos usados
