# Secoes e Formatos — Keep a Changelog

Guia de referencia para secoes e formatos do [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

## Secoes canonicas (ordem obrigatoria)

### Added

Nova funcionalidade adicionada.

```markdown
### Added

- **Add OAuth PKCE flow** \u2014 Replaces deprecated implicit flow. PKCE
  eliminates the need for client secrets in public clients.
- **Add rate limiting middleware**
```

### Changed

Mudanca em funcionalidade existente, sem quebrar compatibilidade.

```markdown
### Changed

- **Update dependencies to latest stable versions**
- **Refactor auth handler for better error messages**
```

### Deprecated

Funcionalidade marcada para remocao futura. Usuarios devem migrar.

```markdown
### Deprecated

- **Implicit OAuth flow** \u2014 will be removed in 2.0. Use PKCE instead.
```

### Removed

Funcionalidade removida nesta release (ja foi deprecated ou era insegura).

```markdown
### Removed

- **Remove legacy v1 API endpoints** \u2014 superseded by v2.
```

### Fixed

Correcao de bug ou vulnerabilidade.

```markdown
### Fixed

- **Fix null dereference in auth handler** \u2014 caused crash on expired tokens.
- **Fix CORS preflight race condition**
```

### Security

Correcao de vulnerabilidade de seguranca.

```markdown
### Security

- **Patch XSS in comment renderer** \u2014 CVE-2026-1234. Upgrade immediately.
```

## Secoes extras (usar se projeto ja as utiliza)

### Breaking Changes

Destaque para mudancas que quebram compatibilidade. Posicionada
**antes de Added** para visibilidade.

```markdown
### Breaking Changes

- **Remove `--old-flag` CLI option** \u2014 incompatible with new architecture.
```

### Performance

Otimizacao de performance.

```markdown
### Performance

- **Reduce cold start latency by 40%** \u2014 cached dependency resolution.
```

### Tests

Adicao ou mudanca de testes.

```markdown
### Tests

- **Add integration tests for OAuth PKCE flow**
```

### Documentation

Atualizacao de documentacao.

```markdown
### Documentation

- **Update API reference for v2 endpoints**
```

## Formato de uma entrada

### Com body (formato canonico Keep a Changelog)

```markdown
- **<title>** \u2014 <description in single paragraph>
```

Exemplo:

```markdown
- **Add OAuth PKCE flow** \u2014 Replaces deprecated implicit flow. PKCE
  eliminates the need for client secrets in public clients and is
  required by Anthropic's OAuth 2.1 specification.
```

### Sem body (titulo auto-explicativo)

```markdown
- **Add OAuth PKCE flow**
```

## Formatos avancados

### Links de comparacao (diff/compare)

```markdown
- **Add feature** \u2014 ([diff](https://github.com/owner/repo/compare/v1.0.0...v1.1.0))
- **Remove deprecated endpoint** \u2014 ([compare](https://github.com/owner/repo/compare/v2.0.0...v3.0.0))
```

### Link para commit ou PR

```markdown
- **Fix auth bug** \u2014 ([#42](https://github.com/owner/repo/issues/42))
- **Add PKCE support** \u2014 ([PR #55](https://github.com/owner/repo/pull/55)) ([abc1234](https://github.com/owner/repo/commit/abc1234))
```

### Agrupamento por escopo

```markdown
### Added

- **auth:** add OAuth PKCE flow
- **auth:** deprecate implicit flow
- **api:** add rate limiting middleware
```

### Breaking changes com destaque

```markdown
### Breaking Changes

- **Remove `--old-flag`** \u2014 Use `--new-flag` instead. Migration:
  ```bash
  migrate.sh --from-old-flag
  ```
```

## Ordem das secoes (canonical)

1. Added
2. Changed
3. Deprecated
4. Removed
5. Fixed
6. Security

Extras (quando presentes no projeto): Breaking Changes (antes de Added),
Performance, Tests, Documentation.

## Data de versao

Formato: `YYYY-MM-DD` (ISO 8601). Nao usar variantes.

```markdown
## [1.2.0] - 2026-04-19
```

## Link de volta

← [Voltar para SKILL.md](../SKILL.md)
