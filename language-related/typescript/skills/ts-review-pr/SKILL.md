---
name: ts-review-pr
description: |
  Revisa PR de projetos TypeScript/Cloudflare Workers com checklist de qualidade.
  Use quando o usuário disser "review pr", "revisar pr", "code review", "audit pr",
  "checar PR", "validar mudanças", "quality gate".
  NÃO use para reviews de código que não sejam de um PR aberto.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Review PR TypeScript

Revisa PR de projetos Cloudflare Workers + Hono + Drizzle ORM + TypeScript strict com checklist estruturado.

## Intro

Code review é a defesa final contra bugs, vulnerabilidades e dívida técnica antes
da fusão. Um review eficaz vai além do "LGTM" — ele identifica problemas
específicos com referências a linhas de código, sugere melhorias concretas e
verifica que a implementação não viola padrões do projeto ou boas práticas de
segurança.

Este skill implementa um checklist de 8 categorias cobrindo: tipos strict,
error handling, testes, performance Workers (CPU budget 50ms), segurança
(LGPD/PII em logs, SQL injection), DRY/SOLID. Cada item deve ser verificado
arquivo por arquivo, não apenas visto superficialmente.

## Pre-flight Reads

- `wrangler.toml` — se routes ou bindings foram modificados
- `drizzle.config.ts` ou similar — para entender migrations
- `.claude/skills/` — skills de referência se houver dúvida

## Workflow

### 1. Gather PR context

Execute em paralelo:
```bash
gh pr view <pr-number> --json title,body,state,additions,deletions,changedFiles
gh pr diff <pr-number>
git log --oneline -10
```

Se não tiver o número do PR:
```bash
gh pr list --state open --author @me
```

### 2. Analisar arquivos modificados

Para cada arquivo modificado:
1. Leia o conteúdo completo do diff
2. Aplique o checklist abaixo
3. Documente findings com `file:linha` para cada problema

### 3. Checklist de Review

#### A. Tipos Strict
- [ ] Nenhum `any` ou `unknown` implícito sem justificativa documentada
- [ ] Types exports usados corretamente para contratos de API
- [ ] Zod schemas para validação de input/output
- [ ] Tipos de retorno de handlers com Tipos corretos

#### B. Error Handling
- [ ] Handlers usam try/catch e retornam erros estruturados
- [ ] Erros não expõem stack traces para o cliente
- [ ] Logs usam formato estruturado com `logger.error` (não `console.error`)
- [ ] Erros customizados têm código de erro consistente

#### C. Testes Vitest
- [ ] Novos handlers имеют cobertura de testes
- [ ] Testes unitários para Zod schemas
- [ ] Mocks para dependências externas (Hono Request/Response)
- [ ] Testes cobrem cenários de erro (404, 400, 500)

#### D. Performance Workers
- [ ] CPU budget respeitado (máximo 50ms)
- [ ] Sem operations síncronas pesadas no handler
- [ ] Queries de banco otimizadas (índices, pagination)
- [ ] Sem loading de dados desnecessários no caminho crítico

#### E. Segurança
- [ ] Nenhum PII (email, CPF, telefone) em logs — usar máscara `222***222`
- [ ] Nenhuma interpolação de strings em SQL queries — usar Drizzle ORM ou parameterized queries
- [ ] Secrets não hardcoded — usar `c.env` bindings
- [ ] Rate limiting implementado em endpoints públicos
- [ ] CORS configurado corretamente

#### F. DRY / SOLID
- [ ] Lógica duplicada extraída para funções/hooks reutilizáveis
- [ ] Princípio de responsabilidade única — handler faz uma coisa
- [ ] Repositórios acessam banco, services contêm lógica de negócio, handlers apenas coordenam

#### G. Convenções TypeScript
- [ ] Código em inglês (variáveis, funções, comentários)
- [ ] Interface names em PascalCase
- [ ] Constantes em SCREAMING_SNAKE_CASE
- [ ] Nomes de arquivos em kebab-case

#### H. Configurações Cloudflare
- [ ] wrangler.toml bindings corretos (vars, secrets, kv, d1, r2)
- [ ] Routes definidos corretamente (padrão vs custom domain)
- [ ] Migration D1 aplicada se schema mudou

### 4. Executar testes localmente

Antes de aprovar, 必须 executar localmente:
```bash
npm run test          # Vitest
npm run typecheck     # tsc --noEmit
npm run lint          # ESLint strict
```

### 5. Publicar review

Publique comments inline para problemas específicos E um review summary:

```bash
gh pr review <pr-number> --comment --body "
## PR Review

### findings

**[FILE:LINE]** Descrição do problema

### Recommendations

1. Sugestão de melhoria

### Approved

✅ Build passing
✅ Tipos strict
✅ Testes passando
✅ Segurança verificada
"
```

## Exemplo Bom

Review com 5 inline comments construtivos:

```
[src/routes/users.ts:23]** Tipo any implícito**
\`any\` sem justificativa. Usar \`unknown\` e validar com Zod schema.

[src/routes/users.ts:45]** SQL injection risk**
Interpolação de string em query. Usar \`db.select().from()\` com Drizzle ORM.

[src/routes/users.ts:67]** PII em log**
Email do usuário visível no log. Aplicar máscara: \`email.replace(/^(.{3})@/, '***@')\`

[src/handlers/auth.ts:89]** Handler muito grande**
Extratos lógica de validação para função separada para reutilização e testabilidade.

[wrangler.toml:12]** Secret em vars**
\`SECRET_KEY\` deve ser secrets, não vars. Usar \`wrangler secret put SECRET_KEY\`
```

**Por que é bom**: Cada comment tem referência de arquivo e linha, descreve o problema específico, sugere como corrigir.

## Exemplo Ruim

```
LGTM! 🚀
```

**Por que é ruim**: Review genérico que não ajuda o autor a melhorar. Não há feedback acionável.

```
O código precisa ser melhorado.
```

**Por que é ruim**: Vago, não aponta onde nem como melhorar.

## Gotchas

- **Gotcha 1**: Revisar arquivo por arquivo, não fazer review geral. Cada finding deve ter `file:linha` preciso.
- **Gotcha 2**: Nunca aprovar PR sem executar testes localmente — gh pr review pode ser aprovado sem testes rodarem no CI ainda.
- **Gotcha 3**: Se wrangler.toml mudou, verificar se bindings novos precisam de secrets configurados (`wrangler secret put`).
- **Gotcha 4**: Validar que migrations D1 estão no PR se schema mudou — migrations são commits separados e devem ser revisadas independientemente.
- **Gotcha 5**: Para PRs grandes (>10 arquivos), sugerir splitting em múltiplos PRs se as mudanças não são relacionadas.
- **Gotcha 6**: Verificar se os testes são determinísticos — mocks que podem falhar intermitentemente são piores que não ter testes.
- **Gotcha 7**: Se houver mudanças de API, verificar se a spec/documentação foi atualizada junto.

## Quando NÃO usar

- **Revisar código sem ser PR** — use análise direta sem o workflow de gh pr
- **Review de segurança específico** — use a skill `owasp-security` (global)
- **Revisar migrations D1** — use o workflow de migration checks específico
- **Auditoria de compliance** — ferramenta especializada necessária
