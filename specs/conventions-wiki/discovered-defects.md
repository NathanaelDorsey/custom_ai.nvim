# Discovered Defects

## Source
CONVENTIONS.md § Discovered Defects

## Fix-or-Log Ladder

When a test/lint/build gate fails on code you did not intend to change:

1. **quick-fix** — trivial data-only fix (config, typo, constant) — same commit if < 5 lines
2. **fix-bug** — non-trivial logic fix — separate commit, links to bug registry

**Never** commit over a red gate without fix-or-log.

## Enforced By
- quick-fix skill
- fix-bug skill
- verify-work (gate failure detection)

## Last Updated
2026-01-10