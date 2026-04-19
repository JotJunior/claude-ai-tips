# Contribuindo

Como adicionar skills, hooks ou melhorias ao `claude-ai-tips`.

## Pré-requisitos

- Leu [architecture.md](./architecture.md) e entende o princípio de partição
- Familiaridade com formato SKILL.md (frontmatter YAML + markdown)
- `shellcheck` instalado (valida scripts POSIX)
- Node.js ≥18 se for contribuir com skills de release (`release-manual-setup`)

## Workflow de contribuição

### 1. Fork + branch feature

```bash
gh repo fork JotJunior/claude-ai-tips --clone=false
git clone https://github.com/<seu-user>/claude-ai-tips.git
cd claude-ai-tips
git checkout -b feat/<nome-da-mudanca>
```

Branch naming:

- `feat/<short-description>` — nova skill/hook
- `fix/<short-description>` — correção
- `docs/<short-description>` — atualização de documentação
- `refactor/<short-description>` — refactor sem mudança externa
- `chore/<short-description>` — manutenção (deps, lint, config)

### 2. Decidir categoria

Use a árvore de decisão em [architecture.md](./architecture.md#decisão-onde-adicionar-nova-skill)
para escolher onde a skill entra (`language-related/`, `platform-related/`,
`data-related/` ou `global/skills/`).

### 3. Criar a estrutura

```bash
SKILL_NAME=minha-skill
SKILL_PATH=global/skills/$SKILL_NAME   # ou subpasta de categoria

mkdir -p $SKILL_PATH/{templates,examples,references,scripts}
touch $SKILL_PATH/SKILL.md
```

Nem toda skill usa todas as subpastas — remova as que não precisa.

### 4. Escrever SKILL.md

Template mínimo:

```markdown
---
name: minha-skill
description: |
  Use quando o usuario <situação concreta A>. Tambem quando
  mencionar "<keyword1>", "<keyword2>", "<keyword3>". NAO use para
  <situação contraria> (use <outra-skill>).
argument-hint: "<arg1> [--flag=<value>]"
allowed-tools:
  - Read
  - Bash
---

# Skill: <Nome Legível>

Descrição curta de propósito (1-2 parágrafos).

## Quando invocar

- Cenário 1
- Cenário 2
- NÃO invocar quando ...

## Argumentos

(Tabela ou lista de argumentos esperados)

## Fluxo

### Etapa 1: ...
### Etapa 2: ...
### Etapa N: ...

## Gotchas

### Armadilha 1
### Armadilha 2
### ...

## Ver também

- Links para skills relacionadas
- Links para references
```

### 5. Implementar scripts (se aplicável)

Scripts POSIX para operações determinísticas. Header padrão:

```sh
#!/bin/sh
# <nome>.sh — <resumo em uma linha>.
#
# Uso:
#   <nome>.sh [opções] <args>
#
# Opções:
#   --foo=X       descrição
#   --bar         flag booleana
#
# Exit codes:
#   0  sucesso
#   1  erro lógico
#   2  erro de permissão
#   3  dependência ausente

set -eu
```

Após criar:

```bash
chmod +x $SKILL_PATH/scripts/*.sh
shellcheck $SKILL_PATH/scripts/*.sh
sh -n $SKILL_PATH/scripts/<script>.sh
```

### 6. Adicionar templates/examples/references (se aplicável)

- **templates/** — arquivos prontos para copiar (configs, scripts pré-gerados)
- **examples/** — `<topico>-good.md` + `<topico>-bad.md` com comentários
- **references/** — material denso consultado sob demanda

### 7. Testar

- Invoque a skill via Claude Code em um projeto real
- Rode scripts manualmente com casos de borda
- Valide que `description:` dispara em pelo menos 3 frases diferentes

### 8. Documentar em `docs/`

Adicione:

- Entrada em [`docs/skills-catalog.md`](./skills-catalog.md) (tabela com trigger + resumo)
- Link no README da categoria (se aplicável)
- Se for skill complexa: novo guide em `docs/guides/`
- Se for feature nova end-to-end: exemplo em `docs/examples/`

### 9. Commit atômico com body rico

```bash
git add $SKILL_PATH
git commit
```

Editor abre. Formato:

```
feat(skills): minha-skill — <resumo curto>

<O que a skill faz e por que foi criada. Inclui contexto de qual problema
resolve.>

<Descrição do fluxo principal, subcomandos, flags importantes.>

<Gotchas principais que foram documentados.>
```

Regras:

- Conventional commits (`feat`, `fix`, `docs`, `refactor`, `chore`, `test`)
- Subject ≤ 100 chars
- EN-US no subject e body **se contribuindo upstream** (projeto original
  usa PT-BR mas recomenda-se EN-US para PRs públicos)
- Body ≥ 20 chars descrevendo o PORQUÊ (não o quê)

### 10. Push + abrir PR

```bash
git push -u origin feat/<nome-da-mudanca>
gh pr create --repo JotJunior/claude-ai-tips --base main \
  --title "feat(skills): minha-skill" \
  --body-file /tmp/pr-body.md
```

PR body deve incluir:

- Motivação
- Lista de commits (1 linha por commit)
- Estrutura nova (árvore)
- Validações executadas
- Checklist antes do merge

## Convenções

### Nomenclatura

| Padrão | Exemplo |
|--------|---------|
| Skills com prefixo de linguagem | `go-add-entity`, `ts-commit`, `py-add-fastapi-route` |
| Skills com prefixo de plataforma | `cf-api-call`, `neon-create-branch` |
| Skills com prefixo de serviço | `pg-query-optimize`, `d1-batch-pattern` |
| Skills agnósticas sem prefixo | `cred-store`, `briefing`, `bugfix` |
| Diretórios kebab-case | `cred-store-setup/`, `release-quality-gate/` |

### Linguagem de conteúdo

- **Código, comentários, scripts**: EN-US
- **Commits em PRs upstream**: EN-US (convenção open source)
- **SKILL.md, references, templates**: PT-BR (consistente com o toolkit)
- **docs/ guides e examples**: PT-BR
- **Nomes de skills, scripts, variáveis**: EN-US sempre

### Frontmatter YAML

Obrigatório:

- `name:` — kebab-case, único no toolkit
- `description:` — trigger-condition (não resumo)
- `allowed-tools:` — lista explícita das tools permitidas

Opcional:

- `argument-hint:` — formato dos argumentos
- `version:` — SemVer da skill (se skill evolui independente)

### Gotchas obrigatórios

Toda SKILL.md nova deve ter pelo menos **3 gotchas** documentados. Se não
conseguir pensar em 3, é sinal de que:

1. A skill é muito simples (talvez não precise existir)
2. Você ainda não usou em produção (volte quando tiver experiência real)
3. Está faltando imaginação sobre edge cases

Gotchas canônicos para inspiração:

- Input inválido mas aceito silenciosamente
- Comportamento diferente em OS diferente
- Dependência opcional que quebra quando ausente
- Cache stale
- Caso com muitos dados (performance)
- Caso com credenciais rotacionadas
- Caso sem rede
- Caso em CI vs dev local

### Segurança

Antes de commitar, verifique:

- [ ] Nenhum segredo em arquivos versionados (tokens, passwords, keys)
- [ ] `.gitignore` cobre arquivos sensíveis
- [ ] Scripts rejeitam symlinks em paths de credenciais
- [ ] Audit logs não registram valores de segredos
- [ ] Templates não têm dados reais (usar placeholders `REPLACE_WITH_...`)

Execute:

```bash
# Detecta segredos comuns
git diff --staged | grep -iE '(password|token|api[_-]?key|secret)' && echo "REVISAR"

# Detecta arquivos grandes
git diff --staged --stat | awk 'NR>1 && $NF > 500 { print "ARQUIVO GRANDE:", $NF, "linhas"}'
```

## Validação antes do PR

### Scripts

```bash
# Syntax
sh -n $SKILL_PATH/scripts/*.sh

# Static analysis (recomendado)
shellcheck $SKILL_PATH/scripts/*.sh

# Permissions
find $SKILL_PATH -name '*.sh' ! -perm -u+x -print
```

### SKILL.md

- [ ] Frontmatter YAML válido (testar com `yq` ou similar)
- [ ] Seções: overview, fluxo, gotchas, ver-também
- [ ] Sem placeholders (`TODO`, `FIXME`, `<placeholder>`)
- [ ] Links funcionais (relativos)

### Árvore

```bash
# Deve cobrir a estrutura esperada
tree $SKILL_PATH

# Não deve ter arquivos temporários
find $SKILL_PATH -name '.DS_Store' -o -name '*.swp' -o -name '*~' -delete
```

## Review criteria (o que o maintainer olha)

Ao receber PR, o maintainer valida:

1. **Princípio de partição** — categoria escolhida está correta?
2. **Shape consistente** — estrutura igual a skills existentes da mesma categoria?
3. **Description trigger-condition** — dispara corretamente? Não colide com outras?
4. **Gotchas valiosos** — armadilhas reais, não placeholders?
5. **Scripts seguros** — validações, error handling, exit codes distintos?
6. **Sem segredos** — grep de padrões sensíveis, revisão manual de configs?
7. **Documentação** — README da categoria atualizado? `skills-catalog.md`?
8. **Commits atômicos** — cada commit é revertível sozinho?
9. **Body rico nos commits** — explicam PORQUÊ, não só o QUÊ?
10. **Backwards-compatible** — não quebra skills existentes?

## Tipos de contribuição bem-vindos

### Alto valor

- **Nova skill que cobre lacuna real** — analise `docs/skills-catalog.md`
  para ver o que já existe
- **Gotchas em SKILL.md existentes** — adicione caso real que te mordeu
- **Hooks novos** — especialmente para `language-related/typescript/` e
  `language-related/python/` que ainda não existem
- **Exemplos end-to-end em `docs/examples/`** — cenários reais com código

### Médio valor

- Fix em script existente
- Atualização de reference (links, versões)
- Tradução de SKILL.md para EN (para contribuição upstream mais ampla)

### Baixo valor (recusável)

- Rename de skill sem justificativa forte
- Mudança de estilo puro (se passa shellcheck, tá bom)
- Skill que duplica funcionalidade existente

## Processo após o merge

Após o PR ser merjeado:

1. Maintainer atualiza `CHANGELOG.md` para a próxima versão
2. Tag de release criada (`git tag -a v2.X.0`)
3. Release notes publicadas no GitHub

Suas contribuições aparecem em:

- `git log --author=<seu-email>`
- Entrada em `CHANGELOG.md`
- Release notes da versão

## Perguntas frequentes

### Posso adicionar skill em linguagem nova?

Sim. Crie `language-related/<nova-linguagem>/` seguindo shape de `go/` ou
`dotnet/`. Comece por `<prefix>-commit` (maior ROI inicial).

### Posso adicionar skill em serviço de dados novo?

Sim. Crie `data-related/<servico>/` seguindo o shape proposto em
[architecture.md](./architecture.md#data-related). Comece pelo references
(`<dsl>-cheatsheet.md`) — é o arquivo mais consultado.

### Como testo minha skill antes de PR?

1. Copie para `~/.claude/skills/<nome>/`
2. Abra projeto real
3. Digite no Claude Code frases do `description:` — skill deve ser invocada
4. Teste edge cases documentados em gotchas
5. Rode scripts isoladamente

### O que faço se minha skill conflita com existente?

Abra issue primeiro, antes de PR. Discuta:

- Consolidar em uma só com `config.json` parametrizando?
- Manter separadas com nomes claramente distintos?
- Deprecar uma em favor da outra?

## Licença

Ao contribuir, você concorda que sua contribuição será licenciada sob
[MIT](../LICENSE) — mesma licença do projeto.

## Ver também

- [architecture.md](./architecture.md) — filosofia e princípio de partição
- [glossary.md](./glossary.md) — vocabulário do projeto
- [skills-catalog.md](./skills-catalog.md) — estado atual
