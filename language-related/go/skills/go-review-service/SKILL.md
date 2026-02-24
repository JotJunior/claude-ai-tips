---
name: go-review-service
description: Audit a GOB Go microservice against all project conventions and patterns
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Go Review Service

Perform a comprehensive read-only audit of a GOB Go microservice, checking 14 conventions. Outputs a structured PASS/FAIL/WARNING report with line references.

## Trigger Phrases

"review service", "audit service", "validar servico", "check service", "verificar servico", "checar servico"

## Arguments

$ARGUMENTS should specify:
- **Service name** (e.g., `gob-member-service`) — required
- **Focus area** (optional) — e.g., "middleware", "routes", "repository" to narrow the audit

## Pre-Flight

Determine the service root:
```
services/{service-name}/
```

Read these files first (in parallel where possible):
1. `cmd/api/main.go` — middleware order, wiring, shutdown
2. `internal/factory/factory.go` — repository factory
3. `internal/repository/repository.go` — interfaces
4. `internal/handler/*.go` — route registration
5. `go.mod` — module path, dependencies
6. `migrations/` — list files for schema reference

## Checks (14 total)

For each check, output one of:
- **PASS** — convention followed correctly
- **FAIL** — convention violated (include file:line reference and what's wrong)
- **WARNING** — partially followed or uncertain (include details)
- **N/A** — not applicable to this service

---

### Check 1: Middleware Order in main.go

**Expected order** (top to bottom in main.go):
1. `recover.New()`
2. `requestid.New()`
3. `nrfiber.Middleware(nrApp)` — after requestid, before logging
4. `middleware.LoggingWithLogger(log)` or `middleware.Logging()`
5. `cors.New(...)` — with AllowOrigins, AllowHeaders, AllowMethods, AllowCredentials
6. `middleware.DryRun(...)` — if service supports dry-run
7. `middleware.DryRunFinalizer()` — if dry-run present
8. `middleware.AuditPublisher(...)` — after cors/dryrun, before endpoints

**Search**: Look for `app.Use(` calls in main.go. Verify order matches.

### Check 2: Audit Middleware

- Separate RabbitMQ connection (`rabbitmq.NewFromURL`)
- Uses `middleware.AuditExchange` constant
- Non-blocking: wrapped in `if rmqURL != ""` with warning on failure
- Placed AFTER cors and BEFORE health/ready/version endpoints
- `defer auditRMQ.Close()` present

**Search**: `AuditPublisher` in main.go.

### Check 3: New Relic APM

- `observability.NewRelicApp(serviceName, cfg, log)` called
- Conditional `nrfiber.Middleware(nrApp)` (only if nrApp != nil)
- `defer observability.ShutdownNewRelic(nrApp)` present
- Placed after `requestid` and before `logging` middleware

**Search**: `NewRelicApp`, `nrfiber`, `ShutdownNewRelic` in main.go.

### Check 4: Route Registration Order

For each handler's `RegisterRoutes()` method:
- Static routes (e.g., `/types`, `/counts`, `/search`) MUST come BEFORE parameterized routes (`/:id`)
- Sub-groups (e.g., `/groups`) MUST be registered BEFORE `/:id` catch-all

**FAIL if**: Any `/:id` or `/:param` route appears before a static route at the same level.

**Search**: All `RegisterRoutes` methods in `internal/handler/`.

### Check 5: Repository Interfaces

- `context.Context` is the first parameter in every method
- `FindByID` returns `(*domain.X, error)` — nil/nil when not found
- Filter structs exist for List methods
- Count methods present where List exists
- Interfaces are in `internal/repository/repository.go`

**Search**: `repository.go` file, look for interface definitions.

### Check 6: Postgres Implementation

- Uses `GetContext` (single row) and `SelectContext` (multiple rows)
- `sql.ErrNoRows` returns `nil, nil` (not wrapped as error)
- Schema prefix on all table references (e.g., `member.members`)
- Uses `$1, $2, ...` positional parameters (not `?`)
- Row structs with `db:""` tags separate from domain structs
- `toDomain()` converter methods on row structs

**Search**: `internal/repository/postgres/*.go` files.

### Check 7: Service Error Patterns

- Package-level sentinel errors: `var ErrXxxNotFound = errors.New("...")`
- No HTTP status codes in service layer
- Services return domain objects, not DTOs
- Constructor accepts repository interfaces (not concrete types)

**Search**: `internal/service/*.go` files, look for `var Err` and return types.

### Check 8: Handler Error Dispatch

- Uses `errors.Is()` for sentinel error matching
- Returns `dto.ErrorResponse` with appropriate HTTP status codes
- Claims extraction via `middleware.GetUserID(c)`, `middleware.GetClaims(c)`
- Proper `c.Status(xxx).JSON(dto.ErrorResponse{...})` pattern

**Search**: `internal/handler/*.go` for `errors.Is` and `ErrorResponse`.

### Check 9: Factory Pattern

- `Repositories` struct holds all repo instances
- `NewRepositories(db)` constructor creates all repos
- `NewDryRunRepositories(db)` for dry-run mode (if applicable)
- Getter methods for each repository
- `RepositoryFactory` with `isDryRun` flag (if dry-run supported)

**Search**: `internal/factory/factory.go`.

### Check 10: JSON/DB Tag Conventions

- JSON tags: `snake_case` (e.g., `json:"lodge_id"`)
- DB tags: `snake_case` matching column names (e.g., `db:"lodge_id"`)
- `omitempty` on optional/nullable fields
- `db:"-"` on computed/relation fields
- No `json:"-"` on fields that should be visible in API

**Search**: Domain structs in `internal/domain/*.go`, check tags.

### Check 11: Health/Ready/Version Endpoints

All three must be present:
- `GET /health` — returns 200 OK
- `GET /ready` — pings DB (`db.PingContext`) and returns health status
- `GET /version` — returns service version info

**Search**: `/health`, `/ready`, `/version` in main.go.

### Check 12: Fiber Configuration

- `EnableTrustedProxyCheck: true`
- `TrustedProxies` configured (e.g., private network ranges)
- `ProxyHeader: "X-Real-Ip"` or `"X-Forwarded-For"`
- These are in `fiber.Config{}` in main.go

**Search**: `fiber.New(` or `fiber.Config` in main.go.

### Check 13: Graceful Shutdown

- Signal handling: `signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)`
- Context cancellation for background goroutines
- Consumer stop (`consumer.Stop()`) if RabbitMQ consumer exists
- Server shutdown: `app.ShutdownWithContext(ctx)` or `app.Shutdown()`
- Deferred resource cleanup (DB close, RabbitMQ close, New Relic shutdown)

**Search**: `signal.Notify`, `Shutdown`, `defer` in main.go.

### Check 14: go.mod Module Path

- Must follow pattern: `github.com/gob/gob-{service-name}`
- Example: `github.com/gob/gob-process-service`
- Go version should be 1.21+

**Search**: First line of `go.mod`.

---

## Output Format

```
# Service Audit: {service-name}
Date: {current date}

## Summary
PASS: X/14 | FAIL: Y/14 | WARNING: Z/14 | N/A: W/14

## Results

### 1. Middleware Order
**PASS** — Correct order: recover → requestid → nrfiber → logging → cors → dryrun → audit
(main.go:45-82)

### 2. Audit Middleware
**FAIL** — Missing separate RabbitMQ connection. Audit reuses existing connection.
(main.go:95)

### 3. New Relic APM
**WARNING** — nrfiber middleware not conditional on nrApp != nil
(main.go:52)

... (continue for all 14 checks)

## Recommendations
1. [Highest priority fixes]
2. [Medium priority improvements]
3. [Low priority suggestions]
```

## Important Notes

- This skill is **read-only** — it does NOT modify any files
- Always provide file:line references for FAIL and WARNING results
- When a check has sub-items, list which sub-items pass and which fail
- If the service doesn't have certain features (e.g., no RabbitMQ consumer), mark related checks as N/A
- Focus on actual convention violations, not style preferences