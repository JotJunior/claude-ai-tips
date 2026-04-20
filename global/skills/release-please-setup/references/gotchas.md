# Gotchas Adicionais

Problemas comuns e armadilhas conhecidas alem dos 3 gotchas criticos do SKILL.md principal.

Vide tambem: [`../SKILL.md`](../SKILL.md)

## Branches master vs main

release-please assume `main` por default. Se repo usa `master`:

```yaml
on:
  push:
    branches:
      - master

with:
  default-branch: master
```

## Auto-merge pode conflitar com branch protection

Se `main` tem branch protection exigindo review, auto-merge precisa ser
feito por uma GitHub App com permissao ou via PAT de admin. Default
`GITHUB_TOKEN` pode nao conseguir mergear.

Requer que o repo permita auto-merge: Settings > General > Pull Requests > Allow auto-merge.

## Tag prefix vs component

Sem `include-component-in-tag`, tag eh `v1.2.3`. Com, eh `<component>-v1.2.3`.

Em single package, manter sem component (prefixo limpo). Em monorepo,
ligar component (discriminar pacote).

## Commits legacy baguncados

Se repo tem commits "fix cadastro" sem conventional prefix, release-please
ignora-os. Para release-please funcionar, ADOTAR conventional a partir de
agora — nao retroativar.

## Hidden sections nao aparecem mas somam

`chore: bump deps` com `hidden: true` nao aparece no CHANGELOG, mas CONTA
para detectar bump. Se repo tem so `chore` desde ultima tag:
release-please nao cria release PR (sem commits visiveis).

## changelog-host precisa estar correto

Default eh `github.com`. Se repo privado em GitHub Enterprise:

```json
"changelog-host": "https://github.enterprise.company.com"
```

GitLab, Gitea, etc: precisa customizar.

## Primeira versao e initial-version

Se nenhum arquivo de versao existe e nenhuma tag, release-please usa
`0.0.1` como default. Configurar `initial-version` se quiser diferente:

```json
"initial-version": "0.1.0"
```
