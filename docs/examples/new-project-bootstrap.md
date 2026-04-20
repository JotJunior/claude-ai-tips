# Exemplo: Bootstrap de projeto novo até primeira release

Cenário completo do zero — `git init` até tag `v0.1.0` com CHANGELOG,
commits validados, quality gate.

## Contexto do exemplo

Vamos criar um projeto fictício `my-cli` — CLI Node.js que lê arquivos
JSON. Não é CF Workers nem Web app; mostra o toolkit funcionando em
projeto "plain Node".

## Pré-requisitos

- Node.js ≥18
- git
- jq
- `claude-ai-tips` clonado em `~/Sistemas/claude-ai-tips`

## Passo 1 — Criar projeto

```bash
cd ~/projetos
mkdir my-cli && cd my-cli
git init

cat > package.json <<'EOF'
{
  "name": "my-cli",
  "version": "0.0.0",
  "description": "CLI que processa arquivos JSON",
  "type": "module",
  "bin": {
    "my-cli": "src/cli.mjs"
  },
  "scripts": {
    "test": "node --test test/*.test.mjs"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "license": "MIT"
}
EOF

mkdir src test
cat > src/cli.mjs <<'EOF'
#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const [,, filePath] = process.argv;
if (!filePath) {
  console.error('Usage: my-cli <file.json>');
  process.exit(1);
}

try {
  const data = JSON.parse(readFileSync(filePath, 'utf8'));
  console.log(JSON.stringify(data, null, 2));
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
EOF
chmod +x src/cli.mjs
```

Estado atual:

```
my-cli/
├── package.json
├── src/cli.mjs
└── test/
```

## Passo 2 — Instalar git hooks

No Claude Code, em `my-cli/`:

```
instalar git hooks neste projeto com enforce de identity 4i3n6 e commits em EN-US
```

A skill `git-hooks-install` pergunta:

1. **Enforce PT-BR rejection?** → Sim
2. **Enforce conventional format?** → Sim
3. **Enforce identity?** → Sim (nome: `4i3n6`, email: `4i3n6@pm.me`)
4. **Adicionar postinstall?** → Sim

Arquivos criados:

```
my-cli/
├── .githooks/
│   ├── commit-msg       # valida conventional + rejeita PT-BR
│   └── pre-commit       # enforce identity
├── scripts/
│   └── install-hooks.sh # postinstall
└── package.json         # + "postinstall": "sh scripts/install-hooks.sh"
```

Ativar manualmente (postinstall ainda não rodou):

```bash
sh scripts/install-hooks.sh
```

Saída:

```
configurado: core.hooksPath = .githooks
chmod +x: .githooks/commit-msg
chmod +x: .githooks/pre-commit
```

## Passo 3 — Inicializar CHANGELOG

No Claude Code:

```
criar CHANGELOG.md novo para este projeto
```

A skill `changelog-write-entry` detecta que não existe, cria:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

## Passo 4 — Configurar release manual

```
configure release manual com body minimo 20 chars e pre-1.0 mode
```

A skill `release-manual-setup` pergunta e cria:

```
my-cli/
├── scripts/
│   ├── install-hooks.sh
│   └── release.mjs          # novo: script principal
└── test/
    └── release.test.mjs     # novo: test suite
```

Adiciona em `package.json`:

```json
"scripts": {
  "test": "node --test test/*.test.mjs",
  "release": "node scripts/release.mjs"
}
```

## Passo 5 — Primeiro commit

Verificar identidade:

```bash
git config user.name       # deve ser: 4i3n6
git config user.email      # deve ser: 4i3n6@pm.me
```

Se diferente:

```bash
git config user.name 4i3n6
git config user.email 4i3n6@pm.me
```

Primeiro commit:

```bash
git add .
git commit
```

Editor abre. Digite:

```
feat: initial CLI scaffold with JSON reader

Creates my-cli binary that reads and pretty-prints JSON files. Installed
via npm link or added as bin dependency. Basic argv parsing with error
handling for missing/invalid input.

Includes git hooks (commit-msg + pre-commit) and release automation via
scripts/release.mjs with quality gate enforcing body >= 20 chars for
feat/fix commits.
```

Hook `commit-msg` valida conformidade. Hook `pre-commit` confirma identidade.

```bash
git log --oneline
# abc1234 feat: initial CLI scaffold with JSON reader
```

## Passo 6 — Adicionar feature + teste

```bash
cat > test/cli.test.mjs <<'EOF'
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';

describe('cli', () => {
  it('reads valid JSON', () => {
    writeFileSync('/tmp/test.json', '{"name":"test"}');
    const result = spawnSync('node', ['src/cli.mjs', '/tmp/test.json'], { encoding: 'utf8' });
    unlinkSync('/tmp/test.json');
    assert.equal(result.status, 0);
    assert.ok(result.stdout.includes('"name": "test"'));
  });

  it('errors on missing file', () => {
    const result = spawnSync('node', ['src/cli.mjs', '/tmp/nonexistent.json'], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.ok(result.stderr.includes('Error'));
  });
});
EOF

# Testar
node --test test/cli.test.mjs
```

Commit:

```bash
git add test/cli.test.mjs
git commit
```

Mensagem:

```
test: add CLI integration tests for JSON reader

Covers happy path (valid JSON returns pretty-printed output with exit 0)
and error path (missing file returns stderr message with exit 1).
Uses node:test built-in runner to avoid adding dependency.
```

## Passo 7 — Adicionar feature (impacta usuário)

Modificar `src/cli.mjs` para aceitar flag `--pretty`:

```bash
cat > src/cli.mjs <<'EOF'
#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const pretty = args.includes('--pretty');
const filePath = args.find(a => !a.startsWith('--'));

if (!filePath) {
  console.error('Usage: my-cli <file.json> [--pretty]');
  process.exit(1);
}

try {
  const data = JSON.parse(readFileSync(filePath, 'utf8'));
  const output = pretty ? JSON.stringify(data, null, 2) : JSON.stringify(data);
  console.log(output);
} catch (err) {
  console.error(`Error: ${err.message}`);
  process.exit(1);
}
EOF
```

Commit com body rico (porque é `feat`):

```bash
git add src/cli.mjs
git commit
```

Mensagem:

```
feat: add --pretty flag for formatted JSON output

Default output is now compact (single-line JSON) for piping into other
tools like jq. The --pretty flag enables indented multi-line output for
human reading. This aligns with Unix philosophy of machine-parsable by
default and human-readable on demand.

Breaking: compact output is now default (was pretty). Users relying on
pretty output need to add --pretty explicitly.
```

**Atenção**: o subject tem `feat:` mas o body diz "Breaking:" — isso NÃO
é detectado como breaking pelo parser. Para sinalizar breaking:

```
feat!: add --pretty flag for formatted JSON output

BREAKING CHANGE: compact output is now default (was pretty). Users
relying on pretty output need to add --pretty explicitly.
```

Ou use `BREAKING CHANGE:` no body. Ambas formas disparam bump MAJOR.

Vamos fazer **sem** ser breaking por enquanto (mais realista — `--pretty`
é adição opcional):

```
feat: add --pretty flag for formatted JSON output

Adds opt-in --pretty flag for indented multi-line output. Default is now
compact (single-line) for piping into other tools. Preserves backward
compat by accepting --pretty flag without breaking existing users who
will keep using default behavior.
```

## Passo 8 — Quality gate antes da release

```
valide prontidão para release v0.1.0
```

A skill `release-quality-gate` executa:

```
Release Quality Gate — PASSED

[1/10] working tree clean                ok
[2/10] target tag v0.1.0 available       ok
[3/10] conventional commits format       3 commits, 0 violations
[4/10] commit body quality               2 feat, 0 fix, 0 breaking — all passed
[5/10] tests                             ok (node --test passou)
[6/10] lint                              skipped (no script)
[7/10] typecheck                         skipped (no script)
[8/10] CHANGELOG entry                   [Unreleased] found
[9/10] branch                            on main
[10/10] sync with remote                 no remote configured yet

Summary:
  Detected bump:  minor (0 breaking + 2 feat + 0 fix)
  Target version: 0.1.0 (from 0.0.0)
  Ready to release.
```

## Passo 9 — Executar release

Dry-run primeiro (sem escrever):

```bash
DRY_RUN=1 npm run release
```

Saída:

```
Release v0.1.0 (minor from 0.0.0):

## [0.1.0] - 2026-04-19

### Added

- **add --pretty flag for formatted JSON output** — Adds opt-in --pretty flag for indented multi-line output. Default is now compact (single-line) for piping into other tools. Preserves backward compat by accepting --pretty flag without breaking existing users who will keep using default behavior.

### Tests

- **add CLI integration tests for JSON reader** — Covers happy path (valid JSON returns pretty-printed output with exit 0) and error path (missing file returns stderr message with exit 1). Uses node:test built-in runner to avoid adding dependency.

### Added

- **initial CLI scaffold with JSON reader** — Creates my-cli binary that reads and pretty-prints JSON files. Installed via npm link or added as bin dependency. Basic argv parsing with error handling for missing/invalid input. Includes git hooks (commit-msg + pre-commit) and release automation via scripts/release.mjs with quality gate enforcing body >= 20 chars for feat/fix commits.

Summary:
  bump:        minor
  current:     0.0.0
  next:        0.1.0
  commits:     3
  tag:         v0.1.0

(dry-run — no files modified, no commit, no tag)
```

Executar de verdade:

```bash
npm run release
```

Saída:

```
Running tests...
✔ reads valid JSON (15.3ms)
✔ errors on missing file (3.1ms)

ℹ tests 2
ℹ pass 2
...

Release v0.1.0 (minor from 0.0.0):
... (conteúdo do changelog) ...

Created commit + tag v0.1.0

To publish:
  git push origin $(git rev-parse --abbrev-ref HEAD)
  git push origin v0.1.0
```

Verificar:

```bash
git log --oneline
# xyz7890 chore(release): v0.1.0
# abc1234 feat: add --pretty flag for formatted JSON output
# def5678 test: add CLI integration tests for JSON reader
# 123abcd feat: initial CLI scaffold with JSON reader

git tag
# v0.1.0

cat CHANGELOG.md | head -30
# # Changelog
#
# All notable changes...
#
# ## [Unreleased]
#
# ## [0.1.0] - 2026-04-19
# ...
```

## Passo 10 — Push para GitHub

Criar repo no GitHub e push:

```bash
gh repo create my-cli --private --source=. --remote=origin
git push -u origin main --tags
```

Ou manualmente:

```bash
# Criar repo no browser
git remote add origin git@github.com:seu-user/my-cli.git
git push -u origin main
git push origin v0.1.0
```

Criar GitHub Release:

```bash
gh release create v0.1.0 \
  --title "v0.1.0 — initial release" \
  --notes-file <(sed -n '/^## \[0.1.0\]/,/^## \[/p' CHANGELOG.md | sed '$d')
```

## Próxima iteração

Ciclo típico:

```bash
# 1. Trabalhar em feature
# <edita arquivos>
git commit    # hook valida conventional + identity

# 2. Mais commits
# <edita mais>
git commit

# 3. Quando acumular mudanças suficientes:
npm run release    # detecta bump automaticamente
git push origin main --tags
```

## Upgrade para release-please (quando fizer sentido)

Se o projeto crescer (team, CI), migrar para release-please:

```
migre este projeto para release-please
```

A skill `release-please-setup` cria os 3 arquivos necessários. Você pode:

- **Manter** `scripts/release.mjs` para releases locais emergenciais
- **Remover** (prefira release-please dali pra frente)

Não há conflito — release-please processa commits; `release.mjs` gera
output similar. Só não rode os dois no mesmo push.

## Checklist da primeira release

- [ ] `git init` feito
- [ ] `package.json` com `version: "0.0.0"` e `name` válido
- [ ] Git hooks instalados (`.githooks/`)
- [ ] `CHANGELOG.md` criado com seção `[Unreleased]`
- [ ] `scripts/release.mjs` + `test/release.test.mjs` presentes
- [ ] Identidade configurada (`git config user.name/email`)
- [ ] Commits com body ≥20 chars em feat/fix
- [ ] Testes passam (`npm test`)
- [ ] Quality gate passa
- [ ] Working tree limpa
- [ ] Tag criada (`git tag -l`)
- [ ] CHANGELOG tem entrada `[0.1.0] - DATE`
- [ ] Pushed para remote (se aplicável)
- [ ] GitHub Release criada (se pública)

## Troubleshooting do exemplo

### "ERROR: Commit message appears to be in Portuguese"

Subject contém verbo PT-BR. Traduza:

| PT | EN |
|----|-----|
| adicionar | add |
| corrigir | fix |
| atualizar | update |
| remover | remove |
| criar | create |

### "ERROR: Commits to this repository must be authored by 4i3n6"

Você não está com a identidade correta:

```bash
git config user.name 4i3n6
git config user.email 4i3n6@pm.me
```

Ou remova o enforce:

```bash
rm .githooks/pre-commit
```

### "Tests failed. Aborting release"

Corrija os testes antes. Se quiser pular (não recomendado):

```bash
NO_TESTS=1 npm run release
```

### "Quality check failed — these commits need a body"

Amend commit com body:

```bash
git commit --amend
# edita mensagem, adiciona body de >=20 chars
```

Ou rebase interativo para commits antigos:

```bash
git rebase -i HEAD~3
# substitui "pick" por "reword" nos commits problemáticos
```

### "Working tree not clean"

Commite, stash ou descarte mudanças pendentes:

```bash
git status
git stash    # ou git add + git commit
```

## Ver também

- [credentials.md](../guides/credentials.md) — não usado neste exemplo, mas útil
  quando for publicar no npm (token npm em cred-store)
- [releases.md](../guides/releases.md) — detalhes completos do padrão manual
- [examples/release-flow.md](./release-flow.md) — outras variações
- [contributing.md](../contributing.md) — convenções ao contribuir
