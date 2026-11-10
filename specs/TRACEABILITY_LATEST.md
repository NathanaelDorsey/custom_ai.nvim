# TRACEABILITY_LATEST.md — Requirements Traceability Matrix

## Source
specs/release-plan.yaml — epic e01-vision-detection (Vision Capability Detection)

## Epic: e01-vision-detection
- WSJF: 85
- BCPs: 18
- Status: released
- All 32 tasks passing

## Story-to-Code Traceability

| Story ID | Story Title | Implementing Code | Tasks | Status |
|----------|-------------|-------------------|-------|--------|
| e01s01 | Tracer Bullet: Vision Detection at Startup | `lua/custom_ai/init.lua` — `detect_vision_capability()`, `check_server_on_startup()` integration | 7 | passing |
| e01s02 | Vision Detection on Model Switch | `lua/custom_ai/init.lua` — `switch_model()` defer_fn, keymap rebind | 6 | passing |
| e01s03 | Filename Pattern Fallback | `lua/custom_ai/init.lua` — `detect_vision_from_filename()`, `detect_vision_via_probe()` | 6 | passing |
| e01s04 | Keymap Gating & Warning | `lua/custom_ai/init.lua` — `setup_keymaps()` conditional bind, warning handler | 7 | passing |
| e01s05 | Config Schema Extension & Defaults | `lua/custom_ai/init.lua` — `vision_probe`, `vision_keywords` defaults | 6 | passing |

## Requirements-to-Code Traceability

| Req ID | Requirement | Story | Code Location | Verified |
|--------|-------------|-------|---------------|----------|
| REQ-001 | Plugin probes vision capability at startup when vision_probe=true | e01s01 | `check_server_on_startup()` → `detect_vision_capability()` | e01s01.t04 |
| REQ-002 | Probe sends test request with image_url content part | e01s01 | `detect_vision_via_probe()` | e01s01.t03 |
| REQ-003 | Probe timeout ≤ 500ms | e01s01 | `detect_vision_via_probe()` — curl -m 2, timeout 500 | e01s01.t03 |
| REQ-004 | state.detected_vision set based on probe result | e01s01 | `detect_vision_capability()` → `state.detected_vision` | e01s01.t02/t05 |
| REQ-005 | Startup notification includes vision status | e01s01 | `check_server_on_startup()` — "Vision: enabled/disabled" | e01s01.t05 |
| REQ-006 | detect_vision_capability() reusable from startup and switch | e01s02 | `detect_vision_capability(callback)` local function | e01s02.t01 |
| REQ-007 | Model switch calls vision detection after health check | e01s02 | `switch_model()` defer_fn callback | e01s02.t02 |
| REQ-008 | Switch notification includes vision status | e01s02 | `switch_model()` defer_fn callback | e01s02.t03 |
| REQ-009 | Chat buffer header updated with vision status | e01s02 / e01s04 | `write_to_buf()` in switch callback | e01s02.t04 |
| REQ-010 | Keymap gating: <leader>av bound only when vision=true | e01s04 | `setup_keymaps(buf, win, messages, detected_vision)` | e01s04.t01 |
| REQ-0011 | Vision warning when unsupported | e01s04 | Warning handler: "Vision not supported..." | e01s04.t02 |
| REQ-0012 | Chat header shows Vision: enabled/disabled | e01s04 | `chat()` / `new_chat()` header lines | e01s04.t04 |
| REQ-0013 | Keymap rebind on model switch | e01s04 | `switch_model()` → `setup_keymaps()` rebind | e01s04.t05 |
| REQ-0014 | vision_probe=true default | e01s05 | `defaults.vision_probe = true` | e01s05.t01 |
| REQ-0015 | vision_keywords defaults (6 LLaVA patterns) | e01s05 | `defaults.vision_keywords` array | e01s05.t02 |

## Code-to-Story Traceability

| Code Element | Story | Requirement |
|--------------|-------|-------------|
| `lua/custom_ai/init.lua` — `defaults.vision_probe` | e01s05 | REQ-0014 |
| `lua/custom_ai/init.lua` — `defaults.vision_keywords` | e01s05 | REQ-0015 |
| `lua/custom_ai/init.lua` — `state.detected_vision` | e01s01 | REQ-004 |
| `lua/custom_ai/init.lua` — `detect_vision_from_filename()` | e01s03 | REQ-010 |
| `lua/custom_ai/init.lua` — `detect_vision_via_probe()` | e01s01 | REQ-002/REQ-003 |
| `lua/custom_ai/init.lua` — `detect_vision_capability()` | e01s01/e01s02 | REQ-001/REQ-006 |
| `lua/custom_ai/init.lua` — `check_server_on_startup()` vision integration | e01s01 | REQ-001/REQ-005 |
| `lua/custom_ai/init.lua` — `switch_model()` vision detection | e01s02 | REQ-007/REQ-008 |
| `lua/custom_ai/init.lua` — `setup_keymaps()` conditional bind | e01s04 | REQ-010/REQ-0011 |
| `lua/custom_ai/init.lua` — `chat()` / `new_chat()` vision header | e01s04 | REQ-0012 |
| `lua/custom_ai/init.lua` — `switch_model()` keymap rebind | e01s04 | REQ-0013 |

## Verification Evidence

| Artifact | Path | Status |
|----------|------|--------|
| Startup detection verification | specs/verifications/e01s01-verify.yaml | PASS |
| Model switch detection verification | specs/verifications/e01s02-verify.yaml | PASS |
| Filename fallback verification | specs/verifications/e01s03-verify.yaml | PASS |
| Keymap gating verification | specs/verifications/e01s04-verify.yaml | PASS |
| Config schema verification | specs/verifications/e01s05-verify.yaml | PASS |
| Audit report | specs/verifications/AUDIT-e01-vision-detection.md | PASS |
| Security review | specs/security/REVIEW.md | PASS (no HIGH findings) |

## Gaps
None — all stories have code, all requirements have verification, all tasks passing.

Generated: 2026-01-10