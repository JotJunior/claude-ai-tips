# Claude Code Usage Insights

Extracted from usage analysis (1,490 messages, 134 sessions, Mar-Apr 2026).
These insights capture recurring friction patterns and proven strategies.

## User Profile

Power user running marathon debugging sessions across full-stack multi-service
architectures (Go backends, React/TypeScript frontends, PostgreSQL). Primarily
problem-oriented — provides live errors, logs, and screenshots expecting rapid
diagnosis rather than upfront architecture planning. High tolerance for iteration
but low tolerance for wrong initial approaches that waste cycles.

## What Works Well

1. **Phased large refactors** — breaking massive work into discrete phases with
   sub-agents for parallel execution (e.g., 25+ page standardization, 49 Storybook stories)
2. **Multi-file debugging** — tracing bugs across backend Go, PostgreSQL, and React
   frontends until the full stack works end-to-end
3. **Systematic sub-agent delegation** — using Agent/Task tools for batched work
   across multiple services

## Top Friction Patterns

### 1. Cascading Multi-Service Bugs (most frequent)

**Problem**: Fixing one layer reveals the next — enum mismatches, DTO gaps,
field name inconsistencies chain across microservices.

**Mitigation**: Before implementing ANY fix in a multi-service system:
- Trace the complete data flow across ALL affected services
- Map DTOs, enums, field names at every boundary
- Identify ALL mismatches before writing any code
- Check: frontend API call -> backend handler/DTO -> DB schema/CHECK constraints

### 2. Wrong Initial Approach (34 instances)

**Problem**: Claude often starts with the wrong strategy — frontend fix when
the problem is backend, wrong query method, naive solution.

**Mitigation**:
- When fixing frontend issues, verify whether the fix should be backend-side first
- Ask which layer/service owns the responsibility before coding
- For domain-specific logic, confirm business rules before assuming

### 3. Stale Artifacts Causing Ghost Bugs

**Problem**: Stale __pycache__, compiled binaries, non-editable pip installs,
uncommitted changes not reaching staging, migration ordering issues.

**Mitigation**:
- Check for stale build artifacts before debugging
- Verify deployed version matches source code
- Confirm all changes are committed and pushed before testing in staging
- Check migration order and dependencies

## Proven Strategies

### Bug Fix Protocol

1. Reproduce or understand the error from description
2. Trace data flow across ALL involved microservices (DTOs, enums, field names)
3. Check for stale artifacts: __pycache__, compiled binaries, cached modules
4. Map ALL layers of the fix before implementing any changes
5. After implementing, grep entire codebase for residual references to old code
6. Run build/lint verification (go vet, go build, tsc --noEmit, golangci-lint)
7. Summarize: files changed, services affected, what to verify after deploy

### Fixing Approach

- Always check ALL references to changed code — don't leave residual references
- After find-replace or refactor, grep the entire codebase for old references
- When fixing frontend issues, verify backend-side first
- Don't overwrite complete files with minimal stubs

### Database Migrations

- Never run migrations without explicit user approval
- Always show migration SQL first and wait for confirmation
- Check existing FK constraints, data, and CHECK constraints
- Verify enum values in Go match PostgreSQL CHECK constraints exactly

### Code Conventions (Go + TypeScript)

- Ensure enum values in Go match PostgreSQL CHECK constraints exactly
- Ensure DTO field names match between frontend API calls and backend structs
- Verify imports are clean after refactoring (no leftover references)
- JSON tags: snake_case, DB tags: snake_case matching column names

## CLAUDE.md Recommendations

When applied to a new project, consider adding these sections:

```markdown
## Multi-Service Architecture
This is a monorepo with multiple microservices. When fixing bugs, always trace
the issue across ALL affected services before implementing a fix. Check DTOs,
enums, and field names match between services.

## Database Migrations
Never run database migrations directly without explicit user approval. Always
show the migration SQL first and wait for confirmation. Check for existing FK
constraints, existing data, and CHECK constraints.

## Bug Fix Protocol
When debugging, check for stale artifacts first. Do not overwrite complete files
with minimal stubs. When a fix reveals another issue, pause and map all remaining
layers before continuing.

## Fixing Approach
When implementing a fix, always check for ALL references to the changed code.
After find-replace or refactor, grep the entire codebase for old references.
When fixing frontend issues, verify whether the fix should be backend-side first.
```

## Advanced Patterns

### Parallel Agent Investigation

For complex multi-service bugs, launch parallel sub-agents:
- Agent 1: Backend contract audit (handlers, DTOs, migrations, enums)
- Agent 2: Frontend contract audit (API service files, hooks, component types)
- Agent 3: Migration & seed integrity check
- Synthesize findings before making any edits

### Test-Driven Bug Fix

For recurring buggy code output:
1. Write a failing test that captures the exact bug
2. Write edge case tests for correct expected behavior
3. Implement minimal fix, run tests after each change
4. Iterate autonomously until all tests pass
5. Run lint/build verification

### Pre-Deploy Verification

For each service check:
1. Git status clean, all changes committed and pushed
2. Migration files sequential, no FK conflicts
3. Build passes (go build / npm run build)
4. API contracts compatible between caller/callee services
5. Environment config complete (no missing vars)