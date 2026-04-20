# Git Hooks Customizados

Instalação de hooks `commit-msg` e `pre-commit` para enforcement de
convenções de commit e identidade.

> **Índice geral**: [README.md](./README.md)

## Instalação

```
instalar git hooks neste projeto
```

Skill `git-hooks-install` cria:

```
projeto/
├── .githooks/
│   ├── commit-msg              # Valida formato + idioma
│   └── pre-commit              # Enforce identity
├── scripts/
│   └── install-hooks.sh        # Postinstall script
└── package.json                # Adiciona "postinstall"
```

Configura `git config core.hooksPath .githooks` (per-clone; postinstall
automatiza para novos contribuidores).

## `commit-msg` — Conventional + EN-US

Rejeita:

- Header fora do formato `type(scope): description`
- Verbos PT-BR (adicionar, corrigir, atualizar, etc. — lista completa no template)

Aceita commits `Merge ...` e `Revert ...` (bypass).

### Exemplo de erro

```
ERROR: Commit message appears to be in Portuguese (PT-BR).
This repository requires commit messages in English (EN-US).

Subject: 'corrigir erro no parser'

  WRONG: fix: corrigir erro no parser
  RIGHT: fix: fix parser error
```

## `pre-commit` — Identity enforcement

Rejeita commits de autores diferentes:

```sh
REQUIRED_NAME="4i3n6"
REQUIRED_EMAIL="4i3n6@pm.me"
```

### Erro

```
ERROR: Commits to this repository must be authored by 4i3n6 <4i3n6@pm.me>
Current identity: cyllas <cyllas@gmail.com>

Fix with:
  git config user.name '4i3n6'
  git config user.email '4i3n6@pm.me'
```

Útil para:

- Projetos solo com identidade obrigatória (CI enforcement)
- Equipes com lista fixa de autores (adaptar para whitelist)

## Postinstall Automation

Script `install-hooks.sh`:

```sh
#!/bin/sh
git config core.hooksPath .githooks
find .githooks -type f -exec chmod +x {} \;
exit 0
```

Adicionado em `package.json`:

```json
"scripts": {
  "postinstall": "sh scripts/install-hooks.sh"
}
```

Quando contribuidor roda `npm install`, hooks são automaticamente configurados.

## Relação com fluxos de release

Os hooks são **pré-requisito** para ambos os padrões de release:

- `release-please` exige Conventional Commits
- `release-manual` também exige Conventional Commits

Instale `git-hooks-install` antes de configurar qualquer fluxo de release.

## Ver também

- [README.md](./README.md) — índice e visão geral
- [release-please.md](./release-please.md) — fluxo automatizado
- [release-manual.md](./release-manual.md) — fluxo manual
