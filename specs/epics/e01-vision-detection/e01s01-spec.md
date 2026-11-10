# e01s01-spec.md — Tracer Bullet: Vision Detection at Startup

## §1 Business Narrative
When a user starts Neovim with a vision-capable model running, the plugin should automatically detect vision support and enable the vision keymap. When a text-only model is running, vision should be disabled with clear indication.

## §2 User Story
As a Neovim user running llama.cpp locally
I want the plugin to automatically detect if my current model supports vision
So that I don't have to manually configure or remember which model key enables vision features

## §3 Acceptance Criteria
- **AC1**: Fresh Neovim start with LLaVA model → notification shows "Vision: enabled"
- **AC2**: Fresh Neovim start with text-only model → notification shows "Vision: disabled"
- **AC3**: `state.detected_vision` reflects current model capability
- **AC4**: `vision_probe` config option controls API probe behavior (default: true)
- **AC5**: All existing startup behavior preserved (model detection, server health check)

## §4 Requirements (Delta: ADDED)
- REQ-001: **ADDED** — Plugin probes vision capability at startup when `vision_probe=true`
- REQ-002: **ADDED** — Vision probe sends minimal test request to `/v1/chat/completions` with `image_url` content part
- REQ-003: **ADDED** — Probe timeout ≤ 500ms (uses `curl -m` equivalent via `vim.system` timeout)
- REQ-004: **ADDED** — `state.detected_vision` set to true/false based on probe result
- REQ-005: **ADDED** — Startup notification includes vision status line

## §5 Main Flow
1. User starts Neovim
2. `check_server_on_startup()` called
3. Model detected via `/v1/models` (existing)
4. **NEW**: If `config.vision_probe` true, call `detect_vision_capability()`
5. **NEW**: `detect_vision_capability()` sends test request with dummy image_url
6. **NEW**: On success (200 OK, valid response) → `state.detected_vision = true`
7. **NEW**: On failure (400, 500, timeout) → `state.detected_vision = false`
8. **NEW**: Notification includes "Vision: enabled" or "Vision: disabled"

## §6 Alternative Flows
- **AF1**: `vision_probe=false` → skip API probe, `state.detected_vision = false` (fallback handled in e01s03)
- **AF2**: API probe times out → `state.detected_vision = false`, log warning
- **AF3**: Server not running → existing "no model running" notification, `state.detected_vision = false`

## §7 Error Handling
- Probe network error → treat as vision unavailable, warn once
- Probe returns 400 (bad request) → vision not supported, `detected_vision = false`
- Probe returns 500 → server error, `detected_vision = false`, warn
- JSON decode error → `detected_vision = false`, warn

## §8 Non-Functional
- **Performance**: Probe adds ≤ 500ms to startup
- **Reliability**: No blocking calls; all via `vim.system` callbacks
- **Compatibility**: Works with any OpenAI-compatible llama.cpp server

## §9 Traceability
- Scope: `specs/product/SCOPE_LATEST.yaml` → in_scope items 1, 4, 7
- Epic: `specs/epics/e01-vision-detection/epic.yaml` → e01s01
- Tests: `specs/tech-architecture/TEST_PLAN_LATEST.md` → scenarios 1, 2

## §10 Configuration
```lua
defaults = {
  -- ... existing ...
  vision_probe = true,
  vision_keywords = {"llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision"},
}
```

## §11 State Changes
```lua
state = {
  -- ... existing ...
  detected_vision = false,  -- NEW
}
```

## §12 Gherkin Scenarios
```gherkin
Scenario: Vision model detected at startup
  Given llama.cpp server running with LLaVA model
  And vision_probe = true
  When Neovim starts
  Then notification shows "Vision: enabled"
  And state.detected_vision == true

Scenario: Text model detected at startup
  Given llama.cpp server running with Qwen model
  And vision_probe = true
  When Neovim starts
  Then notification shows "Vision: disabled"
  And state.detected_vision == false
```