# e01s04-spec.md — Keymap Gating & Warning

## §1 Business Narrative
When vision is not supported by the current model, the vision keymap (<leader>av) should be disabled and attempting to use it should show a clear warning message.

## §2 User Story
As a Neovim user
I want the vision keymap to only work when my model supports vision
So that I don't waste time trying to upload images to a text-only model

## §3 Acceptance Criteria
- **AC1**: Text-only model → `<leader>av` keymap not bound in chat buffer
- **AC2**: Vision model → `<leader>av` keymap bound and functional
- **AC3**: Text-only model + user presses `<leader>av` → warning "Vision not supported by current model"
- **AC4**: Chat window header/help shows "Vision: enabled/disabled"
- **AC5**: New chat re-evaluates keymap binding based on current `state.detected_vision`
- **AC6**: Model switch updates keymap binding without restart

## §4 Requirements (Delta: ADDED)
- REQ-001: **ADDED** — `setup_keymaps()` conditionally binds `km.vision_msg` only when `state.detected_vision == true`
- REQ-002: **ADDED** — When `state.detected_vision == false`, pressing `<leader>av` shows warning via `vim.notify`
- REQ-003: **ADDED** — Chat buffer header includes "Vision: enabled" or "Vision: disabled" line
- REQ-004: **ADDED** — `new_chat()` calls `setup_keymaps()` with current `state.detected_vision`
- REQ-005: **ADDED** — Model switch triggers keymap rebind for open chat window
- REQ-006: **ADDED** — Warning message: "Vision not supported by current model. Switch to a vision-capable model (e.g., LLaVA) to use image upload."

## §5 Main Flow
1. Chat window opens via `chat()` or `new_chat()`
2. `setup_keymaps(buf, win, messages)` called
3. **NEW**: If `state.detected_vision` true → bind `<leader>av` to vision handler
4. **NEW**: If `state.detected_vision` false → bind `<leader>av` to warning handler
5. Chat header written with vision status line
6. User presses `<leader>av`:
   - Vision enabled → normal vision flow (prompt for image, send)
   - Vision disabled → `vim.notify("Vision not supported...", WARN)`

## §6 Alternative Flows
- **AF1**: Model switches while chat open → `switch_model` calls `setup_keymaps` again for open buffer
- **AF2**: User manually calls `refresh_model()` → keymaps rebound

## §7 Error Handling
- Keymap binding failure → silent (non-critical)
- Warning notify failure → silent

## §8 Non-Functional
- **UX**: Clear, actionable warning message
- **Performance**: No overhead — conditional bind at setup time

## §9 Traceability
- Scope: `specs/product/SCOPE_LATEST.yaml` → in_scope items 5, 6
- Epic: `specs/epics/e01-vision-detection/epic.yaml` → e01s04
- Tests: `specs/tech-architecture/TEST_PLAN_LATEST.md` → scenarios 3, 4, 10

## §10 Gherkin Scenarios
```gherkin
Scenario: Vision keymap disabled for text model
  Given Neovim running with text-only model (detected_vision = false)
  When user opens chat
  Then <leader>av shows warning "Vision not supported by current model"
  And chat header shows "Vision: disabled"

Scenario: Vision keymap enabled for vision model
  Given Neovim running with vision model (detected_vision = true)
  When user opens chat
  Then <leader>av prompts for image and works normally
  And chat header shows "Vision: enabled"

Scenario: Model switch updates keymap
  Given chat open with text model
  When user switches to vision model
  Then <leader>av works without reopening chat
  And chat header updates to "Vision: enabled"
```