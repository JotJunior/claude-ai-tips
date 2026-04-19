# Semantic Versioning — referencia

Especificacao: [semver.org/spec/v2.0.0](https://semver.org/spec/v2.0.0.html).

## Formato

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

Exemplos:

- `1.0.0` — release estavel
- `1.2.3` — release normal
- `2.0.0-alpha.1` — pre-release
- `2.0.0-rc.2` — release candidate
- `1.0.0+20240101` — metadata de build (raro)

## Regras de bump

Incrementar:

| Parte | Quando | Efeito |
|-------|--------|--------|
| **MAJOR** | Mudanca incompativel na API publica | Breaking change; consumidor precisa adaptar |
| **MINOR** | Nova funcionalidade backward-compatible | Consumidor pode ignorar |
| **PATCH** | Correcao backward-compatible | Consumidor deve atualizar sem risco |

**Sempre resetar partes a direita:**

- `1.2.3` + MAJOR = `2.0.0` (nao `2.2.3`)
- `1.2.3` + MINOR = `1.3.0` (nao `1.3.3`)
- `1.2.3` + PATCH = `1.2.4`

## Mapping com Conventional Commits

| Commit | Bump default |
|--------|--------------|
| `feat:` | MINOR |
| `fix:` | PATCH |
| `refactor:`, `perf:` | PATCH |
| `test:`, `docs:`, `style:`, `chore:`, `build:`, `ci:` | nenhum |
| `feat!:` ou `BREAKING CHANGE:` | MAJOR |

**Se multiplos commits desde ultima tag:** bump mais alto ganha.

Ex: 3 commits `fix` + 1 `feat` + 0 `breaking` = bump MINOR.

Ex: 0 `feat` + 10 `fix` + 1 `breaking` = bump MAJOR.

## Pre-release (0.x)

Versoes `0.x.y` indicam projeto em **desenvolvimento inicial**. A API
pode mudar a qualquer momento.

### Regra oficial SemVer

Durante 0.x, **nada e garantido**. Breaking changes podem vir em qualquer
bump minor. Consumidores devem pinar versao exata.

### Adaptacoes praticas

Projetos serios em 0.x frequentemente adotam uma destas convencoes:

#### Convencao A — "minor = major em 0.x"

```
0.9.5 -> 0.10.0  # breaking change (equivalente a major em 1.x+)
0.9.5 -> 0.9.6   # feat OR fix
```

Bump rule em `clw-auth/scripts/release.mjs`:

```javascript
function bump(version, type) {
  const pre = version.major === 0;
  if (type === 'major') return pre
    ? { major: 0, minor: version.minor + 1, patch: 0 }
    : { major: version.major + 1, minor: 0, patch: 0 };
  if (type === 'minor') return { major: version.major, minor: version.minor + 1, patch: 0 };
  return { major: version.major, minor: version.minor, patch: version.patch + 1 };
}
```

#### Convencao B — SemVer tradicional mesmo em 0.x

```
0.9.5 -> 1.0.0  # breaking change dispara salto para 1.0
0.9.5 -> 0.10.0 # feat
0.9.5 -> 0.9.6  # fix
```

Usada pela maioria de libs NPM. Apos 1.0.0, SemVer normal.

### Recomendacao

Em projeto novo que ainda esta explorando API: **Convencao A** (clw-auth
pattern) — reserva 1.0.0 para marco de estabilidade.

Em projeto novo que ja tem API consolidada: iniciar direto em **1.0.0**
e seguir SemVer tradicional.

## Pre-release (1.0+)

Formato: `X.Y.Z-<label>.<N>`

Labels comuns:
- `alpha.1`, `alpha.2` — desenvolvimento ativo, API instavel
- `beta.1`, `beta.2` — feature-complete, bugs esperados
- `rc.1`, `rc.2` — release candidate, estabilizacao final

Comparacao: `1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-beta < 1.0.0-rc.1 < 1.0.0`

Tags git: `v1.0.0-alpha.1`, `v1.0.0-beta.2`, `v1.0.0-rc.1`.

## Build metadata

```
1.0.0+20240101
1.0.0+sha.5114f85
```

Raro em projetos hobbistas. Comum em pipelines CI que querem trackear
hash do commit de build. **Nao afeta comparacao de versao**.

## Tags git

### Formato padrao

```
v1.2.3
v2.0.0-beta.1
```

Prefix `v` eh convencao. SemVer spec nao exige, mas GitHub releases e
ferramentas (release-please, npm version) assumem.

### Formato componente (monorepo)

```
md2pdf-v2.2.0
api-v1.5.0
cli-v0.3.1
```

Usado em monorepos onde cada pacote tem versao independente. release-please
suporta nativamente via `changelog-host` + `include-component-in-tag: true`.

### Tag anotada vs lightweight

**Sempre usar tag anotada** (`-a`):

```bash
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Anotadas incluem autor, data e mensagem — sao "commits" em si. Lightweight
sao apenas ponteiros e nao aparecem em `git describe` por default.

release-please e scripts caseiros criam anotadas automaticamente.

## Quando bumar o que

### Bump PATCH

- Correcao de bug que nao muda API
- Security patch
- Correcao de documentacao publicada
- Ajuste de performance interno

### Bump MINOR

- Nova funcionalidade na API publica (backward-compat)
- Nova opcao de configuracao
- Nova funcao/metodo/endpoint
- Deprecation de funcionalidade (aviso, nao remocao)

### Bump MAJOR

- Remocao de funcionalidade anunciada como deprecated
- Mudanca de signatura de funcao publica
- Remocao de field em resposta de API
- Mudanca em comportamento default que quebra consumidores
- Rename de arquivo/modulo public
- Upgrade de dependencia que quebra consumidor

## Dependencias e SemVer

Em `package.json`:

- `"dep": "^1.2.3"` — aceita `>=1.2.3 <2.0.0` (compativel)
- `"dep": "~1.2.3"` — aceita `>=1.2.3 <1.3.0` (so patch)
- `"dep": "1.2.3"` — pin exato
- `"dep": ">=1.2.3"` — qualquer versao a partir de 1.2.3
- `"dep": "*"` — qualquer versao (evitar)

Para bibliotecas publicadas: usar `^` ou `~` conforme sua confianca na
sem-veracidade da dependencia.

Para aplicacoes end-user: usar pin (`1.2.3`) ou lockfile (`package-lock.json`,
`bun.lock`, `pnpm-lock.yaml`) para reproducibilidade exata.

## Comparacao de versoes

Ordem:

```
1.0.0 < 1.0.1 < 1.1.0 < 1.10.0 < 2.0.0
```

Atencao: comparacao numerica por parte, nao lexicografica:

- `1.10.0 > 1.9.0` ✅
- `1.9.0 > 1.10.0` ❌ (errado)

Pre-release sempre < release:

```
1.0.0-alpha < 1.0.0-beta < 1.0.0-rc.1 < 1.0.0
```

Build metadata ignorada na comparacao:

```
1.0.0+build.1 == 1.0.0+build.2   (iguais pra SemVer)
```

## Tools

- [`semver` npm package](https://www.npmjs.com/package/semver) — parse e
  comparacao de versoes em JS
- [`@semantic-release/semantic-release`](https://github.com/semantic-release/semantic-release) —
  alternativa a release-please (mais opinativa)
- [git-tag](https://git-scm.com/docs/git-tag) — built-in
- [`standard-version`](https://github.com/conventional-changelog/standard-version) —
  deprecated, substituido por release-please

## Referencias

- [semver.org/spec/v2.0.0](https://semver.org/spec/v2.0.0.html)
- [Keep a Changelog](https://keepachangelog.com/) — usa SemVer como base
- [Conventional Commits](https://www.conventionalcommits.org/) — mapeia
  commits -> bump
- [npm semver calculator](https://semver.npmjs.com/) — visualiza faixas
