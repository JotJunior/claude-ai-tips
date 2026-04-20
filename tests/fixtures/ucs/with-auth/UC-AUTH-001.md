# UC-AUTH-001 — Autenticar usuario por senha

**Dominio**: AUTH
**Criticidade**: Alta
**Status**: Fixture de teste (sem implementacao)

## Objetivo

Fixture minimo para validar que `next-uc-id.sh AUTH` detecta este ID
existente e retorna o proximo disponivel (UC-AUTH-003 quando combinado
com UC-AUTH-002).

## Fluxo Principal

1. Usuario informa email/senha.
2. Sistema valida credenciais.
3. Sistema emite token de sessao.
