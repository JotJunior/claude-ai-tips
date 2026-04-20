# Extra-Files: Atualizar Versao em Arquivos Customizados

release-please pode atualizar versao em arquivos alem de `package.json`.

Vide tambem: [`../SKILL.md`](../SKILL.md)

## Sintaxe

```json
"extra-files": [
  { "type": "json", "path": "...", "jsonpath": "..." },
  { "type": "generic", "path": "..." }
]
```

## type: json

Usa JSONPath para atualizar campo especifico.

```json
{ "type": "json", "path": "manual/content.json", "jsonpath": "$.version" }
```

Arquivo `manual/content.json`:
```json
{
  "name": "my-app",
  "version": "1.2.3"
}
```

## type: generic

Procura primeira ocorrencia de versao e substitui. Funciona com markers ou sem.

### Com marker

```html
<!-- x-release-please-start-version -->
<meta name="version" content="1.0.0">
<!-- x-release-please-end -->
```

### Inline comment

```html
<meta name="version" content="1.0.0"><!-- x-release-please-version -->
```

### Sem marker (detectado por regex semver)

O generic procura por padrao `\d+\.\d+\.\d+` e substitui a primeira ocorrencia.

## Exemplos reais (projeto md2pdf)

```json
"extra-files": [
  { "type": "generic", "path": "index.html" },
  { "type": "generic", "path": "app.html" },
  { "type": "generic", "path": "pt/index.html" },
  { "type": "generic", "path": "manual/index.html" },
  { "type": "generic", "path": "src/i18n/en.ts" },
  { "type": "generic", "path": "src/i18n/pt.ts" },
  { "type": "json",    "path": "manual/content.json", "jsonpath": "$.version" }
]
```

## Arquivos comuns

| Tipo | Arquivo | Config |
|---|---|---|
| HTML | `index.html`, `app.html` | `generic` |
| i18n | `src/i18n/en.ts` | `generic` |
| JSON | `manual/content.json` | `json` + `jsonpath` |
| Badge markdown | `README.md` | `generic` |
| Constants | `src/constants.ts` | `generic` |

## Warnings

- Se o arquivo nao tem marker nem padrao semver detectavel, a substituicao nao ocorre.
- Versao antiga nao preservada — generic substitui a primeira ocorrencia de qualquer padrao semver.
