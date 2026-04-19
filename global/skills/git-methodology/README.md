# git-methodology/

Hub de documentacao e referencias sobre metodologia git — releases, changelogs,
versionamento, commits, hooks e gates de qualidade pre-release. **Nao e skill
invocavel** — e o mapa mental que orienta escolhas entre as skills abaixo.

## Skills relacionadas

| Skill | Uso |
|-------|-----|
| [`release-please-setup`](../release-please-setup/) | Configura automacao via release-please (recomendado para projetos novos com CI) |
| [`release-manual-setup`](../release-manual-setup/) | Configura script caseiro `release.mjs` estilo clw-auth (controle fino) |
| [`changelog-write-entry`](../changelog-write-entry/) | Escreve entrada manual no CHANGELOG.md (formato Keep a Changelog) |
| [`git-hooks-install`](../git-hooks-install/) | Instala commit-msg + pre-commit customizados (enforce idioma, identidade) |
| [`release-quality-gate`](../release-quality-gate/) | Valida commits + testes + versao antes de criar release |

## Principios (convergentes nos projetos de referencia)

1. **Conventional Commits** — `type(scope): subject` com bodies ricos quando for
   `feat`, `fix` ou breaking change
2. **Semantic Versioning** — `MAJOR.MINOR.PATCH` com regra especial para 0.x
   (pre-1.0 trata minor como major)
3. **Keep a Changelog** — formato estruturado do `CHANGELOG.md`, secoes
   nomeadas (Added, Fixed, Changed, Breaking, Deprecated, Removed, Security)
4. **Changelog em EN-US** — mesmo em projetos com README/docs em PT-BR,
   commits e changelog em ingles (padrao internacional para open source)
5. **Body obrigatorio em feat/fix** — descrever o QUE mudou e o POR QUE, nao
   apenas o que. Minimo 20 caracteres. Breaking changes sempre tem body.
6. **Tags anotadas com SemVer** — `vX.Y.Z` (ou `<component>-vX.Y.Z` em
   monorepos). Cada tag = 1 commit `chore(release)` ou PR de release.
7. **Test release gate** — testes rodam antes de criar tag; release falha
   se algum teste falha
8. **Hooks git customizados** — commit-msg valida formato/idioma; pre-commit
   valida identidade e regras estaticas
9. **Nunca commit direto em main/master** — sempre via branch + PR
   (exceto `chore(release)` automatizado ou hotfix operacional justificado)

## Dois padroes de release — escolha segundo contexto

### Padrao A — release-please (automacao via GitHub Actions)

**Quando usar:**
- Projeto com CI ativo no GitHub Actions
- Repositorio publico ou privado com PR-based workflow
- Time de >1 pessoa ou disciplina de PR obrigatorio
- Monorepo com multiplos pacotes versionados independentemente

**Vantagens:**
- Zero trabalho manual — cada push em `main` abre/atualiza PR de release
- Links automaticos no CHANGELOG (github.com/compare/tag1...tag2)
- Suporte a `changelog-sections` customizadas (mapeia `feat` -> `### Added`)
- Atualiza `package.json`, `.release-please-manifest.json`, e `extra-files`
  (html, json, arquivos de i18n)
- Auto-merge possivel via workflow adicional

**Desvantagens:**
- Dependencia de GitHub Actions (vendor lock)
- Curva de aprendizado da config (release-please-config.json)
- Menos controle fino sobre formato (segue templates do tool)

**Exemplo real:** `md2pdf` ([ver](https://github.com/4i3n6/md2pdf))

### Padrao B — script caseiro release.mjs

**Quando usar:**
- Projeto pessoal ou de time pequeno sem CI complexo
- Controle fino sobre quality gates e formato do changelog
- Repositorio sem GitHub Actions ou com actions minimas
- Projeto pre-1.0 em iteracao rapida

**Vantagens:**
- Controle total sobre logica de parse, bump, changelog
- Testavel (test/release.test.mjs)
- Zero dependencia externa (so Node.js builtin)
- Execucao local (sem push pendente)

**Desvantagens:**
- Trabalho inicial de escrever o script
- Manutencao manual quando regras mudam
- Sem auto-merge — desenvolvedor faz o release explicitamente

**Exemplo real:** `clw-auth` ([ver](https://github.com/4i3n6/clw-auth))

### Comparativo rapido

| Aspecto | release-please | script manual |
|---------|----------------|---------------|
| Automacao | 100% (CI-driven) | parcial (dev invoca) |
| Dependencia | GitHub Actions + GitHub | Node.js built-in |
| Changelog | auto-gerado com links | auto-gerado local |
| Body quality gate | nao (use quality-gate separado) | embutido no script |
| Monorepo | suportado nativamente | precisa adaptar manualmente |
| Suporte a `0.x` | sim, mas trata minor como minor | sim, trata minor como major (opcional) |
| Overhead inicial | baixo (copy templates) | medio (adaptar script) |
| Custo por release | 0 (auto PR) | comando manual |

## Fluxo tipico de adocao

### Novo projeto

1. `/git-hooks-install` — garante convencional commits desde o inicio
2. Escolher padrao A ou B
3. `/release-please-setup` OU `/release-manual-setup`
4. `/release-quality-gate` — adiciona validacao pre-release

### Projeto existente sem versionamento

1. `/git-hooks-install` — comeca a enforcar commits bons
2. Escrever primeiro `CHANGELOG.md` retroativo (pode usar
   `/changelog-write-entry` repetido)
3. Tag manual v0.1.0 ou v1.0.0 conforme maturidade
4. Escolher padrao A ou B para daqui pra frente

### Projeto com versionamento ad-hoc

1. Auditar tags existentes — respeitam SemVer?
2. Verificar CHANGELOG — esta em formato KaC?
3. Se sim: adicionar `/release-quality-gate` pra daqui pra frente
4. Se nao: migrar progressivamente (changelog primeiro, versao depois)

## References disponiveis

- [`references/conventional-commits.md`](./references/conventional-commits.md) —
  tipos, scope, BREAKING CHANGE, exemplos
- [`references/keep-a-changelog.md`](./references/keep-a-changelog.md) —
  formato, secoes, semver, links
- [`references/semver.md`](./references/semver.md) — regras, 0.x especial,
  bump rules
- [`references/commit-body-quality.md`](./references/commit-body-quality.md) —
  quando body eh obrigatorio, tamanho minimo, o QUE vs o PORQUE

## Ver tambem

- [`global/skills/commit/`](../../../language-related/go/skills/commit/) —
  commit skill especifica de Go (padrao existente no toolkit)
- [README raiz do toolkit](../../../README.md)
