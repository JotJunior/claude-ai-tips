# Troubleshooting

## Erros comuns

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `erro: credencial 'X' nao registrada` | Key não existe em `registry.json` | `bash .../list.sh` para ver registradas; `/cred-store-setup <key>` para registrar |
| `1Password trancado — execute: op signin` | Sessão do op expirou | `op signin` (ou desbloqueia app com biometria) |
| `entry nao encontrada no keychain: X` | Service name errado ou credencial apagada | `security find-generic-password -s <service>` para debugar |
| `erro: <path> tem permissoes 644` | `chmod` do arquivo não é `600` | `chmod 600 <path>` |
| `erro: <path> eh um symlink` | Symlink em `files/` (rejeitado) | Copiar arquivo real (não symlink) ou usar source=op/keychain |
| `erro: jq e obrigatorio` | `jq` não instalado | `brew install jq` ou `apt-get install jq` |
| `registry.json` corrompido (JSON inválido) | Edição manual errada | Restaurar backup ou rodar `init-store.sh --force` e re-registrar |
| `audit.log` crescendo indefinidamente | Sem rotação automática | Rotacionar manualmente (ver cookbook) |
| `op: session expired, please sign in again` | Sessão longa expirou mid-operação | `op signin` e retry |
| Erro CF 10000 após resolve ok | Token inválido ou revogado | Criar novo no dashboard, rotacionar (ver cookbook) |
| Erro CF 10001 após resolve ok | Token sem escopo na conta alvo | Recriar token com escopo correto |

---

Voltar para: [README.md](./README.md)
