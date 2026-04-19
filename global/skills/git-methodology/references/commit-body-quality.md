# Commit Body Quality — referencia

Extraido de `clw-auth/scripts/release.mjs` e observacao de padroes em
md2pdf/clw-auth. Define quando body e obrigatorio, tamanho minimo, e
criterios de qualidade.

## Regra principal

**Body obrigatorio para commits que afetam usuarios.** Qual commit afeta
usuario?

| Type | Body obrigatorio? | Justificativa |
|------|-------------------|---------------|
| `feat` | **SIM** | Nova funcionalidade merece explicacao — o que usuario ganhou |
| `fix` | **SIM** | Qual bug? qual sintoma? qual root cause? |
| `perf` | recomendado | Qual impacto mensuravel? |
| `refactor` | opcional | Sem impacto externo — body opcional |
| `test` | opcional | Internal; body so quando nao-obvio |
| `docs` | opcional | Mudanca de doc geralmente eh auto-explicativa |
| `chore` | opcional | Ajuste operacional — body so se nao-trivial |
| `style` | nunca | Pura formatacao |
| `build`, `ci` | opcional | Body se afeta deploy/workflow |
| `BREAKING CHANGE` | **SEMPRE** | Migration path obrigatorio |

## Tamanho minimo

`clw-auth/scripts/release.mjs` enforca:

```javascript
const MIN_BODY_LENGTH = 20;
const BODY_REQUIRED_TYPES = new Set(['feat', 'fix']);

function checkQuality(commits) {
  return commits.filter((c) => {
    if (!c.type) return false;
    if (c.breaking) return !c.body || c.body.length < MIN_BODY_LENGTH;
    return BODY_REQUIRED_TYPES.has(c.type) && (!c.body || c.body.length < MIN_BODY_LENGTH);
  });
}
```

20 chars e baixo o suficiente para ser realistico, mas alto o suficiente
para forcar pelo menos uma frase explicativa.

Exemplo de body **invalido** (<20 chars):
```
fix: null check

short body
```

Exemplo de body **valido** (>=20 chars):
```
fix: prevent null deref in auth handler

Empty OAuth state led to 500 when user cleared cookies.
```

## Estrutura recomendada de body

Nao rigida — adapte ao contexto. Elementos tipicos:

```
<type>(<scope>): <description>

<WHAT> — <PORQUE>

<HOW quando nao-obvio>

<IMPACT para usuario>
```

### Exemplo expandido (clw-auth)

```
feat(opencode): inject CC billing fingerprint and Stainless identity headers

Injects x-anthropic-billing-header (SHA256 fingerprint per request,
matching CC computeFingerprint logic) and Stainless SDK identity headers
(x-app, x-claude-code-session-id, x-stainless-*) into every API request.
Updates beta headers to the full 8-header Claude Code set and forces
userAgent to derive from ccVersion. Fixes requests routing to Extra Usage
instead of subscription billing.
```

Elementos identificaveis:
- **WHAT**: inject fingerprint + identity headers
- **PORQUE**: fix requests routing to Extra Usage instead of subscription billing
- **HOW**: matching CC computeFingerprint logic, 8-header set, derive from
  ccVersion
- **IMPACT**: subscription billing (user vai notar em bill)

## Anti-patterns

### Body que apenas reformula o subject

```
feat(auth): add OAuth flow

Adds OAuth flow.
```

Body nao acrescenta informacao. **Ruim.**

### Body com gerundio explicando o diff

```
fix: null check

Adding null check on line 42 of auth.mjs.
```

Explica o HOW linha-por-linha. O diff do commit ja faz isso. **Ruim.**

### Body com "fixes #123" sozinho

```
fix: fix auth

Fixes #123
```

Referencia issue sem explicar. Se issue desaparece, contexto sumiu.
**Incluir o contexto da issue no body, usar "Refs: #123" como adicional.**

### Body que inclui futuro

```
feat: add login

This is a feature for adding login. Next release we plan to add logout
and password reset.
```

Commit descreve o presente, nao o futuro. Roadmap vai em outro lugar.
**Ruim.**

### Body com copy-paste de chat com IA

```
fix: update code

I've updated the code to fix the issue you mentioned.
```

Texto gerado sem eh impessoal e vazio. Mesmo quando escrito por IA,
deve soar humano e especifico. **Revisar antes de commitar.**

## Good patterns

### Body com contexto de debugging

```
fix(cron): harden scheduled OAuth maintenance

Pins the installed cron entry to the active Node executable so macOS
cron can actually run `clw-auth` outside an interactive shell. Expands
the OAuth refresh window to cover the full 6-hour cron cadence,
replaces stale-entry reuse with in-place cron updates, and makes
`cron-status` report the latest real run plus concrete health issues
from the current execution context.
```

Inclui:
- **Sintoma do bug** (cron nao rodava fora de shell interativo)
- **Causa raiz** (entry apontava para Node em PATH especifico)
- **Fix** (pin ao Node executavel ativo)
- **Impacto adicional** (cron-status agora reporta saude real)

### Body explicando trade-off

```
refactor(auth): replace in-memory cache with fs-backed store

Previous implementation lost tokens on process restart, forcing re-auth
on every spawn. Moving to fs-backed store with atomic writes preserves
auth across restarts. Trade-off: slower than in-memory (~5ms extra per
read) but acceptable — auth check happens once per session.
```

Explica por que mudou E trade-off conhecido.

### Body referenciando especificacao

```
feat(headers): add oauth-2025-04-20 to default beta headers

Without this header Anthropic returns 401 'OAuth authentication is
currently not supported' for every API call even with a valid bearer
token. Confirmed by inspecting the working reference plugin.
```

Ancorar em comportamento observado (API retorna 401) + fonte (reference
plugin).

## Quality gate em script

Pattern do `clw-auth/scripts/release.mjs`:

```javascript
function failQuality(failing) {
  const lines = [
    '',
    'Quality check failed — these commits need a body before releasing:\n',
  ];

  for (const c of failing) {
    const reason = c.breaking
      ? 'breaking changes require a body description'
      : `${c.type} commits require a body description`;
    lines.push(`  ${c.hash.slice(0, 7)}  ${c.type}${c.scope ? `(${c.scope})` : ''}${c.breaking ? '!' : ''}: ${c.description}`);
    lines.push(`           ↑ ${reason} (>= ${MIN_BODY_LENGTH} chars)\n`);
  }

  lines.push('How to fix:');
  lines.push('  git commit --amend          amend the last commit');
  lines.push('  git rebase -i <hash>^       edit an older commit body');
  lines.push('');

  throw new Error(lines.join('\n'));
}
```

Output claro: lista commits com problema, motivo, e comandos para consertar.

## Quando abrir excecao

Alguns commits legitimamente nao precisam de body:

- `fix: typo in README` — obvio
- `chore: bump deps` — lockfile diff e auto-explicativo
- `test: add test for null case` — nome do teste explica

Regra de bolso: se o LEITOR DO CHANGELOG em 6 meses nao precisa do body
para entender o que mudou, body eh dispensavel. Se precisaria, body e
obrigatorio.

## Auxilio interativo

Para desenvolvedores escreverem bodies melhores:

```bash
# Rascunho via editor
git commit                    # abre editor, nao so -m

# Usar template
git config commit.template .gitmessage
```

Template `.gitmessage`:

```
<type>(<scope>): <short description max 72 chars>

# What changed?


# Why?


# Impact?


# Refs: #
```

Linhas com `#` sao removidas pelo git antes do commit.

## Em resumo

1. `feat` e `fix` sempre tem body
2. Breaking changes sempre tem body
3. Body minimo 20 chars
4. Body explica WHAT + WHY (+ HOW + IMPACT quando nao-obvio)
5. Body nao reformula subject
6. Body nao explica diff linha-por-linha
7. Referenciar issue como Refs: footer, nao como unico contexto
