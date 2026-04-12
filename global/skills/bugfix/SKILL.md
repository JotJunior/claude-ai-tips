---
name: bugfix
description: |
  Structured bug fix protocol that traces issues across all affected layers
  before implementing fixes. Prevents cascading bugs in multi-service architectures.
  Triggers: "bugfix", "fix bug", "corrigir bug", "debug", "investigar bug".
argument-hint: "[description of the bug, error message, or screenshot path]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - Agent
  - TaskCreate
  - TaskUpdate
---

# Bug Fix Skill

Structured bug fix protocol derived from usage insights (134 sessions, 71 bug
fixes analyzed). Designed to eliminate cascading fix-reveal-fix cycles.

## Arguments

$ARGUMENTS should describe the bug: error message, observed behavior, expected
behavior, or path to a screenshot.

## Step 0: Determine Complexity

Assess bug scope before starting:

| Complexity | Signals | Approach |
|------------|---------|----------|
| **Single-layer** | Error in one file, one service | Sequential trace (Steps 1-8) |
| **Multi-service** | DTOs, enums, or events cross service boundaries | Parallel agent investigation (Step 3b) |
| **Ghost bug** | "Works on my machine", intermittent, post-deploy | Stale artifact focus (Step 2) |

For multi-service bugs, create tasks to track progress across services.

## Step 1: Understand the Bug

1. Read the error message or user description carefully
2. Identify which service/layer reported the error
3. If a screenshot was provided, analyze it
4. **Ask which layer owns the responsibility** before assuming where the fix goes
5. **For frontend-reported bugs**: verify whether the fix should be backend-side first — the most common wrong initial approach is fixing the frontend when the backend is the root cause

## Step 2: Check for Stale Artifacts

Before any debugging, eliminate ghost bugs:

```bash
# Go: verify binary is current (rebuild to be sure)
cd services/{service} && go build ./...

# Go: check for replaced modules that might be stale
go mod verify

# Node: check for stale builds
ls -la node_modules/.cache/ 2>/dev/null

# Check git status for uncommitted changes
git status --short

# Check if deployed version matches source (production bugs)
git log --oneline -3
```

If stale artifacts found, warn the user before proceeding.

## Step 3: Trace the Full Data Flow

**CRITICAL**: Do NOT fix any single layer yet. Map the complete path first.

For each affected entity/endpoint, trace through ALL layers:

### Backend (Go)
1. **Handler** — read the HTTP handler, check request parsing and response shape
2. **DTO** — check request/response structs, JSON tags, field names
3. **Service** — check business logic, enum values, validation
4. **Repository** — check SQL queries, schema prefix, column names
5. **Migration** — check table definition, CHECK constraints, enum types
6. **Events** — check RabbitMQ publisher payload matches consumer expectations

### Frontend (TypeScript)
1. **API service** — check endpoint URL, request body shape, field names
2. **Types** — check TypeScript types match backend DTOs (snake_case in requests)
3. **Hooks** — check TanStack Query key, request/response handling, transformResponse effects
4. **Component** — check data binding, error handling

### Cross-Service
1. **Inter-service clients** — check if other services call the affected endpoint
2. **RabbitMQ events** — check if the entity publishes/consumes events
3. **Shared enums** — check enum values match across Go, PostgreSQL, and TypeScript
4. **API Gateway / nginx** — check routing rules if 404/502 errors

### Step 3b: Parallel Agent Investigation (for multi-service bugs)

For complex bugs spanning 2+ services, launch parallel agents:

```
Agent 1: Backend contract audit
  - Read handlers, DTOs, migrations, enum CHECK constraints
  - List all field names and types at each boundary

Agent 2: Frontend contract audit
  - Read API service files, hooks, component types
  - List all field names and expected shapes

Agent 3: Event/messaging audit (if events involved)
  - Read publishers, consumers, event models
  - Verify routing keys and payload shapes
```

Synthesize findings from all agents BEFORE making any edits.

## Step 4: Identify ALL Mismatches

Create a list of every discrepancy found:
- Field name mismatches (e.g., `full_name` vs `fullName` vs `FullName`)
- Enum value mismatches (e.g., Go `ACTIVE` vs DB `active`)
- Missing fields in DTOs
- Wrong types (e.g., `string` vs `uuid.UUID`)
- Missing schema prefix in SQL queries
- Route ordering issues (static routes MUST come before `/:id`)
- JSON tag mismatches between Go structs and frontend expectations
- `transformResponse` camelCase conversion not accounted for
- Missing `omitempty` on optional pointer fields

## Step 5: Plan the Fix

Present the complete fix plan to the user BEFORE implementing:
- List every file that needs changes
- Describe what changes in each file
- Identify the correct order of changes
- Flag any migration needs (show SQL, never run without approval)

## Step 6: Implement

Apply changes in dependency order:
1. Database migrations (if needed) — show SQL, wait for approval
2. Backend domain/DTO changes
3. Backend service/repository changes
4. Backend handler changes
5. Frontend type changes
6. Frontend API/hook changes
7. Frontend component changes

**STOP-AND-REMAP RULE**: If implementing a fix reveals a new issue in another
layer, STOP immediately. Do not chase the new issue. Go back to Step 3, re-map
all remaining layers, update the fix plan, then continue. This prevents the
cascading fix-reveal-fix cycle that wastes the most time.

## Step 7: Verify

After implementing:

```bash
# Go: build all affected services
cd services/{service} && go build ./...

# Go: run tests
cd services/{service} && go test ./... -count=1 -timeout 60s

# Go: lint
cd services/{service} && golangci-lint run ./...

# Grep for residual references to old code
rg "oldPattern" --type go --type ts --type tsx

# Check for any leftover imports after refactor
cd services/{service} && go vet ./...
```

### Test-Driven Verification (for recurring or complex bugs)

When the bug is subtle or has regressed before:
1. Write a failing test that captures the exact bug scenario
2. Write edge case tests for correct expected behavior
3. Implement the minimal fix
4. Run tests — iterate until all pass
5. Run full lint/build verification

## Step 8: Summarize

```markdown
## Bug Fix Summary

**Bug**: {description}
**Root cause**: {what was actually wrong}
**Services affected**: {list}

### Changes
| File | Change |
|------|--------|
| path/to/file.go | Fixed field name from X to Y |
| ... | ... |

### Verify after deploy
- [ ] {what to check in staging/production}
```

## Important Rules

- **NEVER fix just one layer and declare done** — always trace the full path
- **NEVER run migrations** without showing SQL and getting user approval
- **When a fix reveals another issue, STOP and re-map** before continuing (Step 6 rule)
- **Always grep for residual references** after any rename/refactor
- **For frontend issues, check if the fix should be backend-side first** — this is the #1 wrong initial approach
- **Don't overwrite complete files with minimal stubs** — preserve existing code
- **Check struct fields match DB columns** — missing fields in scan targets cause silent bugs
- **Verify enum values match across Go, PostgreSQL CHECK constraints, and TypeScript** — mismatches are the most frequent multi-service bug