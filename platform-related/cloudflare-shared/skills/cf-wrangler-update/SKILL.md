---
name: cf-wrangler-update
description: |
  Use quando o usuario pede para atualizar o Wrangler CLI no projeto
  atual ou globalmente. Tambem quando mencionar "atualizar wrangler",
  "update wrangler", "wrangler latest", "bump wrangler". Detecta o
  package manager em uso (bun/pnpm/yarn/npm) pelo lockfile presente,
  compara versao local com latest no npm registry, executa o upgrade
  e valida o binario pos-update. Avisa sobre breaking changes conhecidos
  entre majors. NAO use para comandos wrangler em si (execucao, deploy,
  dev) — use o CLI direto.
argument-hint: "[--global] [--check-only] [--target-version=<ver>]"
allowed-tools:
  - Bash
  - Read
---

# Skill: Cloudflare Wrangler Update

Atualiza Wrangler CLI preservando a estrategia de instalacao do projeto
(devDep local vs global) e o package manager detectado. Complementa o
hook `check-wrangler-version` — enquanto o hook **avisa** passivamente,
esta skill **executa** o upgrade explicitamente.

## Quando usar

- Usuario pediu upgrade explicito
- Hook `check-wrangler-version` avisou de desatualizacao e o usuario
  quer resolver
- Iniciando trabalho em projeto antigo com wrangler stale
- Antes de operacoes sensiveis (deploy producao) para garantir que
  usa versao com fixes recentes

## Fluxo

### Etapa 1: detectar contexto

```bash
# PM detection via lockfile
if [ -f "$PWD/bun.lock" ] || [ -f "$PWD/bun.lockb" ]; then PM="bun"
elif [ -f "$PWD/pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "$PWD/yarn.lock" ]; then PM="yarn"
elif [ -f "$PWD/package-lock.json" ]; then PM="npm"
fi

# Escopo: devDep local ou global
if [ -f "$PWD/package.json" ]; then
  LOCAL_VER=$(jq -r '.devDependencies.wrangler // .dependencies.wrangler // empty' package.json | sed 's/^[\^~>=<]*//')
fi
GLOBAL_VER=$(wrangler --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
```

### Etapa 2: buscar latest

```bash
LATEST=$(curl -s --max-time 5 https://registry.npmjs.org/wrangler/latest | jq -r '.version')
```

Se rede falhar, abortar com exit code 2 — nao tentar update sem saber
target.

### Etapa 3: comparar e decidir

Cenarios:

| Escopo | LOCAL_VER | LATEST | Acao |
|--------|-----------|--------|------|
| project devDep | presente e igual LATEST | — | "ja atualizado" (exit 0) |
| project devDep | presente e menor | — | bump devDep no PM detectado |
| project devDep | ausente | — | so GLOBAL_VER conta |
| global | GLOBAL_VER igual LATEST | — | "global ja atualizado" |
| global | GLOBAL_VER menor | — | bump global via npm (sempre npm para global, por padrao da propria CF) |

Com `--check-only`, parar aqui — so imprime status, nao executa.

### Etapa 4: detectar major bump

Se LATEST major > LOCAL major, imprimir aviso com link pro changelog:

```
[!] Major bump detectado: 3.x -> 4.x
    Revisar breaking changes:
    https://github.com/cloudflare/workers-sdk/releases
```

Pedir confirmacao via `AskUserQuestion` antes de prosseguir.

Para upgrade minor/patch, prosseguir sem confirmacao (dentro do mesmo
major eh seguro assumir backward-compat).

### Etapa 5: executar update

Por PM detectado:

| PM | Local (devDep) | Global |
|----|-----------------|--------|
| `bun` | `bun add -d wrangler@<ver>` | `bun add -g wrangler@<ver>` (raro) |
| `pnpm` | `pnpm add -D wrangler@<ver>` | `pnpm add -g wrangler@<ver>` |
| `yarn` | `yarn add -D wrangler@<ver>` | n/a (yarn nao tem global oficial) |
| `npm` | `npm install -D wrangler@<ver>` | `npm install -g wrangler@<ver>` |

`<ver>` eh `latest` por padrao ou o `--target-version=x.y.z` quando passado.

### Etapa 6: validar pos-update

```bash
INSTALLED=$(wrangler --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ "$INSTALLED" = "$LATEST" ] || echo "AVISO: wrangler --version retorna $INSTALLED (esperado $LATEST) — pode ser cache/path"
```

Alguns cenarios:
- Cache do shell (rehash needed): sugerir `hash -r` ou abrir novo shell
- PATH resolvendo global quando local existe: checar `which wrangler`

### Etapa 7: limpar cache do version-check

Remover `/tmp/.claude-wrangler-version-check` para que o hook reavalie
na proxima invocacao com versao nova.

```bash
rm -f /tmp/.claude-wrangler-version-check
```

### Etapa 8: relatorio

```
wrangler atualizado:
  escopo:        devDep local (package.json)
  package mgr:   bun
  antes:         3.87.0
  depois:        4.81.1
  breaking?:     SIM (3 -> 4) — revisar changelog
  lockfile:      bun.lock atualizado
  binario:       ok (which wrangler = ./node_modules/.bin/wrangler)
```

## Flags

| Flag | Descricao |
|------|-----------|
| `--global` | Forca update global mesmo que exista devDep local |
| `--check-only` | So reporta status, nao executa (dry-run de update) |
| `--target-version=<v>` | Instala versao especifica em vez de latest |
| `--no-confirm` | Pula confirmacao em major bump (uso em automacao) |

## Gotchas

### devDep local > global — sempre preferir

Quando package.json tem `wrangler` como devDep, rodar `bun run <cmd>`,
`pnpm <cmd>`, `npm run <cmd>` usa o local. Ao chamar `wrangler` direto
no shell, pega o global (se existir) ou falha. Projeto saudavel tem
wrangler como devDep — skill prefere esse escopo.

### Yarn 1 vs Yarn Berry

Comandos diferentes entre yarn classic e yarn berry (v2+). Detectar via
`.yarnrc.yml` (berry) ou `yarn --version`. Skill assume classic por
default; se detectar berry, ajustar para `yarn add -D`.

### Global install no bun eh incomum

Bun tem `bun install -g` mas o padrao da comunidade CF eh nao usar
wrangler global. Se o usuario pedir global e o PM for bun, avisar
que npm eh mais compativel para global wrangler.

### wrangler 4.x vs 3.x — breaking changes

Cloudflare fez bump major 3 -> 4 com mudancas relevantes:

- `--local` mudou de default; local por default em dev
- `wrangler.toml` campos deprecated removidos (verificar `compatibility_date`)
- Alguns comandos renomeados

Ao detectar major bump, oferecer link do changelog. Nao tentar
auto-corrigir `wrangler.toml` — isso eh papel de skill especifica
de migration.

### Cache de lockfile

Apos `bun add -d`, `bun.lock` eh atualizado. Se o projeto esta em git,
avisar o usuario para commitar o lockfile — wrangler pin eh essencial
para reproducibilidade.

### Network failure durante upgrade

Se `curl` pro npm registry falhar, abortar ANTES de tentar update. Um
`npm install` sem internet pode consumir cache e instalar versao velha
silenciosamente.

### CI/CD vs desenvolvimento

Em CI geralmente wrangler vem do lockfile direto (bun install --frozen
ou npm ci). Skill nao deve ser usada em CI — eh ferramenta de dev.
Detectar `CI=true` e recusar com mensagem explicativa.

## Scripts

Esta skill eh orquestracao em bash inline (nao tem script separado
porque cada PM tem comando diferente e detectar + executar eh mais
claro inline do que num wrapper generico).

## Ver tambem

- [`hooks/check-wrangler-version.sh`](../../hooks/check-wrangler-version.sh) — avisa passivamente
- [Wrangler changelog](https://github.com/cloudflare/workers-sdk/releases)
- [Wrangler breaking changes 3.x -> 4.x](https://developers.cloudflare.com/workers/wrangler/migration/update-v3-to-v4/)
