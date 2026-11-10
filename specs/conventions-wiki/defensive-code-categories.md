# Defensive Code Categories

## Source
CONVENTIONS.md § Defensive Code Categories

## Categories

| Category | Implementation |
|----------|----------------|
| **Graceful degradation** | Server may not run — detect via `curl -m 2`, show startup scripts, allow manual switch |
| **Timeout** | All `curl` calls use `-m <seconds>`; chat requests have reasonable deadlines |
| **Retry** | Message queue processes requests sequentially; failed requests stay in queue |
| **Circuit breaker** | Detect server death via failed health check; notify user, allow manual restart |

## Enforced By
- seed-conventions (documented in CONVENTIONS.md)
- verify-work (runtime verification)

## Last Updated
2026-01-10