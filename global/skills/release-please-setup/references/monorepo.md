# Monorepo: Configuracao Multi-Pacote

Configurar release-please para projetos com multiplos pacotes/libraries em um unico repo.

Vide tambem: [`../SKILL.md`](../SKILL.md)

## Configuracao basica

No `release-please-config.json`:

```json
{
  "packages": {
    "packages/web": {
      "release-type": "node",
      "component": "web"
    },
    "packages/api": {
      "release-type": "node",
      "component": "api"
    },
    "packages/shared": {
      "release-type": "node",
      "component": "shared"
    }
  },
  "include-component-in-tag": true
}
```

## Tags geradas

| Pacote | Tag |
|---|---|
| `packages/web` | `web-v1.2.3` |
| `packages/api` | `api-v2.0.0` |
| `packages/shared` | `shared-v0.5.1` |

## Manifest

O `.release-please-manifest.json` precisa listar cada pacote com sua versao atual:

```json
{
  "packages/web": "2.0.0",
  "packages/api": "1.5.3",
  "packages/shared": "0.8.1"
}
```

## CHANGELOGs individuais

Cada pacote gera seu proprio `packages/<name>/CHANGELOG.md`.

Release PR por pacote — cada um tem release independente.

## Release-types diferentes

Monorepo pode misturar release-types:

```json
{
  "packages": {
    "packages/web": { "release-type": "node" },
    "packages/api": { "release-type": "node" },
    "packages/shared": { "release-type": "node" }
  }
}
```

Para outros tipos (python, rust, go), usar release-type correspondente.

## Workflow GitHub Actions

O workflow `.github/workflows/release-please.yml` permanece o mesmo, a
config no `packages` faz o trabalho.

## Limpeza apos merge

Nao ha necessidade de job adicional — cada pacote gerencia seu proprio
release cycle.
