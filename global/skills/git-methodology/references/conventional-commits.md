# Conventional Commits — referencia

Especificacao formal: [conventionalcommits.org/v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Formato

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

### Exemplos

```
feat(auth): add OAuth2 PKCE flow

Replaces the deprecated implicit flow. PKCE eliminates the need for
client secrets in public clients (browser/mobile) and is required by
Anthropic's OAuth 2.1 specification.

Refs: #42
```

```
fix!: remove legacy /v1 endpoint

BREAKING CHANGE: Clients must migrate to /v2. The /v1 endpoint was
deprecated in v2.3.0 (2025-08) and removed now to reduce maintenance.
```

```
refactor(store): extract atomic write helper

No behavior change. Consolidates the tmp-file+rename pattern used in
saveAuth, saveConfig, and saveApiReference into writeJsonAtomic().
```

## Types suportados

| Type | Uso | Bump SemVer* |
|------|-----|--------------|
| `feat` | Nova funcionalidade | **MINOR** |
| `fix` | Correcao de bug | **PATCH** |
| `refactor` | Mudanca sem afetar comportamento externo | PATCH |
| `perf` | Otimizacao de performance | PATCH |
| `test` | Adicao/ajuste de testes | nenhum |
| `docs` | Documentacao apenas | nenhum |
| `style` | Formatacao, whitespace | nenhum |
| `chore` | Maintenance geral (deps, lint, config) | nenhum |
| `ci` | Mudanca em workflow CI/CD | nenhum |
| `build` | Mudanca em build system, scripts | nenhum |
| `revert` | Reverte commit anterior | depende |

*Em pre-1.0 (`0.x.y`), alguns projetos tratam `feat` como **patch** (minor
so muda quando projeto estabiliza em 1.0+). Outros projetos (ex: clw-auth)
tratam `feat` em 0.x como bump de minor. Convencao varia — documentar no
projeto.

### BREAKING CHANGE

Sinalizado de **duas formas equivalentes**:

1. **Bang no header**: `feat!:` ou `feat(api)!: nova versao quebrando v1`
2. **Footer**: `BREAKING CHANGE: descricao da quebra`

Ambos dispararam bump **MAJOR** (exceto 0.x onde pode ser interpretado
como MINOR por alguns projetos).

## Scope

Opcional, entre parenteses. Convencoes comuns:

- **Modulo/pacote**: `feat(auth):`, `fix(db):`
- **Subprojeto** (monorepo): `feat(web):`, `fix(api):`
- **Dominio de negocio**: `feat(billing):`, `fix(checkout):`
- **Kebab-case**: `fix(rate-limit):`, `feat(payment-gateway):`

Scope NAO deve conter:
- Nome do arquivo (`fix(auth.mjs):` ❌)
- Verbo (`feat(add-user):` ❌, use `feat(user):` ✅)
- Multiplos scopes em um commit — dividir em commits menores

## Description (primeira linha)

- **Imperativo presente**: "add", "fix", "remove" (nao "added", "fixes")
- **Lowercase**: "add new endpoint" (nao "Add new endpoint")
- **Sem ponto final**: "fix null check" (nao "fix null check.")
- **Maximo 72 caracteres** (alguns projetos permitem 100)
- **Em ingles** (EN-US) — mesmo em projetos com docs em PT-BR

### Padrao observado nos projetos de referencia

| Projeto | Regra |
|---------|-------|
| md2pdf | EN-US enforced via `.githooks/commit-msg` (rejeita PT-BR verbos) |
| clw-auth | EN-US por convencao em AGENTS.md |
| split-ai | EN-US, max 100 chars, scope kebab-case via commitlint |

## Body (opcional, mas recomendado)

Separado do header por linha em branco. Deve responder:

1. **O que** mudou (brevemente — o que nao esta obvio pelo header)
2. **Por que** mudou (sempre — motivacao, contexto)
3. **Como** foi feito (quando nao-trivial — abordagem escolhida)
4. **Impacto** (quando aplicavel — o que o usuario vai notar)

Nao explicar o HOW linha-por-linha — isso e responsabilidade do code
review, nao do commit. Foco e no POR QUE.

### Quando body e obrigatorio

Nos projetos de referencia:

- **`feat`**: sempre (nova funcionalidade merece explicacao)
- **`fix`**: sempre (qual bug? qual era o sintoma? qual foi root cause?)
- **BREAKING CHANGE**: sempre + descrever migracao

Opcional em `chore`, `docs`, `test`, `refactor` (quando nao-trivial).

### Qualidade minima

`clw-auth/scripts/release.mjs` enforca `MIN_BODY_LENGTH = 20` chars.
Isso evita bodies vazios como "fix". Body de 20 chars forca pelo menos
uma frase explicativa.

## Footer

Formato `Key: Value`, um por linha no final. Convencoes:

| Footer | Uso |
|--------|-----|
| `BREAKING CHANGE:` | Descricao de quebra |
| `Refs: #123` | Referencia a issue (sem fechar) |
| `Closes: #123` | Referencia + fecha issue |
| `Co-authored-by: Name <email>` | Pair/Mob programming |
| `Signed-off-by: Name <email>` | DCO sign-off |
| `Reviewed-by: Name <email>` | Code review credit |

## Verbos proibidos em EN-US hooks

Hook `commit-msg` do md2pdf rejeita estes (tipicos em PT-BR):

```
adicionar, remover, corrigir, atualizar, criar, extrair, implementar,
refatorar, substituir, melhorar, resolver, configurar, ajustar,
desativar, ativar, evitar, permitir, forcar, fixar
```

Equivalentes EN-US: `add`, `remove`, `fix`, `update`, `create`, `extract`,
`implement`, `refactor`, `replace`, `improve`, `resolve`, `configure`,
`adjust`, `disable`, `enable`, `avoid`, `allow`, `force`, `pin`.

## Parseando commits (Node.js)

Pattern usado em `clw-auth/scripts/release.mjs`:

```javascript
function parseCommit({ hash, subject, body }) {
  const match = subject.match(/^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$/);
  if (!match) return { hash, type: null, ... };

  const [, type, , scope, bang, description] = match;
  const breaking = bang === '!' || /BREAKING[- ]CHANGE/i.test(body);
  return { hash, type, scope: scope ?? null, breaking, description, body };
}
```

Chave:
- Regex `^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$` cobre todos os casos validos
- Breaking detectado via bang OU via BREAKING CHANGE no body
- Subject nao-conventional retorna `type: null` (nao quebra o parse)

## Enforcement

Camadas de enforcement possiveis:

1. **commit-msg hook local** — rejeita antes do commit (mais cedo)
2. **commitlint pre-push** — valida apos commit mas antes de push
3. **CI check** — valida em PR (tardio mas visivel)
4. **release-please/release.mjs** — rejeita release se commits nao-conformes

Recomendacao: camada 1 + 4 (commit-msg + release gate) — bloqueia entrada
e saida. Camadas 2-3 sao redundantes mas ajudam em times grandes.

## Referencias

- [conventionalcommits.org](https://www.conventionalcommits.org/)
- [commitlint.js.org](https://commitlint.js.org/) — valida commit-msg via config
- [cz-cli](https://github.com/commitizen/cz-cli) — prompt interativo pra escrever commits
- [Angular commit format](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) — origem do pattern
