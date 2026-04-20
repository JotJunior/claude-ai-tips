# UC-AUTH-001 — Fixture multi-domain (AUTH)

Fixture de teste. Existe apenas para preencher o dominio AUTH na
estrutura multi-domain e garantir que `next-uc-id.sh` filtra por
dominio corretamente (ex: `next-uc-id.sh CAD` deve ignorar este UC
e retornar o proximo do dominio CAD, nao do AUTH).
