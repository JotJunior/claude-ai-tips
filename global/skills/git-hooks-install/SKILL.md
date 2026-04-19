---
name: git-hooks-install
description: |
  Use quando o usuario precisa instalar hooks git customizados em um
  projeto — commit-msg (valida conventional commits e/ou rejeita idioma
  errado) e pre-commit (valida identidade do autor, regras estaticas).
  Tambem quando mencionar "instalar git hooks", "setup commit-msg",
  "pre-commit hook", "commit validation", "enforce en-us commits",
  "enforce author identity". Usa core.hooksPath para apontar para
  .githooks/ versionado (hooks ficam no repo, todos contribuidores
  recebem). NAO use para hooks de CI (use GitHub Actions).
argument-hint: "[--commit-msg-lang=en|pt] [--identity=<name>:<email>] [--no-postinstall]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Skill: Git Hooks Install

Instala hooks git customizados em projeto, seguindo padrao do `md2pdf`:

- `.githooks/` versionado no repo (hooks compartilhados por contribuidores)
- `git config core.hooksPath .githooks` aponta git para a pasta
- Postinstall opcional via `scripts/install-hooks.mjs` configura
  automaticamente apos `npm install`

## Hooks disponiveis

| Hook | Momento | Funcao |
|------|---------|--------|
| `commit-msg` | Apos escrever msg, antes de commitar | Valida formato conventional commits; opcional: rejeita PT-BR |
| `pre-commit` | Antes de commitar (apos staging) | Enforca identidade do autor (user.name + user.email) |

## Pre-requisitos

- Repositorio git inicializado (`.git/`)
- `package.json` (opcional — apenas se usar postinstall)
- Decisao: commits em EN-US ou permitir qualquer idioma?

## Fluxo

### Etapa 1: detectar contexto

```bash
test -d .git || { echo "nao eh repo git"; exit 1; }
git config core.hooksPath || echo "default .git/hooks"
test -f package.json && HAS_PKG=1 || HAS_PKG=0
```

### Etapa 2: perguntar preferencias

Via `AskUserQuestion`:

1. **Idioma dos commits**: EN-US enforced (rejeita verbos PT-BR) ou
   qualquer idioma?
2. **Enforce identidade**: sim (precisa `user.name` e `user.email`
   exatos) ou nao?
3. Se sim:
   - `user.name` esperado (ex: `4i3n6`)
   - `user.email` esperado (ex: `4i3n6@pm.me`)
4. **Postinstall auto-config**: se `HAS_PKG=1`, adicionar
   `"postinstall": "node scripts/install-hooks.mjs"` ao package.json?
5. **Validar conventional commits format**: sim (regex obrigatorio)
   ou nao?

### Etapa 3: copiar templates

```bash
mkdir -p .githooks
cp templates/commit-msg .githooks/commit-msg
cp templates/pre-commit .githooks/pre-commit
chmod +x .githooks/commit-msg .githooks/pre-commit
```

### Etapa 4: customizar templates

No `commit-msg`, descomentar/ativar pecas conforme preferencias:

- Bloco `PTBR_PATTERN` ativo -> enforca EN-US
- Bloco `CONVENTIONAL_PATTERN` ativo -> enforca formato conventional
- Ambos opcionais (podem coexistir)

No `pre-commit`, preencher:

```sh
REQUIRED_NAME="4i3n6"
REQUIRED_EMAIL="4i3n6@pm.me"
```

### Etapa 5: configurar core.hooksPath

```bash
git config core.hooksPath .githooks
```

Isso **eh per-clone** — cada contribuidor precisa configurar. Para
evitar passo manual, usar postinstall (etapa 6).

### Etapa 6: postinstall (opcional)

Se `HAS_PKG=1` e usuario confirmou:

```bash
mkdir -p scripts
cp templates/install-hooks.sh scripts/install-hooks.sh
chmod +x scripts/install-hooks.sh
```

Adicionar ao `package.json`:

```json
"scripts": {
  "postinstall": "sh scripts/install-hooks.sh"
}
```

`install-hooks.sh` faz:
- `git config core.hooksPath .githooks`
- Valida que hooks tem `+x` (caso `git clone` em sistema que nao
  preserva permissions)
- Exit 0 sempre (nao quebra `npm install`)

### Etapa 7: commit inicial

```bash
git add .githooks/ scripts/install-hooks.sh package.json
git commit -m "chore(git): add custom commit-msg and pre-commit hooks

Enforces <criterios customizados escolhidos pelo usuario>."
```

Atencao: o primeiro commit depois da skill passa pelos proprios hooks
recem-instalados. Se o usuario nao tiver a identidade correta, o
pre-commit falha. Skill avisa antes de commitar.

### Etapa 8: validar

```bash
# Teste commit-msg
echo "test: valid conventional commit" | .githooks/commit-msg /dev/stdin

# Teste pre-commit
.githooks/pre-commit
```

### Etapa 9: relatorio

```
hooks git instalados:
  .githooks/commit-msg    (EN-US enforcement + conventional format)
  .githooks/pre-commit    (identity check: 4i3n6 <4i3n6@pm.me>)
  scripts/install-hooks.sh (postinstall setup)

core.hooksPath:           .githooks (per-clone)
postinstall:              habilitado (automatico apos npm install)

testes:
  commit-msg            - rejeita 'feat: adicionar x' (PT-BR)
  commit-msg            - aceita 'feat: add x'
  pre-commit            - requer user.name=4i3n6

contribuidores novos precisam:
  npm install            (dispara postinstall)
  OU
  git config core.hooksPath .githooks
```

## Hooks fornecidos

### commit-msg

Bloco 1 — rejeita PT-BR (padrao md2pdf):

```sh
PTBR_PATTERN="(adicionar|corrigir|atualizar|criar|implementar|...)"
if echo "$SUBJECT" | grep -qiE "\\b$PTBR_PATTERN\\b"; then
    echo "ERROR: Commit message in Portuguese. Use English."
    exit 1
fi
```

Bloco 2 — valida conventional format (opcional):

```sh
if ! echo "$FIRST_LINE" | grep -qE "^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\\([^)]+\\))?!?: .+$"; then
    echo "ERROR: Commit doesn't follow Conventional Commits."
    exit 1
fi
```

### pre-commit

Enforca identidade (padrao md2pdf):

```sh
REQUIRED_NAME="4i3n6"
REQUIRED_EMAIL="4i3n6@pm.me"

if [ "$AUTHOR_NAME" != "$REQUIRED_NAME" ] || [ "$AUTHOR_EMAIL" != "$REQUIRED_EMAIL" ]; then
    echo "ERROR: Commits must be authored by $REQUIRED_NAME <$REQUIRED_EMAIL>"
    exit 1
fi
```

## Gotchas

### Hooks em `.git/hooks/` NAO sao versionados

Por design do git, `.git/hooks/` eh local. Usar `core.hooksPath` +
diretorio versionado eh o caminho para compartilhar hooks entre
contribuidores.

### `core.hooksPath` eh per-clone

`git config core.hooksPath .githooks` escreve em `.git/config` local.
Cada clone precisa setar (manualmente ou via postinstall).

### postinstall com `npm ci`

`npm ci` tambem roda postinstall. Em CI isso eh overhead minimo, mas
se `install-hooks.sh` falha, `npm ci` retorna nao-zero — quebra CI.
Garantir `exit 0` no fim de `install-hooks.sh` para nunca quebrar.

### Enforcement de identidade em equipe

Se projeto tem multiplos contribuidores, cada um tem `user.name` e
`user.email` proprios. Enforce rigido (bloqueia todos menos X) eh util
em **projeto solo**. Em equipe, preferir:

- Validar formato de email (regex de dominio)
- Ou permitir lista: `USER_WHITELIST="name1 name2 name3"`

### commit-msg roda em `git commit --amend`

Ao amend, o hook valida de novo. Se mensagem original era invalida,
amend nao conserta ate mensagem nova ser valida.

### Skip de hook

Usuario pode contornar com `--no-verify` (`git commit -n`). Isso eh
deliberado — hook nao substitui revisao humana. Em CI, rodar
validacao tambem (defense in depth).

### Merge commits sem conventional format

`Merge pull request #123 from branch` nao segue conventional. O
template ja trata com:

```sh
if echo "$MSG" | grep -qE "^Merge |^Revert "; then
    exit 0
fi
```

### Cherry-pick / rebase

Durante rebase interativo, hooks rodam a cada commit. Se mensagens
antigas sao invalidas, rebase aborta. Solucao: `git rebase -i
--committer-date-is-author-date` + manualmente editar mensagens antigas.

### Windows line endings

Em Windows, `.githooks/commit-msg` pode vir com CRLF. Adicionar no
`.gitattributes`:

```
.githooks/* text eol=lf
```

Senao `bash: /r: No such file or directory` em execucao.

### Symlinks em sistemas de arquivos sem suporte

`chmod +x` em alguns CI (Windows runners) nao persiste. `install-hooks.sh`
deve tambem rodar `chmod +x` no postinstall.

## Templates fornecidos

| Template | Destino | Descricao |
|----------|---------|-----------|
| `commit-msg` | `.githooks/commit-msg` | Valida idioma + formato |
| `pre-commit` | `.githooks/pre-commit` | Valida identidade |
| `install-hooks.sh` | `scripts/install-hooks.sh` | Postinstall setup |

## Scripts

| Script | Uso |
|--------|-----|
| `scripts/install-hooks.sh` | Configura core.hooksPath + garante permissions |

## Ver tambem

- [`git-methodology/references/conventional-commits.md`](../git-methodology/references/conventional-commits.md)
- [`release-quality-gate`](../release-quality-gate/) — valida commits em release time
- [git core.hooksPath](https://git-scm.com/docs/githooks#_customizing_git_hooks)
- [commitlint](https://commitlint.js.org/) — alternativa baseada em config JSON
