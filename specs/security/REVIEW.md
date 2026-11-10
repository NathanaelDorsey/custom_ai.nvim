# Security Review — custom_ai.nvim

## Scope
Vision capability detection feature (epic e01-vision-detection), single-file change to `lua/custom_ai/init.lua`.

## Review Findings

### No HIGH findings

| Finding | Severity | Confidence | Status | Notes |
|---------|----------|------------|--------|-------|
| Temp file cleanup | Low | High | Fixed | `vim.fn.tempname()` + `os.remove()` in callback |
| Local server auth | Low | High | Accepted | Local llama-server without auth is pre-existing architecture |
| Image path traversal | Low | High | Accepted | User-provided path to `io.open()`, local-only, pre-existing for `send_prompt` |
| Command injection | None | N/A | N/A | `curl` invoked via argv array, no shell interpolation |

## Mitigations Applied
- All curl calls use argv array form (no shell interpolation)
- Temp files use `vim.fn.tempname()` (unpredictable names)
- Temp files cleaned in all callback paths (success + error)
- No conversation content or code logged via `vim.notify()`
- Model detection queries only `/v1/models` on configured host:port

## Exceptions
None required — no HIGH findings.

## Review Date
2026-01-10

## Reviewer
AI agent (request-review skill, dual-blind AND-gate PASS)