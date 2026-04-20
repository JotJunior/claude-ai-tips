# Gotchas e Limitacoes

Todos os gotchas do `release.mjs` exceto os 3 criticos documentados
no SKILL.md principal.

> Voltar para: [../SKILL.md](../SKILL.md)

---

## ESM vs CommonJS

Template usa ESM (`import`/`export` com extensiao `.mjs`).

**Se projeto e CommonJS**:

```javascript
// Adaptar topo de scripts/release.mjs
const { spawnSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
```

**Ou**: manter `.mjs` (ESM) mesmo em projeto CJS — Node.js aceita.

---

## git log entre tags

Primeiro release (sem tags ainda) usa `--max-count=1000` como limite:

```javascript
const logRange = currentTag ? `${currentTag}..HEAD` : '--max-count=1000';
```

**Limitacao**: Projeto com mais de 1000 commits sem tag历史上的 precisa ajustar.

---

## Commits de merge

Script usa `--no-merges` para ignorar commits de merge:

```javascript
const raw = git(['log', logRange, format, '--no-merges']);
```

**Motivo**: GitHub PR merge commits nao seguem conventional commits
e poluiriam o changelog.

---

## Tag prefix

Default: `v0.1.0`. Para monorepo ou customizacao:

```javascript
const TAG_PREFIX = 'my-package-v';  // resulta em my-package-v0.1.0
```

---

## Timestamps em CHANGELOG

Sempre UTC. Script usa:

```javascript
new Date().toISOString().slice(0, 10)  // YYYY-MM-DD
```

**Nao usar timezone local** — resultaria em datas diferentes
dependendo de onde o release e executado.

---

## Amend vs new commit

Default: criar novo commit `chore(release): v0.1.0`.

**Para amend** (menos ruido no log):
```bash
AMEND=1 npm run release
```

**Risco**: amend sobrescreve autor se config git mudou.
Commit original perde creditagem original.

---

## Signed commits/tags

Se projeto exige `gpg.sign`/`tag.gpgSign`, adaptar:

```javascript
// Criar tag signed
git(['tag', '-a', tagName, '-m', message, '-s']);

// Criar commit signed
git(['commit', '-S', '-m', commitMsg]);
```

---

## Limite de 1000 commits

Script le no maximo 1000 commits quando nao ha tag anterior.
Projetos maiores precisam ajustar manualmente:

```javascript
const logRange = '--max-count=5000';  // aumentar se necessario
```

---

## Commits sem type sao ignorados

Commits whose subject does not match the conventional commit regex
(type === null) sao ignorados no changelog. Nao bloqueiam release,
mas tambem nao aparecem no CHANGELOG.

---

## Exit code em dry run

Dry run (`DRY_RUN=1`) pode falhar com exit code 1 se quality gate
falhar — isso e intencional. Nao cria tag/commit, mas informa
problemas nos commits.

---

## AUTO_PUSH=false e push manual

Se `AUTO_PUSH=false` (default), fazer push manual:

```bash
npm run release
git push origin main
git push origin v0.1.0  # ou: git push --tags
```

Fazer push da tag SEPARADAMENTE do branch e APOSTA release ter
sucesso completo antes de fazer push.

---

## FORCE_1_0 para ir a 1.0.0

Para forcar versao `1.0.0` (pulando 0.x):

```bash
# Opcao 1: editar package.json manualmente antes
# Opcao 2: nao ha flag FORCE_1_0 — editar package.json
```

O script nao tem flag `FORCE_1_0`. Use:

```bash
jq '.version = "0.10.0"' package.json > /tmp/pkg.json
mv /tmp/pkg.json package.json
npm run release  # agora bump minor vai para 0.11.0
# Ou:
jq '.version = "1.0.0"' package.json > /tmp/pkg.json
mv /tmp/pkg.json package.json
# Depois: git commit -m "chore: set 1.0.0"
npm run release  # bump patch ou minor de 1.0.0
```
