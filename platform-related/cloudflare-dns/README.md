# platform-related/cloudflare-dns/

Skills para gestao de DNS via Cloudflare API v4 e wrangler. CRUD de records,
bulk operations, audit (SPF/DKIM/DMARC/DNSSEC), migracao de zona entre contas.

## Conteudo

| Recurso | Tipo | Descricao |
|---------|------|-----------|
| [`skills/dns-list-records/`](./skills/dns-list-records/) | skill | Lista records com paginacao (cursor-based, 100 por pagina) |
| [`skills/dns-add-record/`](./skills/dns-add-record/) | skill | Cria record DNS (A/AAAA/CNAME/MX/TXT/SRV/CAA) |
| [`skills/dns-update-record/`](./skills/dns-update-record/) | skill |PATCH parcial (procontent) ou PUT total (full replacement) |
| [`skills/dns-delete-record/`](./skills/dns-delete-record/) | skill | Remove record com confirmacao antes de aplicar |
| [`skills/dns-bulk-import/`](./skills/dns-bulk-import/) | skill | Import em batch: CSV (Zonefile format) ou BIND zone file |
| [`skills/dns-audit/`](./skills/dns-audit/) | skill | Revisa SPF/DKIM/DMARC/CAA/DNSSEC — reporta misconfiguracoes |
| [`skills/dns-migrate-zone/`](./skills/dns-migrate-zone/) | skill | Migra zona entre accounts CF (export + import + propagate) |

## API Reference

- **Base URL:** `https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records`
- **Auth:** Bearer token (API Token, nao Global API Key)
- **Scope:** `Zone:DNS:Edit` (por zona) ou `Zone:DNS:Read` (apenas leitura)
- **Rate limit:** 1200 req/5min por conta

## Conceitos-chave

- **Record types:** A, AAAA, CNAME, MX, TXT, SRV, CAA, SPF (deprecated)
- **Proxy status:** cloudflare proxy vs DNS only (nao proxied)
- **TTL:** auto (Cloudflare gerencia) ou valor fixo (1min a 1hr)
- **Pendencia propagation:** biasanya 30s-5min apos mudanca
- **DNSSEC:** assinatura DS no registro do registrador (nao no CF)

## Dependencias

- [`../cloudflare-shared/`](../cloudflare-shared/) — cf-api-call, cf-credentials-setup
- `jq` para parsing JSON
- `curl` para chamadas REST
- API Token com scope `Zone:DNS:Edit`

## Como invocar

```
"liste todos os records da zona example.com com tipo A e CNAME"
"adicione um record A para api.example.com apontando para 192.0.2.1"
"atualize o TTL do record MX para 3600"
"delete o record TXT antigo de verificacao"
"importe bulk de 200 records via CSV"
"audit DNS: verifique se SPF tem mais de 10 includes"
"migre a zona cliente.com para outra conta CF"
```

## Padroes-chave

- **API Token (nao Global Key):** scope por zona, audit trail
- **PATCH vs PUT:** usar PATCH para mudancas parciais (procontent)
- **Delete seguro:** dry-run obrigatorio antes de aplicar delete
- **Bulk operations:** rate limit awareness (1200/5min)
- **Audit SPF:** detectar >10 includes, ~all mechanisms deprecated
- **Migration:** export completo antes de deletar origem
- **DNSSEC:** validar DS record no registrador antes de ativar

## Ver tambem

- [`../cloudflare-shared/`](../cloudflare-shared/) — fundacao (cf-api-call)
- [`../cloudflare-workers/`](../cloudflare-workers/) — custom domains em workers
- [`../../global/skills/cred-store/`](../../global/skills/cred-store/) — gestao de credenciais
