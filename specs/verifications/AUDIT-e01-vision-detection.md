# Audit Report — Epic e01-vision-detection

## Summary

**Gate: PASS** — All 32 tasks across 5 stories passing. All static verify commands pass. Headless Neovim E2E tests pass with vision server (LLaVA-Next at 127.0.0.1:9931). `luac -p` syntax check passes.

## Checklist Results

| Section | Status | Details |
|---------|--------|---------|
| Supply Chain & Security | ✅ PASS | No new external deps; no secrets; no injection vectors (curl argv array) |
| Provenance & Metadata | ⚠️ MEDIUM | YAML artefacts lack explicit `type:`/`context:` metadata |
| Law of Demeter | ✅ PASS | No method chains through unrelated objects |
| CONVENTIONS.md Compliance | ✅ PASS | All output in specs/; no gh REST API; no secrets |
| Scope | ✅ PASS | Changes limited to vision capability detection |
| Boy Scout Rule | ⚠️ MEDIUM | 4x duplicated `detect_vision_capability()` consolidated into 1 |
| Types and Safety | ✅ PASS | Lua is dynamically typed; no type-bypass casts |
| Test Coverage | ⚠️ MEDIUM | Manual headless Neovim E2E (consistent with CONVENTIONS.md) |
| SOLID / Heuristics | ⚠️ MEDIUM | Async callback style; config-driven design |

## Code Smells Fixed

| Smell | Severity | Location | Resolution |
|-------|----------|----------|------------|
| Duplicated Code (G5) | MEDIUM | `detect_vision_capability()` in 4 worktrees | Consolidated into single implementation in main repo |
| Long Function (G30) | MEDIUM | `detect_vision_capability()` ~70 lines | Split into `detect_vision_from_filename()`, `detect_vision_via_probe()`, `detect_vision_capability()` |
| Blocking Call | HIGH | `vim.system(...):wait()` in startup path (e01s03) | Converted to async callback via `vim.system()` + `vim.schedule()` |
| Hardcoded Model Check | MEDIUM | `key == "vision"` (e01s02) | Replaced with `config.vision_keywords` filename matching |

## Required Fixes Applied

1. **Consolidated `detect_vision_capability()`**: Single implementation with API probe first, filename fallback second, async callback pattern
2. **Removed blocking `:wait()`**: All detection now uses async `vim.system()` callbacks with `vim.schedule()`
3. **Split long functions**: `detect_vision_capability()` delegates to `detect_vision_via_probe()` and `detect_vision_from_filename()`
4. **Replaced hardcoded key check**: Uses `config.vision_keywords` for filename matching instead of `key == "vision"`

## Verification Evidence

- `specs/verifications/e01s01-verify.yaml` — Startup detection
- `specs/verifications/e01s02-verify.yaml` — Model switch detection
- `specs/verifications/e01s03-verify.yaml` — Filename fallback
- `specs/verifications/e01s04-verify.yaml` — Keymap gating
- `specs/verifications/e01s05-verify.yaml` — Config schema

## Gate Verdict

**PASS** — Ready for `request-review` (independent code review).