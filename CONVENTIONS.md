# CONVENTIONS.md — Project Conventions for custom_ai.nvim

This document defines the mandatory conventions for all AI agents working on this project.

## § Always Green / Shift Left

**Rationale:** A defect caught in Preflight costs 1×. Caught in CI costs 10×. Caught in production costs 100×.

**Preflight** = Manual test in Neovim (`:lua require("custom_ai").chat()`) + verify no errors

**CI** = `gh pr checks` when PR is open

**Rules:**
- Preflight MUST be green before committing
- CI MUST be green before merging
- Reproducible gate failures (Preflight or CI) require **fix-or-log**: quick-fix → fix-bug
- NEVER dismiss a red gate as "pre-existing" or "out of scope"

**Banned dismissive phrases:**
| Phrase | Why banned |
|--------|------------|
| "pre-existing" | You didn't check; fix or log |
| "unrelated to my changes" | Prove it with bisect or log it |
| "not introduced by my changes" | Bisect or log |
| "out of scope" | Scope includes gate integrity |

## § Discovered Defects

When a test/lint/build gate fails on code you did not intend to change:

1. **quick-fix** — trivial data-only fix (config, typo, constant) — same commit if < 5 lines
2. **fix-bug** — non-trivial logic fix — separate commit, links to bug registry

**Never** commit over a red gate without fix-or-log.

## § Defensive Code Categories

Apply these patterns at system boundaries:

| Category | Implementation |
|----------|----------------|
| **Graceful degradation** | Server may not run — detect via `curl -m 2`, show startup scripts, allow manual switch |
| **Timeout** | All `curl` calls use `-m <seconds>`; chat requests have reasonable deadlines |
| **Retry** | Message queue processes requests sequentially; failed requests stay in queue |
| **Circuit breaker** | Detect server death via failed health check; notify user, allow manual restart |

## § Neovim Plugin Conventions

- **Single entry point**: `lua/custom_ai/init.lua` returns module table
- **Configuration**: `setup(opts)` with `vim.tbl_deep_extend("force", defaults, opts)`
- **State**: Module-local tables (`state`, `config`) — no global variables
- **Async only**: Network via `vim.system()` with callbacks — NEVER `vim.fn.system()` blocking
- **Buffer-local keymaps**: Set inside chat buffer only, cleaned up on close
- **Floating windows**: `relative="editor"`, `style="minimal"`, `border="rounded"`
- **Read-only chat buffer**: `modifiable=false`, `readonly=true` except when writing
- **Error handling**: `vim.notify()` with appropriate log level (INFO/WARN/ERROR)
- **Temp files**: Use `vim.fn.tempname()` for large payloads (base64 images)
- **Model detection**: Query `/v1/models` endpoint, match filename to config keys

## § Code Style

- Indent: 2 spaces (Lua standard)
- Functions: `local function name()` for private, `function M.name()` for public
- Tables: trailing commas in multi-line
- Strings: double quotes preferred
- Comments: `--` for inline, `--[[ ]]` for blocks
- No external dependencies beyond Neovim stdlib + `curl` in PATH

## § Git / Commit

- Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- Scope: `custom_ai` (e.g. `feat(custom_ai): add vision support`)
- One logical change per commit
- Reference specs/ files when implementing planned work

## § Specs Directory

All planning output goes to `specs/`:

```
specs/
├── product/
│   ├── SCOPE_LATEST.yaml
│   ├── VISION_LATEST.yaml
│   └── GLOSSARY_LATEST.yaml
├── tech-architecture/
│   ├── tech-stack.md
│   ├── SECURITY_PLAN_LATEST.md
│   ├── TEST_PLAN_LATEST.md
│   ├── DESIGN_PLAN_LATEST.md
│   ├── REFACTOR_LATEST.md
│   └── IMPACT_LATEST.md
├── epics/
│   └── archive/
├── verifications/
├── bugs/
│   └── registry.yaml
├── release-plan.yaml
├── execution-status.yaml
├── planning-status.yaml
└── state.yaml
```

**Never** write planning docs outside `specs/`.
**Never** edit `state.yaml.lock` — acquired/released dynamically.