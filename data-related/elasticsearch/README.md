# data-related/elasticsearch/

Skills para Elasticsearch 8.x. Mapping design, query DSL, aggregations,
bulk indexing, reindex zero-downtime, version migration, logging patterns.

## Skills

| Skill | Trigger principal | O que faz |
|-------|-------------------|-----------|
| [`es-mapping-design/`](./skills/es-mapping-design/) | `"mapping"` | text/keyword + multi-fields + analyzer custom |
| [`es-query-build/`](./skills/es-query-build/) | `"query"` | bool query (must/should/filter/must_not) |
| [`es-aggregations/`](./skills/es-aggregations/) | `"agg"` | terms/date_histogram/metrics + pipeline aggs |
| [`es-bulk-index/`](./skills/es-bulk-index/) | `"bulk index"` | NDJSON format + retry per-item + batching |
| [`es-reindex-zero-downtime/`](./skills/es-reindex-zero-downtime/) | `"reindex"` | reindex + alias swap para zero-downtime |
| [`es-version-migrate/`](./skills/es-version-migrate/) | `"upgrade es"` | 7→8/8→9 migration + breaking changes |
| [`es-logging-pattern/`](./skills/es-logging-pattern/) | `"logging"` | data stream + ILM + ECS format |

## Conceitos-chave

- **Index:** documento agrupado com mapping propio
- **Mapping:** esquema dos campos (type, analyzer, format)
- **Document:** JSON record com _id unico
- **Query DSL:** bool, match, term, range, exists, geo
- **Aggregations:** metrics, bucketing, pipeline
- **Alias:** nome logico que aponta para index (ou varios)
- **ILM:** Index Lifecycle Management (hot/warm/cold/delete)
- **API key:** autenticacao (basic auth deprecated desde 8.x)

## Stack

- **Elasticsearch:** 8.x (7.x compatibility mode available)
- **Clients:** @elastic/elasticsearch-js ou low-level fetch
- **Ingest:** bulk API, percolator, ingest pipelines
- **Search:** query context vs filter context
- **ECS:** Elastic Common Schema para format de logs

## Como invocar

```
"crie mapping para indice de produtos com text search e keyword facets"
"build query: filtro por categoria E range de preco"
"aggs: terms por marca + date_histogram por mes + avg price"
"bulk index: 10k docs com retry individual por item falho"
"reindex zero-downtime: migre indice antigo para novo schema"
"upgrade: migrate de 7.17 para 8.x com breaking changes"
"logging: configure data stream com ILM para logs de aplicacao"
```

## Padroes-chave

- **Keyword para faceting:** nao usar text para agregacoes/ordenacao
- **Multi-fields:** text (search) + keyword (sort/facet) juntos
- **Bool filter vs must:** filter nao scored, mais rapido
- **Bulk batching:** 5-10MB por bulk request, nao mais
- **Alias swap:** reindex → alias update atomico = zero-downtime
- **ILM policy:** hot→warm→cold→delete com age thresholds
- **ECS format:** campos padronizados (log.level, message, etc.)
- **API key auth:** usar API key em vez de basic auth
- **Source filtering:** _source: false quando nao precisa do documento

## Ver tambem

- [`../../platform-related/cloudflare-workers/`](../../platform-related/cloudflare-workers/) — logging com Workers
- [`../../global/skills/cred-store/`](../../global/skills/cred-store/) — gestao de credenciais
