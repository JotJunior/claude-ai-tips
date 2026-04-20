---
name: ts-commit
description: |
  Cria commits atômicos seguindo conventional commits com estilo PT-BR.
  Use quando o usuário disser "commit", "criar commit", "fazer commit", "atomic commit",
  "commitar mudanças", "salvar alterações".
  NÃO use quando for apenas staging automático (use outra skill).
allowed-tools:
  - Bash
  - Grep
  - Read
  - Glob
---

# Commit TypeScript

Cria commits atômicos seguindo conventional commits para projetos Cloudflare Workers + Hono + TypeScript strict.

## Intro

Commits bem estruturados são a base de um histórico git navegável e de um codebase
saudável. Um commit atômico contém APENAS mudanças relacionadas a uma única
funcionalidade ou correção — nunca múltiplas preocupações misturadas. A mensagem
deve ser descritiva o suficiente para que qualquer pessoa do time entenda o que
foi feito e por quê, sem precisar ler o diff.

Este skill segue Conventional Commits com body em português brasileiro, o que
facilita a navegação do histórico em equipes que trabalham com documentação e
comentários em PT-BR. O escopo deve refletir a área do código impactada (api,
auth, db, worker, etc.).

## Pre-flight Reads

- `git log --oneline -10` — entender o estilo de commits recentes do projeto
- `git diff --staged` — verificar o que já está staged antes de adicionar mais
- `.gitignore` — confirmar que arquivos sensíveis não estão sendo trackeados

## Workflow

### 1. Gather context

Execute em paralelo:
```bash
git status
git diff --staged
git diff
git log --oneline -5
```

### 2. Analisar mudanças

Revise todos os arquivos modificados e categorize:

- **Tipo de mudança**: qual é o intent principal? (feat, fix, refactor, docs, chore, test, build, ci)
- **Escopo**: qual área do código foi impactada? (api, auth, db, worker, bindings, migrations)
- **Tamanho**: se o diff for muito grande (>15 arquivos), sugira separar em múltiplos commits
- **Dependências lógicas**: quais arquivos devem ser commitados juntos?

### 3. Stage files

- Use `git add <arquivo>` para arquivos específicos
- **NUNCA** use `git add .` ou `git add -A` sem verificar o que está sendo adicionado
- **NUNCA** commite arquivos que possam conter segredos: `.env`, `.env.*`, `credentials.json`, `*.pem`, `wrangler.toml` com secrets inline
- **NUNCA** commite arquivos temporários: `t.txt`, `*.tmp`, `scratch.*`

Se existirem arquivos não rastreados que precisam ser ignorados, sugira adicionar ao `.gitignore`.

### 4. Draft commit message

Siga o formato Conventional Commits:

```
<tipo>(<escopo>): <resumo em português, imperativo, até 72 caracteres>

<corpo em PT-BR com bullet points das principais mudanças>
<linhas de até 80 caracteres>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Tipos permitidos**:
- `feat` — nova funcionalidade
- `fix` — correção de bug
- `refactor` — refatoração sem mudança de comportamento
- `docs` — documentação
- `chore` — tarefas de manutenção (deps, configs)
- `test` — adicionar ou corrigir testes
- `build` — mudanças de build ou dependências externas
- `ci` — pipelines e automação

**Regras**:
- Resumo em português, imperativo ("adicionar validação" não "adiciona" ou "foi adicionado")
- Se múltiplas áreas foram impactadas, liste-as no body
- body em PT-BR com acentos corretos
- Sempre termine com Co-Authored-By

### 5. Commit

Use HEREDOC para preservar formatação:
```bash
git commit -m "$(cat <<'EOF'
<tipo>(<escopo>): <resumo>

<corpo>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 6. Verificar

Execute `git status` e `git log --oneline -3` para confirmar o commit.

## Exemplo Bom

```bash
feat(api): adicionar validação de input com Zod

- Novo schema `userSchema` para POST /api/users
- Validação automática no middleware de rota
- Retorna 400 com detalhes do erro de validação
- Cobertura de testes para cenários inválidos

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
**Por que é bom**: Commit atômico focado em uma única mudança, body rico com contexto, tipo/escopo claros.

## Exemplo Ruim

```bash
git add .
git commit -m "updates"
```
**Por que é ruim**: Sem tipo, sem escopo, sem mensagem descritiva, staging cego. Impossível navegar o histórico.

```bash
feat: implementar的功能
```
**Por que é ruim**: Mensagem em chinês misturado com tipo inglês, impossível entender.

```bash
fix: various fixes
```
**Por que é ruim**: "Various fixes" não diz nada. Qualquer pessoa vendo esse commit no log não sabe o que foi corrigido.

## Gotchas

- **Gotcha 1**: Nunca usar `git add .` cego. Sempre verificar `git status` antes e adicionar arquivos específicos.
- **Gotcha 2**: Validar identidade git (`git config user.name` e `git config user.email`) antes de commitar em nome do usuário.
- **Gotcha 3**: Separar mudanças de formatação (lint, prettier) de mudanças de lógica. Commitar formatação separadamente com tipo `chore`.
- **Gotcha 4**: Em projetos Cloudflare Workers, nunca commitar `wrangler.toml` com secrets reais — usar `wrangler secret put` para secrets e `.env.example` para vars públicas.
- **Gotcha 5**: Commits de migration devem incluir o número sequencial e ser atômicos — uma migration por arquivo, cada um revertível.
- **Gotcha 6**: Se o diff contiver mudanças em arquivos de destino diferentes (ex: API route + migration + testes), agrupe por цель e faça múltiplos commits se necessário.
- **Gotcha 7**: Antes de commitar, verificar se `go.mod` ou `package-lock.json` foram modificados. Se sim, garantir que são necessários para a mudança.

## Quando NÃO usar

- **Staging automático antes de push** — use hook de pre-commit
- **Commits de merge** — git faz automaticamente
- **Revert de commits** — git revert é suficiente
- **Atualização de submódulos** — use skill específica de Go para isso

## Flaky Pre-commit Hooks

Se o commit falhar por pre-commit hook:
1. Leia o erro completo
2. Corrija o problema (lint, тип checking, testes)
3. Re-stage os arquivos corrigidos
4. Crie **NOVO** commit (nunca usar `--amend` a menos que explicitamente solicitado)
