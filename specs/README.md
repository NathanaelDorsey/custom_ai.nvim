# Specs

All planning documents for this project.

## Structure

```
specs/
├── product/
│   ├── SCOPE_LATEST.yaml       # Project scope (in/out of scope)
│   ├── VISION_LATEST.yaml      # Product vision & principles
│   ├── GLOSSARY_LATEST.yaml    # Ubiquitous language
│   └── snapshots/              # Historical scope snapshots
├── tech-architecture/
│   ├── tech-stack.md           # Technology stack & architecture
│   ├── SECURITY_PLAN_LATEST.md # Threat model & mitigations
│   ├── TEST_PLAN_LATEST.md     # Manual test scenarios
│   ├── DESIGN_PLAN_LATEST.md   # Current & future design
│   ├── REFACTOR_LATEST.md      # Refactor opportunities
│   ├── IMPACT_LATEST.md        # Change impact analysis
│   └── adr/                    # Architecture Decision Records
├── epics/
│   └── archive/                # Completed epic capsules
├── verifications/              # UAT/verification records
├── bugs/
│   └── registry.yaml           # Bug tracking
├── release-plan.yaml           # Release sequence & WSJF
├── execution-status.yaml       # Epic execution tracking
├── planning-status.yaml        # Discover phase checklist
└── state.yaml                  # Session state & decisions
```

## Conventions

- **Never** write planning docs outside `specs/`
- **Always** update `state.yaml` when making significant decisions
- **LATEST** files are mutable; snapshots are immutable
- Epic capsules go in `epics/eNN-slug/` with `tasks.yaml` and `SPEC.md`
- ADRs in `tech-architecture/adr/ADR-NNN-title.md`