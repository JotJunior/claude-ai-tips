# Getting Started

Do zero ao primeiro uso do `claude-ai-tips` em 5 minutos.

## Pré-requisitos

| Ferramenta | Obrigatória? | Como verificar |
|------------|--------------|----------------|
| Claude Code | sim | `claude --version` |
| git | sim | `git --version` |
| jq | sim | `jq --version` (scripts POSIX usam) |
| curl | sim | `curl --version` |
| 1Password CLI (`op`) | recomendada | `op --version` |
| macOS Keychain (`security`) | opcional (macOS) | `security --version` |

Instalação rápida macOS:

```bash
brew install jq 1password-cli
```

Instalação rápida Linux:

```bash
apt-get install -y jq curl          # Debian/Ubuntu
dnf install -y jq curl              # Fedora
# 1Password CLI: https://developer.1password.com/docs/cli/get-started/
```

## Passo 1 — Clonar o toolkit

```bash
cd ~/Sistemas        # ou onde preferir
git clone https://github.com/JotJunior/claude-ai-tips.git
cd claude-ai-tips
ls
```

Estrutura top-level:

```
claude-ai-tips/
├── README.md                 # overview no GitHub
├── CHANGELOG.md              # histórico
├── LICENSE                   # MIT
├── docs/                     # você está aqui
├── global/                   # skills agnósticas + insights
├── language-related/         # Go, .NET (TS/Python planejados)
├── platform-related/         # Cloudflare (Neon planejado)
└── data-related/             # scaffold (skills planejadas)
```

## Passo 2 — Usar uma skill em um projeto

Há duas formas:

### Opção A — copiar skills para o projeto

Para que as skills fiquem **versionadas junto com o projeto** e todos os
contribuidores tenham acesso:

```bash
cd /caminho/para/meu-projeto
mkdir -p .claude/skills
cp -r ~/Sistemas/claude-ai-tips/global/skills/cred-store .claude/skills/
cp -r ~/Sistemas/claude-ai-tips/global/skills/cred-store-setup .claude/skills/
```

No Claude Code, as skills ficam disponíveis automaticamente quando
invocadas pelo nome (ex: "configure credenciais Cloudflare" vai acionar
`cf-credentials-setup`).

### Opção B — instalar skills globalmente

Para ter as skills disponíveis em **qualquer projeto** sem copiar:

```bash
mkdir -p ~/.claude/skills
cp -r ~/Sistemas/claude-ai-tips/global/skills/* ~/.claude/skills/
```

Skills em `~/.claude/skills/` funcionam como "skills do usuário" e são
carregadas pelo Claude Code em qualquer diretório de projeto.

## Passo 3 — Ativar hooks (opcional)

Hooks são gates automáticos (PreToolCall, PostToolCall, Stop) que validam
antes/depois de ações do Claude. Para ativar no projeto atual:

```bash
cd /caminho/para/meu-projeto
mkdir -p .claude/hooks
cp ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/hooks/* .claude/hooks/
cp ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/settings.json .claude/settings.json
chmod +x .claude/hooks/*.sh
```

Exemplo de hook: `check-wrangler-version.sh` avisa quando Wrangler está
desatualizado antes de qualquer comando `wrangler`.

## Passo 4 — Primeiro uso concreto

### Cenário: configurar token Cloudflare para o projeto

1. **Inicializar o credential store** (uma vez por máquina):

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/init-store.sh
```

Cria `~/.claude/credentials/` com `.gitignore` paranoico e estrutura segura.

2. **Gerar API Token na Cloudflare**:

- Acesse https://dash.cloudflare.com/profile/api-tokens
- Crie um token com escopo mínimo necessário (ex: `Zone:DNS:Edit` para DNS-only)
- Copie o token

3. **Registrar no store** via skill interativa:

No Claude Code, digite: `"configure credenciais Cloudflare para conta pessoal"`.

A skill `cf-credentials-setup` vai guiar você por:

- Nickname da conta (ex: `pessoal`)
- Fonte de armazenamento (1Password/Keychain/arquivo)
- Coleta do Account ID e token
- Validação via `GET /user/tokens/verify`
- Gravação em `~/.claude/credentials/registry.json`

4. **Testar**:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/list.sh
```

Saída:

```
KEY                                      SOURCE     CREATED                        METADATA
---------------------------------------- ---------- ------------------------------ ---------
cloudflare.pessoal.api_token             op         2026-04-19T21:00:00Z           {"account_id":"..."}
```

5. **Usar em operação concreta** (listar zonas):

```bash
bash ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/skills/cf-api-call/scripts/call.sh \
  GET /zones --account=pessoal --format=pretty
```

## Passo 5 — Explorar mais

Agora que o toolkit está ativo, explore:

| Guia | Conteúdo |
|------|----------|
| [guides/credentials.md](./guides/credentials.md) | Cascata de fontes, rotação, cookbook completo |
| [guides/cloudflare.md](./guides/cloudflare.md) | DNS, WAF, Workers Builds, Analytics via API |
| [guides/releases.md](./guides/releases.md) | release-please vs manual, hooks, quality gate |
| [skills-catalog.md](./skills-catalog.md) | Todas as skills com triggers e exemplos |
| [architecture.md](./architecture.md) | Por que 3 categorias, anatomia de skill |

## Solução de problemas comuns

### "credencial X não registrada"

Você ainda não rodou `cf-credentials-setup` ou `cred-store-setup` para essa key.

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/list.sh
```

Se vazio, registre com a skill apropriada.

### "jq: command not found"

Instale jq:

```bash
brew install jq                    # macOS
apt-get install -y jq             # Debian/Ubuntu
```

### "op: not signed in"

```bash
op signin
```

Se configurou biometria (Touch ID), desbloqueie o 1Password app primeiro.

### Skill não é invocada pelo Claude Code

Verifique:

1. `SKILL.md` está em `<skill>/SKILL.md` (e não na raiz do diretório da skill)?
2. Frontmatter YAML do `description:` menciona palavras-chave que você usou?
3. Skills em `.claude/skills/<nome>/` (local) ou `~/.claude/skills/<nome>/` (global)?

Tente o comando de debug:

```bash
claude --list-skills 2>&1 | head -50
```

## Próximos passos

- Leia [architecture.md](./architecture.md) para entender a filosofia
- Copie skills relevantes ao seu projeto (não precisa copiar tudo)
- Adicione hooks conforme necessidade (CF Workers → `check-wrangler-version`)
- Explore o [skills-catalog.md](./skills-catalog.md) para descobrir skills

Dúvidas ou bugs: abra issue no [repositório upstream](https://github.com/JotJunior/claude-ai-tips/issues).
