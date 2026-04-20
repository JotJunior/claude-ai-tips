# Gestão de Credenciais

Guia prático do sistema `cred-store` + `cred-store-setup` — armazenamento e
consumo de credenciais externas (API tokens, passwords, connection strings)
de forma segura e agnóstica.

## Visão geral

O problema: skills do toolkit precisam autenticar contra APIs externas
(Cloudflare, Neon, Elasticsearch, etc.) sem:

- Vazar segredos em arquivos versionados
- Acoplar cada skill à sua própria lógica de secrets
- Forçar dependência de tooling específico (1Password, Keychain)
- Perder rastreabilidade de operações sensíveis

A solução: um **credential store agnóstico** com cascata de fontes, da mais
segura para a menos segura, onde cada credencial é identificada por uma
**key** estável e segredos **nunca** ficam em arquivo versionado.

Princípios:

1. **Segredos nunca em `registry.json`** — apenas referências
2. **Cascata de resolução** — env → 1Password → Keychain → arquivo
3. **Audit append-only** — rastreio de operações sem valores
4. **Permissões estritas** — diretórios `700`, arquivos `600`
5. **Agnóstico de provider** — mesma API para CF, Neon, ES, qualquer

## Arquitetura

### Cascata de fontes

```
                   resolve.sh <key>
                          │
                          ▼
         ┌─────────────────────────────────┐
         │  Lê entry em registry.json      │
         │  → source, ref, metadata         │
         └─────────────────────────────────┘
                          │
                          ▼
         ┌─────────────────────────────────┐
         │  Tenta fonte primária           │
         └─────────────────────────────────┘
                          │
     ┌────────────────────┼────────────────────┐
     ▼                    ▼                    ▼
 ┌────────┐          ┌────────┐          ┌────────┐
 │  env   │          │   op   │          │keychain│
 │        │          │ (1Pwd) │          │ (macOS)│
 └────────┘          └────────┘          └────────┘
                          │
                          ▼
                     ┌────────┐
                     │  file  │
                     │ (600)  │
                     └────────┘
                          │
                   Primeiro sucesso vence
```

### Layout do store

```
~/.claude/credentials/                      (chmod 700)
├── .gitignore                              (ignora tudo por default)
├── README.md                               (doc do layout)
├── registry.json                           (chmod 600, índice key → source+ref+metadata)
├── audit.log                               (append-only, sem segredos)
├── files/                                  (chmod 700)
│   └── cloudflare-idcbr-api-token.secret   (chmod 600, quando source=file)
└── cloudflare/                             (por provider, opcional)
    └── idcbr/
        └── audit.log                       (audit específico CF+nick)
```

Permissões são validadas **em cada leitura**. Arquivo com `>600` é rejeitado.
Symlinks em `files/` são rejeitados (bypass de chmod).

## Primeiros passos

### Bootstrap do store

Rodar uma vez por máquina:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/init-store.sh
```

Saída:

```
escrito: /Users/you/.claude/credentials/.gitignore
escrito: /Users/you/.claude/credentials/registry.json
escrito: /Users/you/.claude/credentials/README.md

credential store pronto em: /Users/you/.claude/credentials
proximo passo: /cred-store-setup <provider>.<account>.<type>
```

Flags disponíveis:

| Flag | Efeito |
|------|--------|
| `--force` | Sobrescreve `registry.json` (raro — só em bootstrap inicial) |
| `-h`, `--help` | Mostra ajuda |

Variável de ambiente:

```bash
export CLAUDE_CREDS_DIR=/path/alternativo    # override do default ~/.claude/credentials
```

### Registrar primeira credencial

No Claude Code, digite algo como:

```
configure credenciais Cloudflare para minha conta pessoal
```

A skill `cf-credentials-setup` vai guiar:

```
1. Nickname da conta? → pessoal
2. Escopo do token?    → Workers+D1+KV+R2 (ou customizar)
3. Fonte?              → op / keychain / file / env
4. (se op) URI 1P?     → op://Personal/CF pessoal Token/credential
5. Account ID?         → 1783e2ca3a473ef8334a8b17df42878e
6. Email (opcional)    → user@example.com
7. (valida via /user/tokens/verify)
8. Gravado em registry.json ✓
```

Para registro genérico (não-CF):

```
registre credencial para neon com account nickname production
```

Aciona `cred-store-setup` com prompts equivalentes.

### Verificar registro

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/list.sh
```

Saída tabela:

```
KEY                                      SOURCE     CREATED                        METADATA
---------------------------------------- ---------- ------------------------------ --------
cloudflare.pessoal.api_token             op         2026-04-19T21:00:00Z           {"account_id":"1783...","email":"user@example.com"}
neon.production.api_key                  keychain   2026-04-19T22:15:00Z           {"project_id":"cold-sun-123"}
```

Filtrar por provider:

```bash
bash .../list.sh --provider=cloudflare
```

Formato JSON para consumo programático:

```bash
bash .../list.sh --format=json | jq '."cloudflare.pessoal.api_token".metadata'
```

## Índice

| Arquivo | Conteúdo |
|---------|----------|
| [README.md](./README.md) | Este arquivo — visão geral, arquitetura, primeiros passos |
| [sources.md](./sources.md) | Fontes de armazenamento: 1Password CLI, macOS Keychain, arquivo protegido, variável de ambiente |
| [key-conventions.md](./key-conventions.md) | Convenção de nomes de keys, metadata pública por provider |
| [cookbook.md](./cookbook.md) | Exemplos práticos: registro, rotação, migração, audit trail |
| [troubleshooting.md](./troubleshooting.md) | Erros comuns e soluções |

## Ver também

- [`cred-store/SKILL.md`](../../global/skills/cred-store/SKILL.md) —
  contrato da skill
- [`cred-store-setup/SKILL.md`](../../global/skills/cred-store-setup/SKILL.md) —
  fluxo de registro
- [`credential-storage.md`](../../platform-related/cloudflare-shared/references/credential-storage.md) —
  convenções específicas para CF
- [`cloudflare.md`](./cloudflare.md) — uso de credenciais CF em prática
- [1Password CLI docs](https://developer.1password.com/docs/cli/)
- [macOS security man page](https://ss64.com/mac/security.html)
