---
name: insights
description: |
  Aplica insights de uso do Claude Code ao projeto atual. Analisa o projeto,
  identifica quais insights sao relevantes e sugere melhorias no CLAUDE.md,
  hooks e workflows baseados em padroes de uso comprovados.
  Triggers: "aplicar insights", "apply insights", "usage insights",
  "melhorar claude.md", "improve workflow", "otimizar fluxo".
argument-hint: "[area especifica: bugfix | migrations | conventions | hooks | all]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

# Skill: Apply Usage Insights

Analyze the current project and apply relevant insights from usage patterns
to improve Claude Code effectiveness.

## Arguments

$ARGUMENTS should optionally specify a focus area:
- **bugfix** — Apply bug fix protocol and debugging improvements
- **migrations** — Apply database migration safety guidelines
- **conventions** — Apply code convention checks (enum/DTO matching)
- **hooks** — Suggest hooks for automated quality gates
- **all** — Full analysis and recommendations (default)

## Step 1: Load Insights

Read the insights file (search dynamically):
```bash
# Find insights file in user's .claude directory
ls ~/.claude/insights/
```

If the file is at `~/.claude/insights/usage-insights.md`, read it.
If not found, inform user and proceed with built-in best practices.

## Step 2: Analyze Current Project

1. Read the project's `CLAUDE.md` (if exists) to understand current state
2. Check `.claude/settings.json` or `.claude/settings.local.json` for existing hooks
3. Check for project-level skills in `.claude/skills/`
4. Identify project type:
   - **Go microservice**: check for `go.mod`, `internal/`, `migrations/`
   - **React/TypeScript frontend**: check for `package.json`, `src/`, `vite.config`
   - **Monorepo**: check for multiple services, submodules, `.gitmodules`
   - **Python**: check for `requirements.txt`, `pyproject.toml`

## Step 3: Gap Analysis

Compare what the project already has vs. what the insights recommend:

### 3.1 CLAUDE.md Gaps
Check if the project's CLAUDE.md includes:
- [ ] Multi-service architecture awareness (if monorepo)
- [ ] Database migration safety rules (if has migrations/)
- [ ] Bug fix protocol
- [ ] Fixing approach (residual references, backend-first)
- [ ] Code conventions (enum/DTO matching)

### 3.2 Hook Gaps
Check if `.claude/settings.json` or `.claude/settings.local.json` has hooks for:
- [ ] PostToolUse: build verification after editing Go/TS files (`go build ./...`)
- [ ] PreToolUse: route order check (Fiber/Express — `/:id` before static routes)
- [ ] PreToolUse: schema prefix check (SQL queries missing `schema.table`)
- [ ] Stop: uncommitted changes warning (with snooze pattern via /tmp file)
- [ ] Stop: missing test file warning (check for _test.go files)

### 3.3 Skill Gaps
Check if the project has relevant skills in `.claude/skills/`:
- [ ] /bugfix — structured bug fix protocol with parallel agent investigation
- [ ] /commit — conventional commits with submodule handling
- [ ] /review-pr — pre-PR quality gate (diff-aware)
- [ ] /review-service — service convention audit (read-only)
- [ ] /add-entity — CRUD vertical slice generator
- [ ] /add-migration — migration file generator
- [ ] /add-consumer — RabbitMQ consumer generator
- [ ] /add-test — test file generator with MockFunc pattern

### 3.4 Memory Gaps
Check if `~/.claude/projects/*/memory/` has relevant memories:
- [ ] Architecture patterns documented
- [ ] Common gotchas captured
- [ ] UX preferences recorded

## Step 4: Generate Recommendations

Based on the gap analysis, generate a prioritized list:

### Priority 1: CLAUDE.md Additions
For each missing section, propose the exact text to add, adapted to the
project's specific stack and structure. Do NOT add generic text — tailor it:
- Use the project's actual service names
- Reference the project's actual build commands
- Match the project's language and framework

### Priority 2: Hook Suggestions
For each missing hook, propose the exact JSON to add to settings.json.
Only suggest hooks relevant to the project's stack:
- Go projects: `go build ./...` after .go edits
- TypeScript: `tsc --noEmit` after .ts/.tsx edits
- SQL: schema prefix check for repository files

### Priority 3: Workflow Improvements
Based on the project's characteristics, suggest:
- Parallel agent patterns for multi-service debugging
- Test-driven fix workflows
- Pre-deploy verification checklists

## Step 5: Apply (with confirmation)

For each recommendation:
1. Show the user what will be added/changed
2. Wait for confirmation before applying
3. Apply changes via Edit/Write tools
4. Summarize what was applied

## Output Format

```markdown
# Insights Analysis: {project-name}

## Current State
- Project type: {type}
- CLAUDE.md: {exists/missing}
- Hooks: {count} configured
- Skills: {count} available

## Recommendations

### CLAUDE.md ({N} additions suggested)
1. **{section name}** — {why it's relevant}
   > {proposed text preview}

### Hooks ({N} suggestions)
1. **{hook name}** — {what it does}
   > {JSON preview}

### Workflows ({N} patterns)
1. **{pattern name}** — {when to use}

## Apply?
Reply with the numbers you want to apply, or "all" to apply everything.
```

## Important Notes

- This skill is **interactive** — it proposes changes and waits for confirmation
- Tailor all recommendations to the specific project (don't copy generic text)
- Skip recommendations the project already implements
- Focus on highest-impact items first (based on friction frequency in insights)
- If the project already has comprehensive CLAUDE.md and hooks, say so