# Quality Gate — Integration Guide

O quality gate do `release.mjs` executa 4 validacoes em sequencia antes
de criar qualquer tag ou commit de release. Falha em qualquer uma aborta
o processo.

> Voltar para: [../SKILL.md](../SKILL.md)

---

## Visao geral: ordem de execucao

```
1. ensureCleanWorkingTree()   → working tree limpa
2. checkQuality() + failQuality() → conventional + body length
3. runTests()                 → npm test (se habilitado)
4. (continua para release)
```

Se qualquer gate falhar, script termina com `process.exit(1)`.

---

## Gate 1: Clean Working Tree

```javascript
function ensureCleanWorkingTree() {
  const status = git(['status', '--porcelain']);
  if (status.length > 0) {
    throw new Error('Working tree not clean. Commit or stash changes before releasing.');
  }
}
```

**Executado primeiro** para evitar que mudancas nao-committadas sejam
incluidas no release.

**Falhas comuns**:
- Arquivos modificados mas nao commitados
- Arquivos em staging
- Build artifacts ou arquivos gerados

**Como resolver**:
```bash
git add . && git commit -m "chore: wip"  # ou
git stash
```

---

## Gate 2: Conventional Commits + Body Length

Duas verificacoes em `checkQuality(commits)`:

### 2a: Commits sao conventional

Regex: `^([a-z]+)(\(([^)]+)\))?(!)?: .+$`

Commits **nao-conformes** (type === null) nao bloqueiam — sao listados
como WARN. Projetos legacy tem historico misto.

### 2b: Body length para feat/fix/breaking

```javascript
function checkQuality(commits) {
  return commits.filter((c) => {
    if (!c.type) return false;
    if (c.breaking) return !c.body || c.body.length < MIN_BODY_LENGTH;
    return BODY_REQUIRED_TYPES.has(c.type) && (!c.body || c.body.length < MIN_BODY_LENGTH);
  });
}
```

**Tipos que requerem body**: `feat`, `fix` (default, configuravel).

**Breaking changes**: SEMPRE requerem body, independente do tipo.

**Falhas comuns**:

| Commit | Motivo da falha |
|--------|-----------------|
| `feat: add button` | body ausente |
| `fix: null check` | body < 20 chars |
| `feat!: remove API` | breaking sem body |
| `refactor!: break compat` | breaking sem body |

**Como resolver**:
```bash
# Ultimo commit
git commit --amend  # adicionar body interativamente

# Commit mais antigo
git rebase -i <hash>^
# No editor: trocar 'pick' por 'reword' para editar
```

Output de erro inclui hash curto (7 chars) e descricao para identificar.

---

## Gate 3: Tests Pass

```javascript
function runTests() {
  if (NO_TESTS || !RUN_TESTS_BEFORE) return;
  console.log('Running tests...');
  const result = spawnSync('npm', ['test'], { cwd: ROOT, stdio: 'inherit' });
  if (result.status !== 0) throw new Error('Tests failed. Aborting release.');
}
```

**Executado APOS quality gate de commits**, ANTES de criar tag.

**Pular este gate**: `NO_TESTS=1 npm run release`

**Configuravel** via `RUN_TESTS_BEFORE` no topo do script.

**Falhas comuns**:
- Testes quebrados no main/master
- Testes que dependem de estado externo (DB, API mock)
- Testes com timeout em CI lento

---

## Gate 4: Tag + Commit Creation

Nao ha validacao formal aqui — se o script chegou ate aqui,
working tree esta limpa, quality gates passaram e tests passaram.

O script entao:
1. Atualiza `package.json` version
2. Adiciona `package.json` + `CHANGELOG.md` ao staging
3. Cria commit `chore(release): vX.Y.Z`
4. Cria tag anotada `vX.Y.Z`

---

## Relacao com `release-quality-gate`

O skill `release-quality-gate` e um validador **isolado** que pode ser
usado independentemente do script de release. Ele executa as mesmas
validacoes (conventional commits + body length) sem criar release.

Use quando:
- Quer validar commits antes de fazer release manualmente
- Quer integrar com CI externa
- Nao quer usar o script completo de release

**Diferenca**: `release-quality-gate` NAO cria tag, commit ou atualiza
CHANGELOG. E apenas leitura.

---

## Integração com CI

Para rodar quality gate em CI sem criar release:

```bash
# CI: validar commits antes de merge
npm test
node scripts/release.mjs --validate-only  # se suportado
```

Ou use `release-quality-gate` skill para integracao dedicada.
REFSKILLEOF