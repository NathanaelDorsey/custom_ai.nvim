# Always Green / Shift Left

## Source
CONVENTIONS.md § Always Green / Shift Left

## Rationale
A defect caught in Preflight costs 1×. Caught in CI costs 10×. Caught in production costs 100×.

## Preflight Definition
Manual test in Neovim (`:lua require("custom_ai").chat()`) + verify no errors

## CI Definition
`gh pr checks` when PR is open

## Rules
- Preflight MUST be green before committing
- CI MUST be green before merging
- Reproducible gate failures (Preflight or CI) require **fix-or-log**: quick-fix → fix-bug
- NEVER dismiss a red gate as "pre-existing" or "out of scope"

## Banned Dismissive Phrases
| Phrase | Why Banned |
|--------|------------|
| "pre-existing" | You didn't check; fix or log |
| "unrelated to my changes" | Prove it with bisect or log it |
| "not introduced by my changes" | Bisect or log |
| "out of scope" | Scope includes gate integrity |

## Enforced By
- seed-conventions (generated this page)
- verify-work (Preflight gate)

## Last Updated
2026-01-10