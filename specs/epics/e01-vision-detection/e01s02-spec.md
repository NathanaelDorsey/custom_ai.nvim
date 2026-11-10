# e01s02-spec.md — Vision Detection on Model Switch

## §1 Business Narrative
When a user switches models via the model selector, the plugin should re-detect vision capability for the new model and update the vision state accordingly.

## §2 User Story
As a Neovim user who switches between vision and text models
I want vision capability to be re-detected automatically on model switch
So that the vision keymap works correctly for the current model without manual intervention

## §3 Acceptance Criteria
- **AC1**: Switch from vision→text model → `state.detected_vision` becomes false within 500ms
- **AC2**: Switch from text→vision model → `state.detected_vision` becomes true within 500ms
- **AC3**: Switch notification includes vision status
- **AC4**: Chat window help text updates to reflect current vision status
- **AC5**: Existing model switch behavior preserved (server restart, health check)

## §4 Requirements (Delta: ADDED)
- REQ-001: **ADDED** — `detect_vision_capability()` reusable from both startup and model switch
- REQ-002: **ADDED** — Model switch calls vision detection after server health check passes
- REQ-003: **ADDED** — Vision detection runs in same defer_fn callback as health check (after 3s)
- REQ-004: **ADDED** — Switch notification includes "Vision: enabled/disabled"
- REQ-005: **ADDED** — Chat buffer header updated with vision status on switch

## §5 Main Flow
1. User calls `switch_model()` via `:lua require("custom_ai").switch_model()`
2. User selects new model key
3. Old server killed, new server started (existing)
4. Health check defer_fn fires after 3s (existing)
5. **NEW**: In health check callback, call `detect_vision_capability()`
6. **NEW**: Update `state.detected_vision` based on result
7. **NEW**: Notify user with vision status
8. **NEW**: Update chat buffer header if visible

## §6 Alternative Flows
- **AF1**: Health check fails → vision detection skipped, `detected_vision = false`
- **AF2**: `vision_probe=false` → filename fallback used (e01s03)

## §7 Error Handling
- Same as e01s01 for probe errors
- Health check failure → vision detection skipped

## §8 Non-Functional
- **Performance**: Vision detection adds ≤ 500ms to model switch (already has 3s defer)
- **Reliability**: Reuses same detection logic as startup

## §9 Traceability
- Scope: `specs/product/SCOPE_LATEST.yaml` → in_scope items 2, 4
- Epic: `specs/epics/e01-vision-detection/epic.yaml` → e01s02
- Tests: `specs/tech-architecture/TEST_PLAN_LATEST.md` → scenario 5

## §10 State Changes
```lua
-- In switch_model health check callback:
detect_vision_capability(function(has_vision)
  state.detected_vision = has_vision
  -- notify + update chat header
end)
```

## §11 Gherkin Scenarios
```gherkin
Scenario: Switch from vision to text model
  Given Neovim running with vision model (detected_vision = true)
  When user switches to text-only model
  And server restarts and health check passes
  Then state.detected_vision == false
  And notification shows "Vision: disabled"
  And chat header shows "Vision: disabled"

Scenario: Switch from text to vision model
  Given Neovim running with text model (detected_vision = false)
  When user switches to vision model
  And server restarts and health check passes
  Then state.detected_vision == true
  And notification shows "Vision: enabled"
  And chat header shows "Vision: enabled"
```