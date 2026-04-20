# Release Script Walkthrough

Explicacao detalhada do `scripts/release.mjs` — cada funcao, fluxo de execucao e exit codes.

> Voltar para: [../SKILL.md](../SKILL.md)

---

## Visao geral do fluxo

```
main() 
  └─> ensureCleanWorkingTree()
  └─> loadPackageJson()
  └─> latestTag()
  └─> readCommits(logRange)
  └─> parseCommit()        x N
  └─> checkQuality()        x N
  └─> failQuality()         (se falhar)
  └─> runTests()
  └─> detectBumpType()
  └─> bump()
  └─> groupCommits()
  └─> updateChangelog()
  └─> updatePackageVersion()
  └─> git commit + git tag
  └─> (opcional) git push
```

---

## Funcao: `git(args, opts)`

Wrappers `spawnSync` para comandos git. Throw em qualquer erro.

```javascript
function git(args, opts = {}) {
  const result = spawnSync('git', args, { cwd: ROOT, encoding: 'utf8', ...opts });
  if (result.status !== 0) throw new Error(`git ${args.join(' ')} failed:\n${result.stderr}`);
  return result.stdout.trim();
}
```

Todas as funcoes git usam este wrapper. Erros lancam excecao com mensagem stderr.

---

## Funcao: `latestTag()`

Retorna a tag mais recente ou `null` se nao houver tags.

```javascript
function latestTag() {
  try {
    return git(['describe', '--tags', '--abbrev=0']);
  } catch {
    return null;
  }
}
```

---

## Funcao: `readCommits(logRange)`

Le commits do git log entre `logRange` (ex: `v0.1.0..HEAD` ou `--max-count=1000`).

Formato do git log: `%H%n%s%n%b%n{COMMIT_SEP}` — hash, subject, body, separator.

```javascript
function readCommits(logRange) {
  const format = `--format=%H%n%s%n%b%n${COMMIT_SEP}`;
  const raw = git(['log', logRange, format, '--no-merges']);
  // ...
}
```

**Nota**: `--no-merges` ignora commits de merge (GitHub PR merge nao sao conventional).

Retorna array de `{ hash, subject, body }`.

---

## Funcao: `parseCommit({ hash, subject, body })`

Parseia uma linha subject conventional commit via regex.

Regex: `^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$`

| Campo | Exemplo | Extraido |
|-------|---------|----------|
| type | `feat(cli):` | `feat` |
| scope | `feat(cli):` | `cli` |
| bang | `feat!:` | `!` |
| description | `feat: add x` | `add x` |
| breaking | body contem `BREAKING CHANGE:` | `true` |

```javascript
function parseCommit({ hash, subject, body }) {
  const match = subject.match(/^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$/);
  if (!match) {
    return { hash, type: null, scope: null, breaking: false, description: subject, body };
  }
  const [, type, , scope, bang, description] = match;
  const breaking = bang === '!' || /BREAKING[- ]CHANGE/i.test(body);
  return { hash, type, scope: scope ?? null, breaking, description, body };
}
```

---

## Funcao: `detectBumpType(commits)`

Detecta tipo de bump olhando todos os commits:

- **major**: qualquer commit breaking (`!:` ou `BREAKING CHANGE:`)
- **minor**: qualquer `feat` (sem breaking)
- **patch**: tudo mais (`fix`, `chore`, etc.)

```javascript
function detectBumpType(commits) {
  let hasBreaking = false;
  let hasFeat    = false;
  for (const c of commits) {
    if (c.breaking) hasBreaking = true;
    if (c.type === 'feat') hasFeat = true;
  }
  if (hasBreaking) return 'major';
  if (hasFeat)    return 'minor';
  return 'patch';
}
```

**Precedencia**: major > minor > patch. Se tiver feat e breaking, retorna major.

---

## Funcao: `bump(version, type)`

Aplica bump na versao. Logica especial para pre-1.0:

```javascript
function bump(version, type) {
  const pre = version.major === 0;
  if (type === 'major') return pre && PRE_1_0_MAJOR_AS_MINOR
    ? { major: 0, minor: version.minor + 1, patch: 0 }
    : { major: version.major + 1, minor: 0, patch: 0 };
  if (type === 'minor') return { major: version.major, minor: version.minor + 1, patch: 0 };
  return { major: version.major, minor: version.minor, patch: version.patch + 1 };
}
```

| Entrada | Tipo | Saida |
|---------|------|-------|
| `0.9.5` | patch | `0.9.6` |
| `0.9.5` | minor | `0.10.0` |
| `0.9.5` | major | `0.10.0` (com `PRE_1_0_MAJOR_AS_MINOR=true`) |
| `1.5.3` | major | `2.0.0` |

---

## Funcao: `groupCommits(commits)`

Agrupa commits em 4 buckets:

```javascript
function groupCommits(commits) {
  const groups = { breaking: [], feat: [], fix: [], chore: [] };
  for (const c of commits) {
    if (c.breaking)                                        { groups.breaking.push(entry); continue; }
    if (c.type === 'feat')                                 { groups.feat.push(entry); continue; }
    if (c.type === 'fix')                                  { groups.fix.push(entry); continue; }
    if (c.type && c.type !== 'feat' && c.type !== 'fix')   { groups.chore.push(entry); continue; }
  }
  return groups;
}
```

Commits sem tipo conventional (type === null) sao ignorados.

---

## Funcao: `buildEntry(version, groups)`

Gera bloco de CHANGELOG em formato Keep a Changelog 1.1.0:

```markdown
## [1.2.0] - 2026-04-19

### Breaking Changes

- **Brief description** — rich body.

### Added

- **New feature** — explanation.

### Fixed

- **Bug fix** — context.

### Changed

- **Refactor** — impact.
```

Secoes vazias sao omitidas. Ordem fixa: Breaking > Added > Fixed > Changed.

---

## Funcao: `updateChangelog(version, groups)`

Insere entrada no CHANGELOG.md:

1. Le arquivo existente (ou cria estrutura padrao se nao existir)
2. Procura `## [Unreleased]` e insere entrada depois dele
3. Se nao houver `## [Unreleased]`, appenda no final

```javascript
const unreleasedMatch = existing.match(/^## \[Unreleased\]/m);
const newContent = unreleasedMatch
  ? existing.replace(/^## \[Unreleased\]\s*\n/m, `## [Unreleased]\n\n${entry}\n`)
  : existing + '\n' + entry + '\n';
```

Timestamp sempre UTC: `new Date().toISOString().slice(0, 10)`.

---

## Exit codes

| Situacao | Exit code | Motivo |
|----------|-----------|--------|
| Sucesso | 0 | Release criado com tag + commit |
| Dry run | 0 | Nenhuma modificacao, apenasmostra o que faria |
| Erro git | 1 | git status != 0, commit failed, etc. |
| Tests fail | 1 | `npm test` retornou status != 0 |
| Quality gate fail | 1 | Commits sem body requerido |
| Nothing to release | 1 | Nenhum commit desde ultima tag |

---

## Parametros configuraveis (topo do script)

| Parametro | Default | Descricao |
|-----------|---------|-----------|
| `BODY_REQUIRED_TYPES` | `Set(['feat', 'fix'])` | Tipos que requerem body |
| `MIN_BODY_LENGTH` | `20` | Tamanho minimo do body em chars |
| `PRE_1_0_MAJOR_AS_MINOR` | `true` | major bump em 0.x vira minor |
| `RUN_TESTS_BEFORE` | `true` | Rodar npm test antes do release |
| `AUTO_PUSH` | `false` | Push automatico apos release |
| `TAG_PREFIX` | `'v'` | Prefixoda tag (ex: `v0.1.0`) |
| `COMMIT_SEP` | `'---COMMIT-END---'` | Separador de blocos no git log |
